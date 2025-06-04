# VM Utilization Agent - Testing Guide for Azure Lab

This guide walks you through testing the VM Utilization Agent on Azure VMs before pushing to the GitHub repository.

## Prerequisites

1. **Azure CLI** - Make sure you're logged in: `az login`
2. **Terraform** - Installed and initialized
3. **SSH Key Pair** - For Linux VM access
4. **AWS Account** - With S3 bucket and IAM credentials
5. **RDP Client** - For Windows VM access

## Step 1: Configure SSH Keys

Generate an SSH key pair for Linux VM access:

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f ~/.ssh/azure_lab_key

# Display the public key to copy into terraform.tfvars
cat ~/.ssh/azure_lab_key.pub
```

## Step 2: Configure AWS S3 Bucket

Create an S3 bucket for testing:

```bash
# Create S3 bucket (replace with unique name)
aws s3 mb s3://your-unique-test-bucket-name-$(date +%s)

# Create IAM user for VM metrics (optional - can use existing credentials)
aws iam create-user --user-name vm-metrics-test-user

# Create and attach policy for S3 access
aws iam put-user-policy --user-name vm-metrics-test-user --policy-name S3MetricsAccess --policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-unique-test-bucket-name-*",
        "arn:aws:s3:::your-unique-test-bucket-name-*/*"
      ]
    }
  ]
}'

# Create access keys
aws iam create-access-key --user-name vm-metrics-test-user
```

## Step 3: Update Configuration

Update `terraform.tfvars` with your actual values:

```hcl
# Update these with your actual values:
ssh_public_key        = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7... <YOUR_ACTUAL_PUBLIC_KEY>"
aws_access_key_id     = "<YOUR_AWS_ACCESS_KEY>"
aws_secret_access_key = "<YOUR_AWS_SECRET_KEY>"
s3_bucket_name       = "<YOUR_BUCKET_NAME>"
```

## Step 4: Deploy Azure Infrastructure

Navigate to the azure-lab directory and deploy:

```bash
cd /path/to/your/azure-lab

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

After deployment, note the outputs:
- Linux VM public IP
- Windows VM public IP
- SSH command for Linux VM
- RDP info for Windows VM

## Step 5: Test Linux VM Installation

1. **Connect to Linux VM:**
   ```bash
   # Use the SSH command from terraform output
   ssh -i ~/.ssh/azure_lab_key azureuser@<LINUX_VM_PUBLIC_IP>
   ```

2. **Install VM Utilization Agent:**
   ```bash
   # Copy the install.sh script to the VM
   scp -i ~/.ssh/azure_lab_key install.sh azureuser@<LINUX_VM_PUBLIC_IP>:~/

   # Run the installation
   sudo ./install.sh \
     --telegraf-url "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_linux_amd64.tar.gz" \
     --bucket "<YOUR_BUCKET_NAME>" \
     --region "us-east-1" \
     --access-key "<YOUR_AWS_ACCESS_KEY>" \
     --secret-key "<YOUR_AWS_SECRET_KEY>"
   ```

3. **Verify Installation:**
   ```bash
   # Check Telegraf service
   sudo systemctl status telegraf

   # Check sync timer
   sudo systemctl status vm-metrics-sync.timer

   # View metrics files
   sudo ls -la /var/lib/vm-metrics/

   # Check S3 sync logs
   sudo journalctl -u vm-metrics-sync -f
   ```

4. **Test Metrics Collection:**
   ```bash
   # Wait 2-3 minutes, then check for JSON files
   sudo find /var/lib/vm-metrics/ -name "*.json" -exec tail -n 5 {} \;

   # Verify S3 upload (wait 5+ minutes after installation)
   aws s3 ls s3://<YOUR_BUCKET_NAME>/vm-metrics/ --recursive
   ```

## Step 6: Test Windows VM Installation

1. **Connect to Windows VM:**
   - Use RDP client to connect to `<WINDOWS_VM_PUBLIC_IP>:3389`
   - Username: `azureuser`
   - Password: `<YOUR_VM_PASSWORD>` (as configured in terraform.tfvars)

2. **Install VM Utilization Agent:**
   ```powershell
   # Open PowerShell as Administrator
   # Copy the install.ps1 script to the VM, then run:
   
   .\install.ps1 `
     -TelegrafUrl "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_windows_amd64.zip" `
     -Bucket "<YOUR_BUCKET_NAME>" `
     -Region "us-east-1" `
     -AccessKey "<YOUR_AWS_ACCESS_KEY>" `
     -SecretKey "<YOUR_AWS_SECRET_KEY>"
   ```

3. **Verify Installation:**
   ```powershell
   # Check Telegraf service
   Get-Service -Name "Telegraf"

   # Check scheduled task
   Get-ScheduledTask -TaskName "VM-Metrics-Sync"

   # View metrics files
   Get-ChildItem "C:\ProgramData\vm-metrics\"

   # Check task history
   Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-TaskScheduler/Operational'; ID=200,201} | Where-Object {$_.Message -like "*VM-Metrics-Sync*"} | Select-Object -First 5
   ```

4. **Test Metrics Collection:**
   ```powershell
   # Wait 2-3 minutes, then check for JSON files
   Get-ChildItem "C:\ProgramData\vm-metrics\" -Filter "*.json" | ForEach-Object { Get-Content $_.FullName | Select-Object -Last 5 }

   # Verify S3 upload (wait 5+ minutes after installation)
   # Use AWS CLI or check S3 console
   ```

## Step 7: Validate S3 Data

Check that metrics are being uploaded to S3:

```bash
# List all uploaded metrics
aws s3 ls s3://<YOUR_BUCKET_NAME>/vm-metrics/ --recursive

# Download and inspect a metrics file
aws s3 cp s3://<YOUR_BUCKET_NAME>/vm-metrics/azlab-linux-vm/metrics_$(date +%Y%m%d).json ./test-metrics.json
cat test-metrics.json | jq '.'
```

Expected JSON structure:
```json
{
  "fields": {
    "usage_active": 45.2,
    "usage_idle": 54.8
  },
  "name": "cpu",
  "tags": {
    "cpu": "cpu-total",
    "host": "azlab-linux-vm"
  },
  "timestamp": 1703001234
}
```

## Step 8: Test Uninstallation

Test the uninstall procedures on both VMs:

**Linux:**
```bash
# Run uninstall commands from the guide
sudo systemctl stop telegraf vm-metrics-sync.timer
sudo systemctl disable telegraf vm-metrics-sync.timer vm-metrics-sync.service
# ... (follow full uninstall procedure)
```

**Windows:**
```powershell
# Run uninstall commands from the guide
Stop-Service -Name "Telegraf" -Force
sc.exe delete "Telegraf"
# ... (follow full uninstall procedure)
```

## Step 9: Document Results

Create a test report with:
- ✅ Installation success/failure on both platforms
- ✅ Metrics collection verification
- ✅ S3 upload verification
- ✅ Service status verification
- ✅ Uninstallation verification
- 🐛 Any issues encountered and solutions

## Step 10: Clean Up Test Environment

When testing is complete:

```bash
# Destroy Azure resources
cd /path/to/your/azure-lab
terraform destroy

# Clean up AWS resources
aws s3 rm s3://<YOUR_BUCKET_NAME> --recursive
aws s3 rb s3://<YOUR_BUCKET_NAME>
aws iam delete-access-key --user-name vm-metrics-test-user --access-key-id <ACCESS_KEY_ID>
aws iam delete-user-policy --user-name vm-metrics-test-user --policy-name S3MetricsAccess
aws iam delete-user --user-name vm-metrics-test-user
```

## Troubleshooting

### Common Issues

1. **SSH Connection Failed:**
   - Check NSG rules allow SSH (port 22)
   - Verify SSH key is correct
   - Check VM is running

2. **Telegraf Service Won't Start:**
   - Check configuration file syntax: `telegraf --config /etc/telegraf/telegraf.conf --test`
   - Review service logs: `sudo journalctl -u telegraf -f`

3. **S3 Upload Fails:**
   - Verify AWS credentials have correct permissions
   - Check bucket name is correct
   - Verify internet connectivity: `curl -I https://s3.amazonaws.com`

4. **Windows Installation Issues:**
   - Ensure PowerShell is running as Administrator
   - Check Windows Defender isn't blocking downloads
   - Verify .NET Framework is installed

### Log Locations

**Linux:**
- Telegraf logs: `sudo journalctl -u telegraf`
- S3 sync logs: `sudo journalctl -u vm-metrics-sync`
- Metrics files: `/var/lib/vm-metrics/`

**Windows:**
- Telegraf service logs: Event Viewer > Windows Logs > System
- Scheduled task logs: Event Viewer > Applications and Services Logs > Microsoft > Windows > TaskScheduler
- Metrics files: `C:\ProgramData\vm-metrics\`

---

**⚠️ SECURITY NOTE:** Ensure all sensitive information (SSH keys, AWS credentials, passwords) are properly secured and never committed to version control. This guide uses placeholder values that must be replaced with your actual credentials during testing.

Once testing is complete and successful, proceed to push all files to the GitHub repository as instructed. 