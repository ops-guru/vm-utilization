#!/bin/bash

# VM Utilization Agent Installer for Linux
# Supports environment variables and command-line arguments
# Environment variables take precedence over command-line arguments

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    log_info "Loading environment variables from .env file..."
    export $(cat .env | grep -v '^#' | grep -v '^$' | xargs)
fi

# Default values (can be overridden by environment variables or arguments)
TELEGRAF_URL="${VM_TELEGRAF_URL:-}"
BUCKET_NAME="${VM_S3_BUCKET:-}"
AWS_REGION="${VM_AWS_REGION:-us-east-1}"
AWS_ACCESS_KEY="${VM_AWS_ACCESS_KEY:-}"
AWS_SECRET_KEY="${VM_AWS_SECRET_KEY:-}"
CUSTOMER_ID="${VM_CUSTOMER_ID:-default-customer}"

# Function to show usage
usage() {
    cat << EOF
VM Utilization Agent Installer for Linux

USAGE:
    sudo $0 [OPTIONS]

ENVIRONMENT VARIABLES (recommended):
    VM_TELEGRAF_URL      - Telegraf download URL
    VM_S3_BUCKET         - S3 bucket name for metrics storage
    VM_AWS_REGION        - AWS region (default: us-east-1)
    VM_AWS_ACCESS_KEY    - AWS access key
    VM_AWS_SECRET_KEY    - AWS secret key
    VM_CUSTOMER_ID       - Customer identifier (default: default-customer)

COMMAND LINE OPTIONS (override environment variables):
    --telegraf-url URL   - Telegraf download URL
    --bucket BUCKET      - S3 bucket name
    --region REGION      - AWS region
    --access-key KEY     - AWS access key
    --secret-key KEY     - AWS secret key
    --customer-id ID     - Customer identifier
    --help               - Show this help message

EXAMPLES:
    # Using environment variables (recommended):
    export VM_TELEGRAF_URL="https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_linux_amd64.tar.gz"
    export VM_S3_BUCKET="my-metrics-bucket"
    export VM_AWS_ACCESS_KEY="AKIA..."
    export VM_AWS_SECRET_KEY="wJalr..."
    sudo $0

    # Using command line arguments:
    sudo $0 --telegraf-url "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_linux_amd64.tar.gz" \\
            --bucket "my-metrics-bucket" \\
            --access-key "AKIA..." \\
            --secret-key "wJalr..."

NOTES:
    - Environment variables take precedence over command-line arguments
    - Place a .env file in the same directory to load variables automatically
    - All AWS credentials are stored securely and not logged
    - Requires sudo privileges for installation

EOF
}

# Parse command line arguments (these override environment variables)
while [[ $# -gt 0 ]]; do
    case $1 in
        --telegraf-url)
            TELEGRAF_URL="$2"
            shift 2
            ;;
        --bucket)
            BUCKET_NAME="$2"
            shift 2
            ;;
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --access-key)
            AWS_ACCESS_KEY="$2"
            shift 2
            ;;
        --secret-key)
            AWS_SECRET_KEY="$2"
            shift 2
            ;;
        --customer-id)
            CUSTOMER_ID="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Function to validate required parameters
validate_parameters() {
    local missing_params=()
    
    if [[ -z "$TELEGRAF_URL" ]]; then
        missing_params+=("VM_TELEGRAF_URL or --telegraf-url")
    fi
    
    if [[ -z "$BUCKET_NAME" ]]; then
        missing_params+=("VM_S3_BUCKET or --bucket")
    fi
    
    if [[ -z "$AWS_ACCESS_KEY" ]]; then
        missing_params+=("VM_AWS_ACCESS_KEY or --access-key")
    fi
    
    if [[ -z "$AWS_SECRET_KEY" ]]; then
        missing_params+=("VM_AWS_SECRET_KEY or --secret-key")
    fi
    
    if [[ ${#missing_params[@]} -gt 0 ]]; then
        log_error "Missing required parameters:"
        for param in "${missing_params[@]}"; do
            log_error "  - $param"
        done
        echo
        usage
        exit 1
    fi
}

log_info "Starting VM Utilization Agent installation..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Validate parameters
validate_parameters

# Log configuration (without sensitive data)
log_info "Configuration:"
log_info "  Telegraf URL: $TELEGRAF_URL"
log_info "  S3 Bucket: $BUCKET_NAME"
log_info "  AWS Region: $AWS_REGION"
log_info "  Customer ID: $CUSTOMER_ID"
log_info "  AWS Access Key: ${AWS_ACCESS_KEY:0:8}..."

# Check required commands
log_info "Checking system requirements..."
for cmd in wget tar systemctl; do
    if ! command -v $cmd &> /dev/null; then
        log_error "$cmd is required but not installed"
        exit 1
    fi
done

# Create system user for telegraf if it doesn't exist
if ! id "telegraf" &>/dev/null; then
    log_info "Creating telegraf user..."
    useradd --system --no-create-home --shell /bin/false telegraf
fi

# Create directories
log_info "Creating directories..."
mkdir -p /etc/telegraf
mkdir -p /var/lib/vm-metrics
mkdir -p /var/log/telegraf
mkdir -p /opt/telegraf

# Set ownership
chown telegraf:telegraf /var/lib/vm-metrics
chown telegraf:telegraf /var/log/telegraf

# Download and install Telegraf
log_info "Downloading Telegraf..."
TELEGRAF_ARCHIVE="/tmp/telegraf.tar.gz"
if ! wget -q "$TELEGRAF_URL" -O "$TELEGRAF_ARCHIVE"; then
    log_error "Failed to download Telegraf from $TELEGRAF_URL"
    exit 1
fi

log_info "Installing Telegraf..."
tar -xzf "$TELEGRAF_ARCHIVE" -C /tmp/
TELEGRAF_DIR=$(find /tmp -name "telegraf-*" -type d | head -1)
if [[ -z "$TELEGRAF_DIR" ]]; then
    log_error "Failed to extract Telegraf archive"
    exit 1
fi

# Copy Telegraf binary
cp "$TELEGRAF_DIR/usr/bin/telegraf" /usr/local/bin/
chmod +x /usr/local/bin/telegraf

# Create Telegraf configuration
log_info "Creating Telegraf configuration..."
cat > /etc/telegraf/telegraf.conf << EOF
# VM Utilization Agent Configuration
[global_tags]
  customer_id = "$CUSTOMER_ID"

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

# Output to file (JSON format)
[[outputs.file]]
  files = ["/var/lib/vm-metrics/metrics_\$(date +%Y%m%d).json"]
  data_format = "json"
  json_timestamp_units = "1s"

# CPU metrics
[[inputs.cpu]]
  percpu = false
  totalcpu = true
  collect_cpu_time = false
  report_active = true

# Memory metrics
[[inputs.mem]]

# Disk metrics
[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]

# System load
[[inputs.system]]
EOF

# Install AWS CLI if not present
if ! command -v aws &> /dev/null; then
    log_info "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    cd /tmp
    unzip -q awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
fi

# Configure AWS credentials for telegraf user
log_info "Configuring AWS credentials..."
mkdir -p /home/telegraf/.aws
cat > /home/telegraf/.aws/credentials << EOF
[default]
aws_access_key_id = $AWS_ACCESS_KEY
aws_secret_access_key = $AWS_SECRET_KEY
EOF

cat > /home/telegraf/.aws/config << EOF
[default]
region = $AWS_REGION
output = json
EOF

# Set secure permissions on AWS credentials
chown -R telegraf:telegraf /home/telegraf/.aws
chmod 700 /home/telegraf/.aws
chmod 600 /home/telegraf/.aws/credentials
chmod 600 /home/telegraf/.aws/config

# Create Telegraf systemd service
log_info "Creating Telegraf service..."
cat > /etc/systemd/system/telegraf.service << EOF
[Unit]
Description=VM Utilization Agent (Telegraf)
After=network.target
Wants=network.target

[Service]
Type=simple
User=telegraf
Group=telegraf
ExecStart=/usr/local/bin/telegraf --config /etc/telegraf/telegraf.conf
Restart=always
RestartSec=5
KillMode=mixed
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

# Create S3 sync script
log_info "Creating S3 sync script..."
cat > /usr/local/bin/vm-metrics-sync.sh << EOF
#!/bin/bash
# VM Metrics S3 Sync Script

export AWS_CONFIG_FILE="/home/telegraf/.aws/config"
export AWS_SHARED_CREDENTIALS_FILE="/home/telegraf/.aws/credentials"

HOSTNAME=\$(hostname)
METRICS_DIR="/var/lib/vm-metrics"
S3_BUCKET="$BUCKET_NAME"
S3_PREFIX="vm-metrics/\$HOSTNAME"

# Sync metrics to S3
/usr/local/bin/aws s3 sync "\$METRICS_DIR" "s3://\$S3_BUCKET/\$S3_PREFIX" \\
    --exclude "*.tmp" \\
    --exclude "*.lock" \\
    --delete

# Clean up old local files (keep last 7 days)
find "\$METRICS_DIR" -name "metrics_*.json" -mtime +7 -delete

echo "Metrics sync completed: \$(date)"
EOF

chmod +x /usr/local/bin/vm-metrics-sync.sh
chown telegraf:telegraf /usr/local/bin/vm-metrics-sync.sh

# Create S3 sync systemd service
cat > /etc/systemd/system/vm-metrics-sync.service << EOF
[Unit]
Description=VM Metrics S3 Sync
After=network.target

[Service]
Type=oneshot
User=telegraf
Group=telegraf
ExecStart=/usr/local/bin/vm-metrics-sync.sh
EOF

# Create S3 sync timer (every 5 minutes)
cat > /etc/systemd/system/vm-metrics-sync.timer << EOF
[Unit]
Description=VM Metrics S3 Sync Timer
Requires=vm-metrics-sync.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF

# Start and enable services
log_info "Starting services..."
systemctl daemon-reload
systemctl enable telegraf
systemctl enable vm-metrics-sync.timer
systemctl start telegraf
systemctl start vm-metrics-sync.timer

# Verify installation
log_info "Verifying installation..."
sleep 5

if systemctl is-active --quiet telegraf; then
    log_success "Telegraf service is running"
else
    log_error "Telegraf service failed to start"
    systemctl status telegraf
    exit 1
fi

if systemctl is-active --quiet vm-metrics-sync.timer; then
    log_success "S3 sync timer is running"
else
    log_error "S3 sync timer failed to start"
    systemctl status vm-metrics-sync.timer
    exit 1
fi

# Test metric collection
log_info "Testing metric collection..."
sleep 30
if [[ -f "/var/lib/vm-metrics/metrics_$(date +%Y%m%d).json" ]]; then
    log_success "Metrics file created successfully"
    log_info "Sample metrics:"
    tail -n 3 "/var/lib/vm-metrics/metrics_$(date +%Y%m%d).json"
else
    log_warning "Metrics file not yet created (may take a few minutes)"
fi

# Cleanup
rm -rf /tmp/telegraf* /tmp/aws*

log_success "VM Utilization Agent installation completed successfully!"
log_info "Configuration:"
log_info "  - Metrics collection: Every 30 seconds"
log_info "  - S3 sync: Every 5 minutes"
log_info "  - Local storage: /var/lib/vm-metrics/"
log_info "  - Logs: journalctl -u telegraf -f"
log_info "  - S3 sync logs: journalctl -u vm-metrics-sync -f"

echo
log_info "To check status:"
log_info "  sudo systemctl status telegraf"
log_info "  sudo systemctl status vm-metrics-sync.timer" 