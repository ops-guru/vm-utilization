#!/usr/bin/env bash
set -euo pipefail

# VM Utilisation Agent - Linux Installation Script
# This script installs Telegraf and AWS CLI, configures metric collection,
# and sets up automated S3 sync for VM utilisation metrics.

# Default values
TELEGRAF_URL=""
BUCKET=""
REGION=""
ACCESS_KEY=""
SECRET_KEY=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --telegraf-url)
            TELEGRAF_URL="$2"
            shift 2
            ;;
        --bucket)
            BUCKET="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --access-key)
            ACCESS_KEY="$2"
            shift 2
            ;;
        --secret-key)
            SECRET_KEY="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 --telegraf-url <url> --bucket <bucket> --region <region> --access-key <key> --secret-key <secret>"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$TELEGRAF_URL" || -z "$BUCKET" || -z "$REGION" || -z "$ACCESS_KEY" || -z "$SECRET_KEY" ]]; then
    echo "Error: All parameters are required"
    echo "Usage: $0 --telegraf-url <url> --bucket <bucket> --region <region> --access-key <key> --secret-key <secret>"
    exit 1
fi

echo "Starting VM Utilisation Agent installation..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Create necessary directories
echo "Creating directories..."
mkdir -p "/etc/telegraf"
mkdir -p "/var/lib/vm-metrics"
mkdir -p "/etc/vm-metrics"

# Download and install Telegraf
echo "Downloading and installing Telegraf..."
TELEGRAF_TEMP="/tmp/telegraf.tar.gz"
curl -fsSL "$TELEGRAF_URL" -o "$TELEGRAF_TEMP"

# Extract Telegraf
cd /tmp
tar -xzf "$TELEGRAF_TEMP"
TELEGRAF_DIR=$(find /tmp -name "telegraf-*" -type d | head -1)
cp "$TELEGRAF_DIR/usr/bin/telegraf" "/usr/local/bin/telegraf"
chmod +x "/usr/local/bin/telegraf"

# Clean up Telegraf temp files
rm -rf "$TELEGRAF_TEMP" "$TELEGRAF_DIR"

# Download and install AWS CLI v2
echo "Downloading and installing AWS CLI v2..."
AWS_CLI_TEMP="/tmp/awscliv2.zip"
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$AWS_CLI_TEMP"

# Install unzip if not present
if ! command -v unzip &> /dev/null; then
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y unzip
    elif command -v yum &> /dev/null; then
        yum install -y unzip
    elif command -v dnf &> /dev/null; then
        dnf install -y unzip
    else
        echo "Error: unzip not found and cannot be installed automatically"
        exit 1
    fi
fi

cd /tmp
unzip -q "$AWS_CLI_TEMP"
./aws/install --bin-dir "/usr/local/bin" --install-dir "/usr/local/aws-cli"

# Clean up AWS CLI temp files
rm -rf "$AWS_CLI_TEMP" "/tmp/aws"

# Create Telegraf configuration
echo "Creating Telegraf configuration..."
cat > "/etc/telegraf/telegraf.conf" << 'EOF'
# Telegraf Configuration for VM Utilisation Metrics

[global_tags]
  # Add global tags here if needed

[agent]
  interval = "30s"
  round_interval = true
  metric_batch_size = 1000
  metric_buffer_limit = 10000
  collection_jitter = "0s"
  flush_interval = "30s"
  flush_jitter = "0s"
  precision = ""
  hostname = ""
  omit_hostname = false

# CPU metrics
[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false
  report_active = false

# Memory metrics
[[inputs.mem]]

# Disk metrics
[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]

# File output
[[outputs.file]]
  files = ["/var/lib/vm-metrics/metrics_%Y%m%d.json"]
  data_format = "json"
  json_timestamp_units = "1s"
  rotation_interval = "24h"
  rotation_max_size = "100MB"
  rotation_max_archives = 7
EOF

# Store AWS credentials securely
echo "Storing AWS credentials..."
cat > "/etc/vm-metrics/aws-credentials" << EOF
AWS_ACCESS_KEY_ID="$ACCESS_KEY"
AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
AWS_DEFAULT_REGION="$REGION"
EOF
chmod 600 "/etc/vm-metrics/aws-credentials"

# Create Telegraf systemd service
echo "Creating Telegraf systemd service..."
cat > "/etc/systemd/system/telegraf.service" << 'EOF'
[Unit]
Description=Telegraf
Documentation=https://github.com/influxdata/telegraf
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/telegraf --config /etc/telegraf/telegraf.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5
KillMode=control-group

[Install]
WantedBy=multi-user.target
EOF

# Create VM metrics sync service
echo "Creating VM metrics sync service..."
cat > "/etc/systemd/system/vm-metrics-sync.service" << EOF
[Unit]
Description=VM Metrics S3 Sync
After=network.target

[Service]
Type=oneshot
User=root
EnvironmentFile=/etc/vm-metrics/aws-credentials
ExecStart=/usr/local/bin/aws s3 sync /var/lib/vm-metrics/ s3://$BUCKET/vm-metrics/\$(hostname)/
StandardOutput=journal
StandardError=journal
EOF

# Create VM metrics sync timer
echo "Creating VM metrics sync timer..."
cat > "/etc/systemd/system/vm-metrics-sync.timer" << 'EOF'
[Unit]
Description=VM Metrics S3 Sync Timer
Requires=vm-metrics-sync.service

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Reload systemd and enable services
echo "Enabling and starting services..."
systemctl daemon-reload
systemctl enable telegraf.service
systemctl enable vm-metrics-sync.timer
systemctl start telegraf.service
systemctl start vm-metrics-sync.timer

# Verify installation
echo "Verifying installation..."
sleep 5

if systemctl is-active --quiet telegraf; then
    echo "✓ Telegraf service is running"
else
    echo "✗ Telegraf service failed to start"
    systemctl status telegraf --no-pager
fi

if systemctl is-active --quiet vm-metrics-sync.timer; then
    echo "✓ VM metrics sync timer is active"
else
    echo "✗ VM metrics sync timer failed to start"
    systemctl status vm-metrics-sync.timer --no-pager
fi

# Check if metrics directory exists and has files
if [[ -d "/var/lib/vm-metrics" ]]; then
    echo "✓ Metrics directory created"
    # Wait a bit for first metrics to be written
    sleep 35
    if ls /var/lib/vm-metrics/*.json 1> /dev/null 2>&1; then
        echo "✓ Metrics files are being generated"
    else
        echo "⚠ No metrics files found yet (this is normal for the first 30 seconds)"
    fi
else
    echo "✗ Metrics directory not found"
fi

echo ""
echo "VM Utilisation Agent installation completed!"
echo ""
echo "Services status:"
echo "- Telegraf: $(systemctl is-active telegraf)"
echo "- Sync Timer: $(systemctl is-active vm-metrics-sync.timer)"
echo ""
echo "Metrics are being collected every 30 seconds and uploaded to S3 every 5 minutes."
echo "Local metrics directory: /var/lib/vm-metrics/"
echo "S3 destination: s3://$BUCKET/vm-metrics/$(hostname)/"
echo ""
echo "To monitor the installation:"
echo "  sudo systemctl status telegraf"
echo "  sudo systemctl status vm-metrics-sync.timer"
echo "  sudo journalctl -u vm-metrics-sync -f"
echo "  sudo ls -la /var/lib/vm-metrics/" 