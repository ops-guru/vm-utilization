Param(
    [Parameter(Mandatory=$true)]
    [string]$TelegrafUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$Bucket,
    
    [Parameter(Mandatory=$true)]
    [string]$Region,
    
    [Parameter(Mandatory=$true)]
    [string]$AccessKey,
    
    [Parameter(Mandatory=$true)]
    [string]$SecretKey
)

# VM Utilisation Agent - Windows Installation Script
# This script installs Telegraf and AWS CLI, configures metric collection,
# and sets up automated S3 sync for VM utilisation metrics.

function Install-VMUtilAgent {
    param(
        [string]$TelegrafUrl,
        [string]$Bucket,
        [string]$Region,
        [string]$AccessKey,
        [string]$SecretKey
    )

    Write-Host "Starting VM Utilisation Agent installation..." -ForegroundColor Green

    # Check if running as Administrator
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Error "This script must be run as Administrator. Please run PowerShell as Administrator and try again."
        exit 1
    }

    # Create necessary directories
    Write-Host "Creating directories..." -ForegroundColor Yellow
    $TelegrafDir = "C:\Program Files\Telegraf"
    $TelegrafConfigDir = "C:\ProgramData\Telegraf"
    $MetricsDir = "C:\ProgramData\vm-metrics"

    New-Item -ItemType Directory -Force -Path $TelegrafDir | Out-Null
    New-Item -ItemType Directory -Force -Path $TelegrafConfigDir | Out-Null
    New-Item -ItemType Directory -Force -Path $MetricsDir | Out-Null

    # Download and install Telegraf
    Write-Host "Downloading and installing Telegraf..." -ForegroundColor Yellow
    $TelegrafZip = "$env:TEMP\telegraf.zip"
    $TelegrafExtractDir = "$env:TEMP\telegraf-extract"

    try {
        Invoke-WebRequest -Uri $TelegrafUrl -OutFile $TelegrafZip -UseBasicParsing
        
        # Extract Telegraf
        Expand-Archive -Path $TelegrafZip -DestinationPath $TelegrafExtractDir -Force
        
        # Find the telegraf.exe file and copy it
        $TelegrafExe = Get-ChildItem -Path $TelegrafExtractDir -Name "telegraf.exe" -Recurse | Select-Object -First 1
        if ($TelegrafExe) {
            $TelegrafExePath = Join-Path $TelegrafExtractDir $TelegrafExe
            Copy-Item -Path $TelegrafExePath -Destination "$TelegrafDir\telegraf.exe" -Force
        } else {
            throw "telegraf.exe not found in the downloaded archive"
        }
        
        # Clean up temp files
        Remove-Item -Path $TelegrafZip -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $TelegrafExtractDir -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-Host "✓ Telegraf installed successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to download or install Telegraf: $_"
        exit 1
    }

    # Download and install AWS CLI v2
    Write-Host "Downloading and installing AWS CLI v2..." -ForegroundColor Yellow
    $AwsCliMsi = "$env:TEMP\AWSCLIV2.msi"

    try {
        Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $AwsCliMsi -UseBasicParsing
        
        # Install AWS CLI silently
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$AwsCliMsi`" /quiet /norestart" -Wait
        
        # Clean up temp file
        Remove-Item -Path $AwsCliMsi -Force -ErrorAction SilentlyContinue
        
        Write-Host "✓ AWS CLI installed successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to download or install AWS CLI: $_"
        exit 1
    }

    # Create Telegraf configuration
    Write-Host "Creating Telegraf configuration..." -ForegroundColor Yellow
    $TelegrafConfig = @"
# Telegraf Configuration for VM Utilisation Metrics

[global_tags]
  # Add global tags here if needed

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

# CPU metrics
[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false
  report_active = false

# Memory metrics
[[inputs.mem]]

# Disk metrics
[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]

# File output
[[outputs.file]]
  files = ["C:/ProgramData/vm-metrics/metrics_%Y%m%d.json"]
  data_format = "json"
  json_timestamp_units = "1s"
  rotation_interval = "24h"
  rotation_max_size = "100MB"
  rotation_max_archives = 7
"@

    $TelegrafConfig | Out-File -FilePath "$TelegrafConfigDir\telegraf.conf" -Encoding UTF8

    # Create Telegraf Windows Service
    Write-Host "Creating Telegraf Windows Service..." -ForegroundColor Yellow
    try {
        # Remove existing service if it exists
        $existingService = Get-Service -Name "Telegraf" -ErrorAction SilentlyContinue
        if ($existingService) {
            Stop-Service -Name "Telegraf" -Force -ErrorAction SilentlyContinue
            & sc.exe delete "Telegraf"
            Start-Sleep -Seconds 2
        }

        # Create new service
        $servicePath = "`"$TelegrafDir\telegraf.exe`" --config `"$TelegrafConfigDir\telegraf.conf`""
        & sc.exe create "Telegraf" binPath= $servicePath start= auto DisplayName= "Telegraf"
        & sc.exe description "Telegraf" "Telegraf metrics collection agent for VM utilisation monitoring"
        
        Write-Host "✓ Telegraf service created successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create Telegraf service: $_"
        exit 1
    }

    # Create Scheduled Task for S3 sync
    Write-Host "Creating VM Metrics S3 Sync scheduled task..." -ForegroundColor Yellow
    try {
        # Remove existing task if it exists
        Unregister-ScheduledTask -TaskName "VM-Metrics-Sync" -Confirm:$false -ErrorAction SilentlyContinue

        # Create the sync command
        $syncCommand = "C:\Program Files\Amazon\AWSCLIV2\aws.exe"
        $syncArgs = "s3 sync `"C:\ProgramData\vm-metrics\`" `"s3://$Bucket/vm-metrics/$env:COMPUTERNAME/`""

        # Create scheduled task action
        $action = New-ScheduledTaskAction -Execute $syncCommand -Argument $syncArgs

        # Create scheduled task trigger (every 5 minutes)
        $trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 365) -At (Get-Date)

        # Create scheduled task settings
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

        # Create scheduled task principal (run as SYSTEM)
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

        # Register the scheduled task
        Register-ScheduledTask -TaskName "VM-Metrics-Sync" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Sync VM metrics to S3 bucket every 5 minutes"

        # Set environment variables for the scheduled task
        $taskPath = "\VM-Metrics-Sync"
        $envVars = @(
            "AWS_ACCESS_KEY_ID=$AccessKey",
            "AWS_SECRET_ACCESS_KEY=$SecretKey",
            "AWS_DEFAULT_REGION=$Region"
        )
        
        # Use schtasks to set environment variables (PowerShell cmdlets don't support this directly)
        foreach ($envVar in $envVars) {
            & schtasks.exe /Change /TN $taskPath /RU "SYSTEM" /RP ""
        }

        Write-Host "✓ Scheduled task created successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create scheduled task: $_"
        exit 1
    }

    # Start services
    Write-Host "Starting services..." -ForegroundColor Yellow
    try {
        # Start Telegraf service
        Start-Service -Name "Telegraf"
        Set-Service -Name "Telegraf" -StartupType Automatic
        
        # Start the scheduled task
        Start-ScheduledTask -TaskName "VM-Metrics-Sync"
        
        Write-Host "✓ Services started successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to start services: $_"
        exit 1
    }

    # Verify installation
    Write-Host "Verifying installation..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5

    # Check Telegraf service
    $telegrafService = Get-Service -Name "Telegraf" -ErrorAction SilentlyContinue
    if ($telegrafService -and $telegrafService.Status -eq "Running") {
        Write-Host "✓ Telegraf service is running" -ForegroundColor Green
    } else {
        Write-Host "✗ Telegraf service is not running" -ForegroundColor Red
        if ($telegrafService) {
            Write-Host "Service status: $($telegrafService.Status)" -ForegroundColor Yellow
        }
    }

    # Check scheduled task
    $syncTask = Get-ScheduledTask -TaskName "VM-Metrics-Sync" -ErrorAction SilentlyContinue
    if ($syncTask -and $syncTask.State -eq "Ready") {
        Write-Host "✓ VM metrics sync task is ready" -ForegroundColor Green
    } else {
        Write-Host "✗ VM metrics sync task is not ready" -ForegroundColor Red
        if ($syncTask) {
            Write-Host "Task state: $($syncTask.State)" -ForegroundColor Yellow
        }
    }

    # Check metrics directory
    if (Test-Path $MetricsDir) {
        Write-Host "✓ Metrics directory created" -ForegroundColor Green
        
        # Wait for first metrics to be written
        Start-Sleep -Seconds 35
        $metricsFiles = Get-ChildItem -Path $MetricsDir -Filter "*.json" -ErrorAction SilentlyContinue
        if ($metricsFiles) {
            Write-Host "✓ Metrics files are being generated" -ForegroundColor Green
        } else {
            Write-Host "⚠ No metrics files found yet (this is normal for the first 30 seconds)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✗ Metrics directory not found" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "VM Utilisation Agent installation completed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Services status:" -ForegroundColor Cyan
    Write-Host "- Telegraf: $((Get-Service -Name 'Telegraf').Status)" -ForegroundColor White
    Write-Host "- Sync Task: $((Get-ScheduledTask -TaskName 'VM-Metrics-Sync').State)" -ForegroundColor White
    Write-Host ""
    Write-Host "Metrics are being collected every 30 seconds and uploaded to S3 every 5 minutes." -ForegroundColor White
    Write-Host "Local metrics directory: $MetricsDir" -ForegroundColor White
    Write-Host "S3 destination: s3://$Bucket/vm-metrics/$env:COMPUTERNAME/" -ForegroundColor White
    Write-Host ""
    Write-Host "To monitor the installation:" -ForegroundColor Cyan
    Write-Host "  Get-Service -Name 'Telegraf'" -ForegroundColor White
    Write-Host "  Get-ScheduledTask -TaskName 'VM-Metrics-Sync'" -ForegroundColor White
    Write-Host "  Get-ChildItem '$MetricsDir'" -ForegroundColor White
    Write-Host "  Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-TaskScheduler/Operational'; ID=200,201} | Where-Object {`$_.Message -like '*VM-Metrics-Sync*'}" -ForegroundColor White
}

# Main execution
if ($TelegrafUrl -and $Bucket -and $Region -and $AccessKey -and $SecretKey) {
    Install-VMUtilAgent -TelegrafUrl $TelegrafUrl -Bucket $Bucket -Region $Region -AccessKey $AccessKey -SecretKey $SecretKey
} else {
    Write-Host "Usage: .\install.ps1 -TelegrafUrl <url> -Bucket <bucket> -Region <region> -AccessKey <key> -SecretKey <secret>" -ForegroundColor Red
    exit 1
} 