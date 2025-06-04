# VM Utilization Agent Environment Variables Template
# Copy this file to .env.ps1 and update with your actual values

$env:VM_TELEGRAF_URL = "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_windows_amd64.zip"
$env:VM_S3_BUCKET = "your-metrics-bucket-name"
$env:VM_AWS_ACCESS_KEY = "AKIA..."
$env:VM_AWS_SECRET_KEY = "wJalrXUtn..."
$env:VM_AWS_REGION = "us-east-1"
$env:VM_CUSTOMER_ID = "your-customer-id"

Write-Host "Environment variables loaded for VM Utilization Agent" -ForegroundColor Green
Write-Host "Bucket: $env:VM_S3_BUCKET" -ForegroundColor Cyan
Write-Host "Region: $env:VM_AWS_REGION" -ForegroundColor Cyan
Write-Host "Customer ID: $env:VM_CUSTOMER_ID" -ForegroundColor Cyan

# IMPORTANT SECURITY NOTES:
# 1. Never commit this file with real credentials to version control
# 2. The .gitignore file is configured to exclude .env.ps1 files
# 3. Replace "AKIA..." and "wJalrXUtn..." with your actual AWS credentials
# 4. Ensure the S3 bucket exists and your AWS credentials have appropriate permissions

# Required S3 Permissions:
# - s3:PutObject
# - s3:PutObjectAcl  
# - s3:GetObject
# - s3:ListBucket
# - s3:DeleteObject (for cleanup) 