# VM Utilization Agent Installer for Windows
# Supports environment variables and command-line parameters
# Environment variables take precedence over command-line parameters

[CmdletBinding()]
param(
    [string]$TelegrafUrl = "",
    [string]$Bucket = "",
    [string]$Region = "us-east-1",
    [string]$AccessKey = "",
    [string]$SecretKey = "",
    [string]$CustomerId = "default-customer",
    [switch]$Help
)

# Function to show usage
function Show-Usage {
    Write-Host @"
VM Utilization Agent Installer for Windows

USAGE:
    .\install.ps1 [OPTIONS]

ENVIRONMENT VARIABLES (recommended):
    VM_TELEGRAF_URL      - Telegraf download URL
    VM_S3_BUCKET         - S3 bucket name for metrics storage
    VM_AWS_REGION        - AWS region (default: us-east-1)
    VM_AWS_ACCESS_KEY    - AWS access key
    VM_AWS_SECRET_KEY    - AWS secret key
    VM_CUSTOMER_ID       - Customer identifier (default: default-customer)

COMMAND LINE PARAMETERS (override environment variables):
    -TelegrafUrl URL     - Telegraf download URL
    -Bucket BUCKET       - S3 bucket name
    -Region REGION       - AWS region
    -AccessKey KEY       - AWS access key
    -SecretKey KEY       - AWS secret key
    -CustomerId ID       - Customer identifier
    -Help                - Show this help message

EXAMPLES:
    # Using environment variables (recommended):
    `$env:VM_TELEGRAF_URL = "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_windows_amd64.zip"
    `$env:VM_S3_BUCKET = "my-metrics-bucket"
    `$env:VM_AWS_ACCESS_KEY = "AKIA..."
    `$env:VM_AWS_SECRET_KEY = "wJalr..."
    .\install.ps1

    # Using command line parameters:
    .\install.ps1 -TelegrafUrl "https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_windows_amd64.zip" ``
                  -Bucket "my-metrics-bucket" ``
                  -AccessKey "AKIA..." ``
                  -SecretKey "wJalr..."

NOTES:
    - Environment variables take precedence over command-line parameters
    - Create a .env.ps1 file in the same directory to load variables automatically
    - All AWS credentials are stored securely and not logged
    - Requires Administrator privileges for installation

"@ -ForegroundColor Green
}

# Show help if requested
if ($Help) {
    Show-Usage
    exit 0
}

# Load environment variables from .env.ps1 file if it exists
$envFile = Join-Path $PSScriptRoot ".env.ps1"
if (Test-Path $envFile) {
    Write-Host "[INFO] Loading environment variables from .env.ps1 file..." -ForegroundColor Blue
    . $envFile
}

# Use environment variables if available, otherwise use parameters
$TelegrafUrl = if ($env:VM_TELEGRAF_URL) { $env:VM_TELEGRAF_URL } else { $TelegrafUrl }
$Bucket = if ($env:VM_S3_BUCKET) { $env:VM_S3_BUCKET } else { $Bucket }
$Region = if ($env:VM_AWS_REGION) { $env:VM_AWS_REGION } else { $Region }
$AccessKey = if ($env:VM_AWS_ACCESS_KEY) { $env:VM_AWS_ACCESS_KEY } else { $AccessKey }
$SecretKey = if ($env:VM_AWS_SECRET_KEY) { $env:VM_AWS_SECRET_KEY } else { $SecretKey }
$CustomerId = if ($env:VM_CUSTOMER_ID) { $env:VM_CUSTOMER_ID } else { $CustomerId }

# Logging functions
function Write-Info($message) {
    Write-Host "[INFO] $message" -ForegroundColor Blue
}

function Write-Success($message) {
    Write-Host "[SUCCESS] $message" -ForegroundColor Green
}

function Write-Warning($message) {
    Write-Host "[WARNING] $message" -ForegroundColor Yellow
}

function Write-Error($message) {
    Write-Host "[ERROR] $message" -ForegroundColor Red
}

# Function to validate required parameters
function Test-Parameters {
    $missingParams = @()
    
    if (-not $TelegrafUrl) {
        $missingParams += "VM_TELEGRAF_URL or -TelegrafUrl"
    }
    
    if (-not $Bucket) {
        $missingParams += "VM_S3_BUCKET or -Bucket"
    }
    
    if (-not $AccessKey) {
        $missingParams += "VM_AWS_ACCESS_KEY or -AccessKey"
    }
    
    if (-not $SecretKey) {
        $missingParams += "VM_AWS_SECRET_KEY or -SecretKey"
    }
    
    if ($missingParams.Count -gt 0) {
        Write-Error "Missing required parameters:"
        foreach ($param in $missingParams) {
            Write-Error "  - $param"
        }
        Write-Host ""
        Show-Usage
        exit 1
    }
}

Write-Info "Starting VM Utilization Agent installation..."

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator"
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Validate parameters
Test-Parameters

# Log configuration (without sensitive data)
Write-Info "Configuration:"
Write-Info "  Telegraf URL: $TelegrafUrl"
Write-Info "  S3 Bucket: $Bucket"
Write-Info "  AWS Region: $Region"
Write-Info "  Customer ID: $CustomerId"
Write-Info "  AWS Access Key: $($AccessKey.Substring(0, [Math]::Min(8, $AccessKey.Length)))..."

# Set up directories
$InstallDir = "C:\Program Files\Telegraf"
$MetricsDir = "C:\ProgramData\vm-metrics"
$ConfigDir = "C:\ProgramData\Telegraf"

Write-Info "Creating directories..."
$null = New-Item -Path $InstallDir -ItemType Directory -Force
$null = New-Item -Path $MetricsDir -ItemType Directory -Force
$null = New-Item -Path $ConfigDir -ItemType Directory -Force

# Download and install Telegraf
Write-Info "Downloading Telegraf..."
$TelegrafZip = "$env:TEMP\telegraf.zip"
$TelegrafExtract = "$env:TEMP\telegraf_extract"

try {
    Invoke-WebRequest -Uri $TelegrafUrl -OutFile $TelegrafZip -UseBasicParsing
    Write-Success "Telegraf downloaded successfully"
} catch {
    Write-Error "Failed to download Telegraf from $TelegrafUrl"
    Write-Error $_.Exception.Message
    exit 1
}

Write-Info "Installing Telegraf..."
if (Test-Path $TelegrafExtract) {
    Remove-Item $TelegrafExtract -Recurse -Force
}
$null = New-Item -Path $TelegrafExtract -ItemType Directory -Force

# Extract Telegraf
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($TelegrafZip, $TelegrafExtract)
    
    # Find telegraf.exe in extracted directory
    $TelegrafExe = Get-ChildItem -Path $TelegrafExtract -Name "telegraf.exe" -Recurse | Select-Object -First 1
    if (-not $TelegrafExe) {
        throw "telegraf.exe not found in downloaded archive"
    }
    
    $TelegrafSource = Join-Path $TelegrafExtract $TelegrafExe.DirectoryName "telegraf.exe"
    $TelegrafTarget = Join-Path $InstallDir "telegraf.exe"
    
    Copy-Item $TelegrafSource $TelegrafTarget -Force
    Write-Success "Telegraf installed to $TelegrafTarget"
} catch {
    Write-Error "Failed to extract and install Telegraf"
    Write-Error $_.Exception.Message
    exit 1
}

# Create Telegraf configuration
Write-Info "Creating Telegraf configuration..."
$TelegrafConfig = @"
# VM Utilization Agent Configuration
[global_tags]
  customer_id = "$CustomerId"

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
  files = ["$($MetricsDir.Replace('\', '\\'))\\metrics_%Y%m%d.json"]
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
"@

$ConfigFile = Join-Path $ConfigDir "telegraf.conf"
$TelegrafConfig | Out-File -FilePath $ConfigFile -Encoding UTF8
Write-Success "Telegraf configuration created at $ConfigFile"

# Install AWS CLI if not present
if (-not (Get-Command "aws" -ErrorAction SilentlyContinue)) {
    Write-Info "Installing AWS CLI..."
    try {
        $AwsCliUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
        $AwsCliMsi = "$env:TEMP\AWSCLIV2.msi"
        
        Invoke-WebRequest -Uri $AwsCliUrl -OutFile $AwsCliMsi -UseBasicParsing
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$AwsCliMsi`" /quiet" -Wait
        
        # Add AWS CLI to PATH for current session
        $env:PATH += ";C:\Program Files\Amazon\AWSCLIV2"
        
        Write-Success "AWS CLI installed successfully"
    } catch {
        Write-Error "Failed to install AWS CLI"
        Write-Error $_.Exception.Message
        exit 1
    }
}

# Configure AWS credentials
Write-Info "Configuring AWS credentials..."
$AwsDir = Join-Path $env:USERPROFILE ".aws"
if (-not (Test-Path $AwsDir)) {
    $null = New-Item -Path $AwsDir -ItemType Directory -Force
}

$CredentialsContent = @"
[default]
aws_access_key_id = $AccessKey
aws_secret_access_key = $SecretKey
"@

$ConfigContent = @"
[default]
region = $Region
output = json
"@

$CredentialsFile = Join-Path $AwsDir "credentials"
$ConfigFile = Join-Path $AwsDir "config"

$CredentialsContent | Out-File -FilePath $CredentialsFile -Encoding UTF8
$ConfigContent | Out-File -FilePath $ConfigFile -Encoding UTF8

# Set secure permissions on AWS credentials
$Acl = Get-Acl $CredentialsFile
$Acl.SetAccessRuleProtection($true, $false)
$AdminRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "Allow")
$UserRule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, "FullControl", "Allow")
$Acl.SetAccessRule($AdminRule)
$Acl.SetAccessRule($UserRule)
Set-Acl -Path $CredentialsFile -AclObject $Acl

Write-Success "AWS credentials configured"

# Create Telegraf Windows service
Write-Info "Creating Telegraf service..."
$ServiceName = "Telegraf"
$ServiceDisplayName = "VM Utilization Agent (Telegraf)"
$ServiceDescription = "Collects VM utilization metrics"
$TelegrafExePath = Join-Path $InstallDir "telegraf.exe"
$ServiceArgs = "--config `"$ConfigFile`""

# Remove existing service if it exists
$ExistingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($ExistingService) {
    Write-Info "Removing existing Telegraf service..."
    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    & sc.exe delete $ServiceName
    Start-Sleep -Seconds 2
}

# Create new service
try {
    & sc.exe create $ServiceName binPath= "`"$TelegrafExePath`" $ServiceArgs" DisplayName= $ServiceDisplayName start= auto
    & sc.exe description $ServiceName $ServiceDescription
    
    Write-Success "Telegraf service created successfully"
} catch {
    Write-Error "Failed to create Telegraf service"
    Write-Error $_.Exception.Message
    exit 1
}

# Create S3 sync script
Write-Info "Creating S3 sync script..."
$SyncScriptContent = @"
# VM Metrics S3 Sync Script
`$Hostname = `$env:COMPUTERNAME
`$MetricsDir = "$MetricsDir"
`$S3Bucket = "$Bucket"
`$S3Prefix = "vm-metrics/`$Hostname"

# Sync metrics to S3
try {
    & aws s3 sync "`$MetricsDir" "s3://`$S3Bucket/`$S3Prefix" --exclude "*.tmp" --exclude "*.lock" --delete
    Write-EventLog -LogName Application -Source "VM-Metrics-Sync" -EventId 1001 -EntryType Information -Message "Metrics sync completed: `$(Get-Date)"
} catch {
    Write-EventLog -LogName Application -Source "VM-Metrics-Sync" -EventId 1002 -EntryType Error -Message "Metrics sync failed: `$(`$_.Exception.Message)"
}

# Clean up old local files (keep last 7 days)
Get-ChildItem "`$MetricsDir" -Filter "metrics_*.json" | Where-Object { `$_.LastWriteTime -lt (Get-Date).AddDays(-7) } | Remove-Item -Force

Write-Host "Metrics sync completed: `$(Get-Date)"
"@

$SyncScript = Join-Path $ConfigDir "vm-metrics-sync.ps1"
$SyncScriptContent | Out-File -FilePath $SyncScript -Encoding UTF8
Write-Success "S3 sync script created at $SyncScript"

# Create event log source for sync script
try {
    if (-not [System.Diagnostics.EventLog]::SourceExists("VM-Metrics-Sync")) {
        New-EventLog -LogName Application -Source "VM-Metrics-Sync"
    }
} catch {
    Write-Warning "Could not create event log source (this is optional)"
}

# Create scheduled task for S3 sync
Write-Info "Creating scheduled task for S3 sync..."
$TaskName = "VM-Metrics-Sync"
$TaskDescription = "Sync VM metrics to S3 every 5 minutes"

# Remove existing task if it exists
$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($ExistingTask) {
    Write-Info "Removing existing scheduled task..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Create new scheduled task
try {
    $Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$SyncScript`""
    $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 365)
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    $Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -Description $TaskDescription
    Register-ScheduledTask -TaskName $TaskName -InputObject $Task
    
    Write-Success "Scheduled task created successfully"
} catch {
    Write-Error "Failed to create scheduled task"
    Write-Error $_.Exception.Message
    exit 1
}

# Start services
Write-Info "Starting services..."

# Start Telegraf service
try {
    Start-Service -Name $ServiceName
    Write-Success "Telegraf service started"
} catch {
    Write-Error "Failed to start Telegraf service"
    Write-Error $_.Exception.Message
    exit 1
}

# Run the sync task once to test
try {
    Start-ScheduledTask -TaskName $TaskName
    Write-Success "S3 sync task started"
} catch {
    Write-Warning "Could not start sync task immediately (will run on schedule)"
}

# Verify installation
Write-Info "Verifying installation..."
Start-Sleep -Seconds 5

$TelegrafService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($TelegrafService -and $TelegrafService.Status -eq "Running") {
    Write-Success "Telegraf service is running"
} else {
    Write-Error "Telegraf service is not running"
    exit 1
}

$SyncTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($SyncTask) {
    Write-Success "S3 sync task is configured"
} else {
    Write-Error "S3 sync task is not configured"
    exit 1
}

# Test metric collection
Write-Info "Testing metric collection..."
Start-Sleep -Seconds 30
$TodayMetrics = Join-Path $MetricsDir "metrics_$(Get-Date -Format 'yyyyMMdd').json"
if (Test-Path $TodayMetrics) {
    Write-Success "Metrics file created successfully"
    Write-Info "Sample metrics:"
    Get-Content $TodayMetrics | Select-Object -Last 3
} else {
    Write-Warning "Metrics file not yet created (may take a few minutes)"
}

# Cleanup
Remove-Item $TelegrafZip -Force -ErrorAction SilentlyContinue
Remove-Item $TelegrafExtract -Recurse -Force -ErrorAction SilentlyContinue

Write-Success "VM Utilization Agent installation completed successfully!"
Write-Info "Configuration:"
Write-Info "  - Metrics collection: Every 30 seconds"
Write-Info "  - S3 sync: Every 5 minutes"
Write-Info "  - Local storage: $MetricsDir"
Write-Info "  - Service logs: Event Viewer > Windows Logs > System"
Write-Info "  - Sync logs: Event Viewer > Windows Logs > Application"

Write-Host ""
Write-Info "To check status:"
Write-Info "  Get-Service -Name 'Telegraf'"
Write-Info "  Get-ScheduledTask -TaskName 'VM-Metrics-Sync'" 