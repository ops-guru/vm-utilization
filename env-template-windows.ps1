# VM Utilization Agent Environment Variables
# Copy this file to .env.ps1 and update with your actual values

$env:VM_TELEGRAF_URL = "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_windows_amd64.zip"
$env:VM_S3_BUCKET = "og-ai-lab-vm-metrics"
$env:VM_AWS_ACCESS_KEY = "AKIAYM7POORF4D525Z4M"
$env:VM_AWS_SECRET_KEY = "GoL29qTSNuO+qLua2UyV75q1OVZbQ1/HWnLOKrKDGoL29qTSNuO+qLua2UyV75q1OVZbQ1/HWnLOKrKDGoL29qTSNuO+qLua2UyV75q1OVZbQ1/HWnLOKrKDGoL29qTSNuO+qLua2UyV75q1OVZbQ1/HWnLOKrKDGoL29qTSNuO+qLua2UyV75q1OVZbQ1/HWnLOKrKD"
$env:VM_AWS_REGION = "us-east-1"
$env:VM_CUSTOMER_ID = "azure-lab-customer"

Write-Host "Environment variables loaded for VM Utilization Agent" -ForegroundColor Green
Write-Host "Bucket: $env:VM_S3_BUCKET" -ForegroundColor Cyan
Write-Host "Region: $env:VM_AWS_REGION" -ForegroundColor Cyan
Write-Host "Customer ID: $env:VM_CUSTOMER_ID" -ForegroundColor Cyan 