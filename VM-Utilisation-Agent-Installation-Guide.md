# VM Utilisation Agent – Installation Guide

This guide helps you deploy a Telegraf-based utilisation agent that collects CPU, memory, and disk metrics every 30 seconds, stores them as newline-delimited JSON files locally, and uploads the rotated files to an S3 bucket every 5 minutes. Installation requires only one copy-and-paste command per VM.

## Prerequisites

| Requirement | Description | Example |
|-------------|-------------|---------|
| **Outbound HTTPS** | VM must have internet access to download packages and sync to S3 | Port 443 open to `*.amazonaws.com`, `dl.influxdata.com` |
| **Temporary AWS Credentials** | IAM user with S3 write permissions to target bucket | Access Key: `<AKIA...>`, Secret: `<wJalrXUtn...>` |
| **Administrative Rights** | Root/Administrator access to install services and create system directories | `sudo` on Linux, "Run as Administrator" on Windows |
| **Target S3 Bucket** | Pre-existing S3 bucket for metric storage | `s3://<YOUR-BUCKET>/vm-metrics/<CUSTOMER-ID>/` |

## 1. Linux Installation

### One-liner Install Command

```bash
curl -fsSL https://raw.githubusercontent.com/your-org/vm-util-agent/main/install.sh | sudo bash -s -- \
  --telegraf-url "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_linux_amd64.tar.gz" \
  --bucket "<YOUR-BUCKET>" \
  --region "<REGION>" \
  --access-key "<AKIA...>" \
  --secret-key "<wJalrXUtn...>"
```

### What the Script Does

1. **Downloads and installs Telegraf v1.34.4** to `/usr/local/bin/telegraf`
2. **Downloads and installs AWS CLI v2** to `/usr/local/bin/aws`
3. **Creates Telegraf configuration** at `/etc/telegraf/telegraf.conf` with:
   - CPU, memory, and disk input plugins
   - JSON output to `/var/lib/vm-metrics/metrics_%Y%m%d.json`
   - 30-second collection interval
4. **Creates systemd services**:
   - `telegraf.service` - runs the metrics collection agent
   - `vm-metrics-sync.service` - syncs files to S3
   - `vm-metrics-sync.timer` - triggers sync every 5 minutes
5. **Stores AWS credentials** securely in `/etc/vm-metrics/aws-credentials`
6. **Starts services** and enables them for automatic startup

### Verify Installation

```bash
# Check Telegraf service status
sudo systemctl status telegraf

# Check sync timer status
sudo systemctl status vm-metrics-sync.timer

# View recent metrics files
sudo ls -la /var/lib/vm-metrics/

# Check sync logs
sudo journalctl -u vm-metrics-sync -f
```

### Uninstall

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

## 2. Windows Installation

### One-liner Install Command

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; `
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/your-org/vm-util-agent/main/install.ps1')); `
Install-VMUtilAgent -TelegrafUrl "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_windows_amd64.zip" `
  -Bucket "<YOUR-BUCKET>" -Region "<REGION>" -AccessKey "<AKIA...>" -SecretKey "<wJalrXUtn...>"
```

### What the Script Does

1. **Downloads and installs Telegraf v1.34.4** to `C:\Program Files\Telegraf`
2. **Downloads and installs AWS CLI v2 MSI** silently
3. **Creates Telegraf configuration** at `C:\ProgramData\Telegraf\telegraf.conf` with:
   - CPU, memory, and disk input plugins
   - JSON output to `C:\ProgramData\vm-metrics\metrics_%Y%m%d.json`
   - 30-second collection interval
4. **Creates Windows Service** named "Telegraf" using `sc.exe`
5. **Creates Scheduled Task** named "VM-Metrics-Sync" that runs every 5 minutes as SYSTEM
6. **Stores AWS credentials** as environment variables on the scheduled task
7. **Starts services** and configures them for automatic startup

### Verify Installation

```powershell
# Check Telegraf service status
Get-Service -Name "Telegraf"

# Check scheduled task status
Get-ScheduledTask -TaskName "VM-Metrics-Sync"

# View recent metrics files
Get-ChildItem "C:\ProgramData\vm-metrics\"

# Check sync task history
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-TaskScheduler/Operational'; ID=200,201} | Where-Object {$_.Message -like "*VM-Metrics-Sync*"} | Select-Object -First 5
```

### Uninstall

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

## FAQ

| Question | Answer |
|----------|--------|
| **What's the typical file size for daily metrics?** | Approximately 2-5 MB per day per VM, depending on disk count and activity. Files are rotated daily and compressed during S3 upload. |
| **What happens if the VM goes offline?** | Telegraf continues collecting metrics locally. When connectivity resumes, the sync service uploads all pending files. Local files are retained for 7 days before cleanup. |
| **Are metrics encrypted in transit and at rest?** | Yes. S3 uploads use HTTPS/TLS encryption in transit. Enable S3 server-side encryption (SSE-S3 or SSE-KMS) for encryption at rest. Local files are stored with restricted permissions (root/SYSTEM only). |
| **Can I add custom metrics or modify collection intervals?** | Yes. Edit the Telegraf configuration file (`/etc/telegraf/telegraf.conf` on Linux, `C:\ProgramData\Telegraf\telegraf.conf` on Windows) and restart the Telegraf service. Refer to [Telegraf documentation](https://docs.influxdata.com/telegraf/) for available plugins. |

## Contact

For technical support or questions about the VM Utilisation Agent, contact: **support@<CUSTOMER-ID>.com**

## Appendix A – Direct Download Links

### Telegraf v1.34.4

| Platform | Architecture | Download URL |
|----------|--------------|--------------|
| **Linux** | AMD64 | https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_linux_amd64.tar.gz |
| **Linux** | ARM64 | https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_linux_arm64.tar.gz |
| **Windows** | AMD64 | https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_windows_amd64.zip |

### Checksums

**Checksum file:** https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_checksums.txt

Verify downloads using:
```bash
# Linux
wget https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_checksums.txt
sha256sum -c telegraf-1.34.4_checksums.txt --ignore-missing

# Windows PowerShell
$expectedHash = (Invoke-WebRequest "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_checksums.txt").Content
$actualHash = Get-FileHash "telegraf-1.34.4_windows_amd64.zip" -Algorithm SHA256
$expectedHash -match $actualHash.Hash
``` 