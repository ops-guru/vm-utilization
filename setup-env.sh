#!/bin/bash

# VM Utilization Agent - Environment Setup Script
# This script creates the .env file for your Azure lab testing environment

set -e

echo "🔧 VM Utilization Agent - Environment Setup"
echo "============================================"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if .env already exists
if [[ -f ".env" ]]; then
    log_warning ".env file already exists"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Keeping existing .env file"
        exit 0
    fi
fi

# Prompt for AWS credentials
echo
log_info "Setting up environment variables for your Azure lab..."
echo

# AWS S3 Bucket
read -p "Enter your S3 bucket name (or press Enter to generate one): " BUCKET_NAME
if [[ -z "$BUCKET_NAME" ]]; then
    BUCKET_NAME="vm-metrics-test-$(date +%s)"
    log_info "Generated bucket name: $BUCKET_NAME"
fi

# AWS Region
read -p "Enter AWS region [us-east-1]: " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

# AWS Access Key
read -p "Enter your AWS Access Key ID: " AWS_ACCESS_KEY
if [[ -z "$AWS_ACCESS_KEY" ]]; then
    log_error "AWS Access Key is required"
    exit 1
fi

# AWS Secret Key (hidden input)
echo -n "Enter your AWS Secret Access Key: "
read -s AWS_SECRET_KEY
echo
if [[ -z "$AWS_SECRET_KEY" ]]; then
    log_error "AWS Secret Key is required"
    exit 1
fi

# Customer ID
read -p "Enter Customer ID [azure-lab-customer]: " CUSTOMER_ID
CUSTOMER_ID=${CUSTOMER_ID:-azure-lab-customer}

# Create .env file
log_info "Creating .env file..."
cat > .env << EOF
# VM Utilization Agent - Environment Variables for Azure Lab Testing
# Generated on $(date)

# Telegraf Configuration
VM_TELEGRAF_URL="https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_linux_amd64.tar.gz"

# AWS S3 Configuration
VM_S3_BUCKET="$BUCKET_NAME"
VM_AWS_REGION="$AWS_REGION"
VM_AWS_ACCESS_KEY="$AWS_ACCESS_KEY"
VM_AWS_SECRET_KEY="$AWS_SECRET_KEY"

# Customer Configuration
VM_CUSTOMER_ID="$CUSTOMER_ID"

# AUTO-GENERATED FOR AZURE LAB TESTING
# Your Azure VMs:
# - Linux VM hostname: azlab-linux-vm
# - Windows VM hostname: azlab-windows-vm
# - Metrics S3 path: s3://$BUCKET_NAME/vm-metrics/hostname/
EOF

# Set secure permissions on .env file
chmod 600 .env

log_success ".env file created successfully!"

# Test AWS credentials
log_info "Testing AWS credentials..."
if command -v aws &> /dev/null; then
    export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY"
    export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_KEY"
    export AWS_DEFAULT_REGION="$AWS_REGION"
    
    if aws sts get-caller-identity &>/dev/null; then
        log_success "AWS credentials are valid"
        
        # Check if bucket exists, create if not
        if aws s3 ls "s3://$BUCKET_NAME" &>/dev/null; then
            log_success "S3 bucket '$BUCKET_NAME' exists"
        else
            log_info "Creating S3 bucket '$BUCKET_NAME'..."
            if aws s3 mb "s3://$BUCKET_NAME"; then
                log_success "S3 bucket created successfully"
            else
                log_warning "Could not create S3 bucket. You may need to create it manually."
            fi
        fi
    else
        log_warning "AWS credentials test failed. Please verify your credentials."
    fi
else
    log_warning "AWS CLI not found. Install it to test credentials automatically."
fi

echo
log_success "Environment setup completed!"
echo
log_info "Configuration summary:"
log_info "  Bucket: $BUCKET_NAME"
log_info "  Region: $AWS_REGION"
log_info "  Customer ID: $CUSTOMER_ID"
log_info "  Access Key: ${AWS_ACCESS_KEY:0:8}..."
echo
log_info "Next steps:"
log_info "  1. Copy the install scripts to your VMs"
log_info "  2. Copy the .env file to the same directory as install.sh"
log_info "  3. Run: sudo ./install.sh"
echo
log_info "For Windows VMs, create .env.ps1:"
log_info "  cp env-template.ps1 .env.ps1"
log_info "  # Edit .env.ps1 with your values"
log_info "  # Run: . ./.env.ps1 ; ./install.ps1" 