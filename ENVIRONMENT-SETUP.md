# Environment Variables Setup Guide

The VM Utilization Agent installation scripts now support environment variables as the primary configuration method, making deployment more secure and convenient.

## Quick Start

### Linux/macOS Setup

1. **Run the interactive setup:**
   ```bash
   ./setup-env.sh
   ```

2. **Or manually create `.env` file:**
   ```bash
   cp env-template.txt .env
   # Edit .env with your values
   ```

3. **Install the agent:**
   ```bash
   sudo ./install.sh
   ```

### Windows Setup

1. **Create environment file:**
   ```powershell
   cp env-template.ps1 .env.ps1
   # Edit .env.ps1 with your values
   ```

2. **Load environment and install:**
   ```powershell
   . .\.env.ps1
   .\install.ps1
   ```

## Environment Variables Reference

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `VM_TELEGRAF_URL` | Telegraf download URL | `https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_linux_amd64.tar.gz` |
| `VM_S3_BUCKET` | S3 bucket for metrics storage | `my-vm-metrics-bucket` |
| `VM_AWS_ACCESS_KEY` | AWS access key ID | `AKIA...` |
| `VM_AWS_SECRET_KEY` | AWS secret access key | `wJalrXUtn...` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `VM_AWS_REGION` | AWS region | `us-east-1` |
| `VM_CUSTOMER_ID` | Customer identifier | `default-customer` |

## Configuration Methods (Priority Order)

1. **Environment Variables** (highest priority)
2. **Command Line Arguments** (fallback)
3. **Default Values** (lowest priority)

### Linux Examples

**Using environment variables:**
```bash
export VM_TELEGRAF_URL="https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_linux_amd64.tar.gz"
export VM_S3_BUCKET="my-metrics-bucket"
export VM_AWS_ACCESS_KEY="AKIA..."
export VM_AWS_SECRET_KEY="wJalr..."
sudo ./install.sh
```

**Using .env file:**
```bash
# Create .env file with variables
cat > .env << 'EOF'
VM_TELEGRAF_URL="https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_linux_amd64.tar.gz"
VM_S3_BUCKET="my-metrics-bucket"
VM_AWS_ACCESS_KEY="AKIA..."
VM_AWS_SECRET_KEY="wJalr..."
EOF

# Install (script will load .env automatically)
sudo ./install.sh
```

**Using command line arguments (fallback):**
```bash
sudo ./install.sh \
  --telegraf-url "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_linux_amd64.tar.gz" \
  --bucket "my-metrics-bucket" \
  --access-key "AKIA..." \
  --secret-key "wJalr..."
```

### Windows Examples

**Using environment variables:**
```powershell
$env:VM_TELEGRAF_URL = "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_windows_amd64.zip"
$env:VM_S3_BUCKET = "my-metrics-bucket"
$env:VM_AWS_ACCESS_KEY = "AKIA..."
$env:VM_AWS_SECRET_KEY = "wJalr..."
.\install.ps1
```

**Using .env.ps1 file:**
```powershell
# Create .env.ps1 file
@"
`$env:VM_TELEGRAF_URL = "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_windows_amd64.zip"
`$env:VM_S3_BUCKET = "my-metrics-bucket"
`$env:VM_AWS_ACCESS_KEY = "AKIA..."
`$env:VM_AWS_SECRET_KEY = "wJalr..."
"@ | Out-File -FilePath .env.ps1 -Encoding UTF8

# Load environment and install
. .\.env.ps1
.\install.ps1
```

**Using command line parameters (fallback):**
```powershell
.\install.ps1 -TelegrafUrl "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_windows_amd64.zip" `
              -Bucket "my-metrics-bucket" `
              -AccessKey "AKIA..." `
              -SecretKey "wJalr..."
```

## Security Best Practices

### File Permissions

The scripts automatically set secure permissions:
- **Linux**: `.env` files are set to `600` (owner read/write only)
- **Windows**: AWS credentials get restricted ACLs

### Credential Management

1. **Never commit credentials to version control**
   - The `.gitignore` file excludes all `.env*` files
   - Use templates (`env-template.txt`, `env-template.ps1`)

2. **Use least-privilege AWS policies**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "s3:PutObject",
           "s3:PutObjectAcl",
           "s3:GetObject",
           "s3:ListBucket",
           "s3:DeleteObject"
         ],
         "Resource": [
           "arn:aws:s3:::your-bucket-name",
           "arn:aws:s3:::your-bucket-name/*"
         ]
       }
     ]
   }
   ```

3. **Rotate credentials regularly**
   - Update `.env` files when rotating AWS keys
   - Restart services after credential updates

## Deployment Scenarios

### Single VM Deployment

```bash
# On target VM
curl -fsSL https://raw.githubusercontent.com/ops-guru/vm-utilization/main/setup-env.sh -o setup-env.sh
chmod +x setup-env.sh
./setup-env.sh

curl -fsSL https://raw.githubusercontent.com/ops-guru/vm-utilization/main/install.sh -o install.sh
chmod +x install.sh
sudo ./install.sh
```

### Multi-VM Deployment

```bash
# Create .env file once
./setup-env.sh

# Deploy to multiple VMs
for vm in vm1.example.com vm2.example.com vm3.example.com; do
  scp .env install.sh $vm:/tmp/
  ssh $vm "cd /tmp && sudo ./install.sh"
done
```

### CI/CD Pipeline Integration

```yaml
# Example GitHub Actions
- name: Deploy VM Agent
  run: |
    echo "VM_TELEGRAF_URL=${{ vars.TELEGRAF_URL }}" >> .env
    echo "VM_S3_BUCKET=${{ vars.S3_BUCKET }}" >> .env
    echo "VM_AWS_ACCESS_KEY=${{ secrets.AWS_ACCESS_KEY }}" >> .env
    echo "VM_AWS_SECRET_KEY=${{ secrets.AWS_SECRET_KEY }}" >> .env
    
    scp .env install.sh user@${{ matrix.vm }}:/tmp/
    ssh user@${{ matrix.vm }} "cd /tmp && sudo ./install.sh"
```

## Troubleshooting

### Environment Loading Issues

**Problem**: Variables not loading from .env file
```bash
# Debug: Check if .env file exists and is readable
ls -la .env
cat .env

# Manual load test
source .env
echo $VM_S3_BUCKET
```

**Problem**: PowerShell execution policy prevents .env.ps1 loading
```powershell
# Check execution policy
Get-ExecutionPolicy

# Set for current session
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Load environment
. .\.env.ps1
```

### Variable Priority Conflicts

When variables are set in multiple places, the priority is:
1. Environment variables (highest)
2. Command line arguments
3. Default values (lowest)

To debug which values are being used:
```bash
# Linux: Check environment
env | grep VM_

# Windows: Check environment
Get-ChildItem Env: | Where-Object Name -Like "VM_*"
```

### AWS Credential Issues

**Test AWS access:**
```bash
# Set credentials from .env
source .env
export AWS_ACCESS_KEY_ID="$VM_AWS_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$VM_AWS_SECRET_KEY"
export AWS_DEFAULT_REGION="$VM_AWS_REGION"

# Test access
aws sts get-caller-identity
aws s3 ls s3://$VM_S3_BUCKET
```

**Common issues:**
- Incorrect bucket name or region
- Insufficient S3 permissions
- Expired or invalid credentials
- Network connectivity issues

## Migration from Command Line Arguments

If you're currently using command line arguments, you can easily migrate:

### Extract Current Arguments
```bash
# If you're currently running:
# sudo ./install.sh --bucket "my-bucket" --access-key "AKIA..." --secret-key "wJalr..."

# Create equivalent .env file:
cat > .env << EOF
VM_S3_BUCKET="my-bucket"
VM_AWS_ACCESS_KEY="AKIA..."
VM_AWS_SECRET_KEY="wJalr..."
EOF

# Now simply run:
sudo ./install.sh
```

### Verify Migration
After creating the .env file, test that the installation script loads the correct values:
```bash
# This should show your configuration without running installation
sudo ./install.sh --help
```

The new environment variable approach provides better security, easier automation, and cleaner deployment workflows while maintaining full backward compatibility with command line arguments. 