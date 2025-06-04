# VM Utilization Agent

A Telegraf-based utilization agent that collects CPU, memory, and disk metrics from virtual machines and uploads them to AWS S3. This agent provides automated deployment scripts for both Linux and Windows environments.

## 🚀 Quick Start

### Linux (One-liner Installation)

```bash
curl -fsSL https://raw.githubusercontent.com/ops-guru/vm-utilization/main/install.sh | sudo bash -s -- \
  --telegraf-url "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_linux_amd64.tar.gz" \
  --bucket "<YOUR-BUCKET>" \
  --region "<REGION>" \
  --access-key "<AKIA...>" \
  --secret-key "<wJalrXUtn...>"
```

### Windows (One-liner Installation)

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; `
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/ops-guru/vm-utilization/main/install.ps1')); `
Install-VMUtilAgent -TelegrafUrl "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_windows_amd64.zip" `
  -Bucket "<YOUR-BUCKET>" -Region "<REGION>" -AccessKey "<AKIA...>" -SecretKey "<wJalrXUtn...>"
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

## 🔧 Installation Parameters

Both scripts accept the following parameters:

| Parameter | Description | Example |
|-----------|-------------|---------|
| `--telegraf-url` / `-TelegrafUrl` | Telegraf download URL | `https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_linux_amd64.tar.gz` |
| `--bucket` / `-Bucket` | S3 bucket name | `my-vm-metrics-bucket` |
| `--region` / `-Region` | AWS region | `us-east-1` |
| `--access-key` / `-AccessKey` | AWS access key | `AKIA...` |
| `--secret-key` / `-SecretKey` | AWS secret key | `wJalrXUtn...` |

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