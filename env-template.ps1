# VM Utilization Agent - PowerShell Environment Variables Template
# Copy this file to .env.ps1 and fill in your actual values

# Telegraf Configuration
$env:VM_TELEGRAF_URL = "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_windows_amd64.zip"

# AWS S3 Configuration
$env:VM_S3_BUCKET = "your-metrics-bucket-name"
$env:VM_AWS_REGION = "us-east-1"
$env:VM_AWS_ACCESS_KEY = "AKIA..."
$env:VM_AWS_SECRET_KEY = "wJalrXUtn..."

# Customer Configuration
$env:VM_CUSTOMER_ID = "your-customer-id"

<#
IMPORTANT NOTES:
1. Never commit this file with real credentials to version control
2. The .gitignore file is configured to exclude .env.ps1 files
3. Run this script with: . .\.env.ps1 before running install.ps1
4. Ensure the S3 bucket exists and your AWS credentials have appropriate permissions

Required S3 Permissions:
- s3:PutObject
- s3:PutObjectAcl  
- s3:GetObject
- s3:ListBucket
- s3:DeleteObject (for cleanup)
#> 