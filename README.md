# VM Utilization Agent

A Telegraf-based utilization agent that collects CPU, memory, and disk metrics from virtual machines and uploads them to AWS S3. This agent provides automated deployment scripts for both Linux and Windows environments.

## 🚀 Quick Start

### Option 1: Environment Variables (Recommended)

**Linux/macOS:**
```bash
# Interactive setup
./setup-env.sh

# Install agent
sudo ./install.sh
```

**Windows:**
```powershell
# Create environment file
cp env-template.ps1 .env.ps1
# Edit .env.ps1 with your values

# Load environment and install
. .\.env.ps1
.\install.ps1
```

### Option 2: Command Line Arguments

**Linux:**
```bash
sudo ./install.sh \
  --telegraf-url "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_linux_amd64.tar.gz" \
  --bucket "your-s3-bucket" \
  --access-key "YOUR_AWS_ACCESS_KEY" \
  --secret-key "YOUR_AWS_SECRET_KEY"
```

**Windows:**
```powershell
.\install.ps1 -TelegrafUrl "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_windows_amd64.zip" `
              -Bucket "your-s3-bucket" `
              -AccessKey "YOUR_AWS_ACCESS_KEY" `
              -SecretKey "YOUR_AWS_SECRET_KEY"
```

## 📋 What It Does

- **Collects Metrics**: CPU, memory, and disk utilization every 30 seconds
- **Stores Locally**: Metrics saved as newline-delimited JSON files with daily rotation
- **Uploads to S3**: Automated sync to AWS S3 every 5 minutes
- **Self-Managing**: Systemd services (Linux) or Windows Services for reliability
- **Minimal Footprint**: ~2-5 MB storage per day per VM

## 📁 Repository Structure

```
vm-utilization/
├── README.md                                    # This file
├── LICENSE                                      # MIT License
├── VM-Utilisation-Agent-Installation-Guide.md  # Comprehensive installation guide
├── install.sh                                   # Linux installation script
├── install.ps1                                  # Windows installation script
├── setup-env.sh                                 # Interactive environment setup
├── env-template.txt                             # Linux environment template
├── env-template.ps1                             # Windows environment template
├── ENVIRONMENT-SETUP.md                         # Detailed environment setup guide
└── docs/                                        # Additional documentation
```

## 📚 Documentation

- **[Installation Guide](VM-Utilisation-Agent-Installation-Guide.md)** - Complete installation, verification, and troubleshooting guide
- **[Azure Testing Guide](https://github.com/ops-guru/vm-utilization/blob/main/docs/azure-testing-guide.md)** - How to test using Azure VMs

## 🛠 Prerequisites

| Requirement | Linux | Windows | Description |
|-------------|-------|---------|-------------|
| **Admin Rights** | `sudo` access | Administrator | Required to install services |
| **Internet Access** | HTTPS (443) | HTTPS (443) | For downloads and S3 sync |
| **AWS Credentials** | S3 write permissions | S3 write permissions | For metrics upload |
| **S3 Bucket** | Pre-existing | Pre-existing | Target for metrics storage |

## 🔧 Configuration

The installation scripts support multiple configuration methods with the following priority:

1. **Environment Variables** (highest priority)
2. **Command Line Arguments** (fallback)
3. **Default Values** (lowest priority)

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `VM_TELEGRAF_URL` | Telegraf download URL | `https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_linux_amd64.tar.gz` |
| `VM_S3_BUCKET` | S3 bucket for metrics storage | `my-vm-metrics-bucket` |
| `VM_AWS_ACCESS_KEY` | AWS access key ID | `AKIA...` |
| `VM_AWS_SECRET_KEY` | AWS secret access key | `wJalrXUtn...` |

### Optional Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `VM_AWS_REGION` | AWS region | `us-east-1` |
| `VM_CUSTOMER_ID` | Customer identifier | `default-customer` |

For detailed configuration options, see [ENVIRONMENT-SETUP.md](ENVIRONMENT-SETUP.md).

## 📊 Metrics Collected

The agent collects the following metrics:

### CPU Metrics
- `cpu.usage_active` - Active CPU percentage
- `cpu.usage_idle` - Idle CPU percentage
- Per-CPU core metrics (when available)

### Memory Metrics
- `mem.used_percent` - Memory usage percentage
- `mem.available` - Available memory in bytes
- `mem.total` - Total memory in bytes

### Disk Metrics
- `disk.used_percent` - Disk usage percentage per mount/drive
- `disk.free` - Free disk space in bytes
- `disk.total` - Total disk space in bytes

## 🏗 Architecture

```
VM Utilization Agent Architecture:

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Telegraf      │    │  Local Storage  │    │   AWS S3        │
│   Collector     │───▶│  (JSON files)   │───▶│   Bucket        │
│   (30s interval)│    │  Daily rotation │    │  (5min sync)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

**Linux Implementation:**
- Telegraf runs as systemd service
- S3 sync via systemd timer (5-minute intervals)
- Credentials stored in `/etc/vm-metrics/aws-credentials`

**Windows Implementation:**
- Telegraf runs as Windows Service
- S3 sync via Scheduled Task (5-minute intervals)
- Credentials stored as task environment variables

## 🧪 Testing

For testing the agent before deployment:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ops-guru/vm-utilization.git
   cd vm-utilization
   ```

2. **Test locally:**
   ```bash
   # Linux
   sudo ./install.sh --telegraf-url "..." --bucket "test-bucket" --region "us-east-1" --access-key "..." --secret-key "..."
   
   # Windows
   .\install.ps1 -TelegrafUrl "..." -Bucket "test-bucket" -Region "us-east-1" -AccessKey "..." -SecretKey "..."
   ```

3. **Verify metrics collection:**
   ```bash
   # Linux
   sudo ls -la /var/lib/vm-metrics/
   sudo systemctl status telegraf
   
   # Windows
   Get-ChildItem "C:\ProgramData\vm-metrics\"
   Get-Service -Name "Telegraf"
   ```

## 📈 Monitoring

### Service Status Commands

**Linux:**
```bash
# Check Telegraf service
sudo systemctl status telegraf

# Check S3 sync timer
sudo systemctl status vm-metrics-sync.timer

# View sync logs
sudo journalctl -u vm-metrics-sync -f
```

**Windows:**
```powershell
# Check Telegraf service
Get-Service -Name "Telegraf"

# Check scheduled task
Get-ScheduledTask -TaskName "VM-Metrics-Sync"

# View task history
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-TaskScheduler/Operational'; ID=200,201} | Where-Object {$_.Message -like "*VM-Metrics-Sync*"}
```

## 🗑 Uninstallation

### Linux

```bash
# Stop and disable services
sudo systemctl stop telegraf vm-metrics-sync.timer
sudo systemctl disable telegraf vm-metrics-sync.timer vm-metrics-sync.service

# Remove service files
sudo rm -f /etc/systemd/system/telegraf.service
sudo rm -f /etc/systemd/system/vm-metrics-sync.service
sudo rm -f /etc/systemd/system/vm-metrics-sync.timer

# Remove application files
sudo rm -rf /etc/telegraf
sudo rm -rf /var/lib/vm-metrics
sudo rm -rf /etc/vm-metrics
sudo rm -f /usr/local/bin/telegraf

# Reload systemd
sudo systemctl daemon-reload
```

### Windows

```powershell
# Stop and remove Telegraf service
Stop-Service -Name "Telegraf" -Force
sc.exe delete "Telegraf"

# Remove scheduled task
Unregister-ScheduledTask -TaskName "VM-Metrics-Sync" -Confirm:$false

# Remove application directories
Remove-Item -Path "C:\Program Files\Telegraf" -Recurse -Force
Remove-Item -Path "C:\ProgramData\Telegraf" -Recurse -Force
Remove-Item -Path "C:\ProgramData\vm-metrics" -Recurse -Force
```

## 🔒 Security

- **Credentials**: Stored with restricted permissions (root/SYSTEM only)
- **Transport**: HTTPS/TLS for all S3 communications
- **File Permissions**: Metrics files readable only by system accounts
- **No Network Exposure**: Agent only makes outbound connections

## 🐛 Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Service won't start | Configuration error | Check `telegraf --config <config> --test` |
| S3 upload fails | Credentials/permissions | Verify IAM permissions and bucket access |
| High disk usage | Sync failure | Check network connectivity and S3 permissions |

### Log Locations

**Linux:**
- Telegraf: `sudo journalctl -u telegraf`
- S3 Sync: `sudo journalctl -u vm-metrics-sync`

**Windows:**
- Telegraf: Event Viewer > Windows Logs > System
- S3 Sync: Event Viewer > Task Scheduler logs

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📞 Support

For issues and support:
- **GitHub Issues**: [Create an issue](https://github.com/ops-guru/vm-utilization/issues)
- **Documentation**: See [Installation Guide](VM-Utilisation-Agent-Installation-Guide.md)

## 🏷 Tags

`telegraf` `monitoring` `metrics` `vm-utilization` `aws-s3` `linux` `windows` `automation` `devops`