# Changelog

All notable changes to the VM Utilization Agent project will be documented in this file.

## [2.0.0] - 2025-06-04

### 🚀 Major Enhancements

#### Multi-Distribution Linux Support
- **BREAKING**: Enhanced `install.sh` to support multiple Linux distributions
- **NEW**: Automatic distribution detection for Ubuntu, Debian, CentOS, RHEL, Fedora, openSUSE, SLES, Alpine
- **NEW**: Intelligent package manager selection (apt, yum, dnf, zypper, apk)
- **NEW**: Cross-platform user creation with fallback methods
- **NEW**: Multi-architecture AWS CLI installation (x86_64, aarch64)
- **IMPROVED**: Error handling for unsupported distributions
- **IMPROVED**: Graceful fallback for group ownership commands

#### Code Quality & Cleanup
- **REMOVED**: Duplicate environment files (`.env.ps1`)
- **REMOVED**: Outdated documentation (`VM-Utilisation-Agent-Installation-Guide.md`)
- **REMOVED**: Simulation testing files (`test-simulation.sh`, `TEST-ANALYSIS-REPORT.md`)
- **REMOVED**: Environment-specific setup guide (`WINDOWS-VM-SETUP.md`)
- **RENAMED**: `env-template.ps1` → `env-template-windows.ps1` for clarity
- **UPDATED**: Repository structure documentation

#### Documentation Improvements
- **ENHANCED**: README.md with comprehensive distribution support details
- **NEW**: Linux distribution compatibility matrix
- **IMPROVED**: Installation examples for different package managers
- **UPDATED**: Architecture diagrams and file structure
- **ENHANCED**: Live testing results integration

### 🔧 Technical Changes

#### Installation Script (`install.sh`)
```bash
# New Features:
- detect_distro() - Automatic distribution detection
- install_dependencies() - Distribution-specific package installation
- create_telegraf_user() - Cross-platform user creation
- install_aws_cli() - Multi-architecture AWS CLI installation

# Improved Error Handling:
- Graceful package manager detection
- Fallback user creation methods
- Robust file ownership commands
- Architecture-specific binary selection
```

#### Security Enhancements
- **IMPROVED**: File ownership with error handling (`chown telegraf:telegraf 2>/dev/null || chown telegraf`)
- **ENHANCED**: Distribution-specific package installation
- **MAINTAINED**: Secure credential storage across all platforms

### 🧪 Validation

#### Live Testing Results
- ✅ **Ubuntu 22.04**: Successfully tested on Azure VM
- ✅ **Multi-VM Environment**: Validated with both Linux and Windows VMs
- ✅ **Continuous Operation**: 224+ metrics collected over 12+ minutes
- ✅ **Service Management**: systemd integration working correctly
- ✅ **AWS Integration**: S3 sync architecture validated

#### Performance Metrics
- **Memory Usage**: 30.3MB (minimal footprint)
- **CPU Impact**: 528ms total (very low impact)
- **Metrics Rate**: ~18 metrics/minute sustained
- **Storage Efficiency**: JSON format with daily rotation

### 🔄 Migration Guide

#### From Version 1.x
1. **No breaking changes** for existing installations
2. **Environment variables** remain the same
3. **Service names** unchanged (telegraf, vm-metrics-sync)
4. **File locations** preserved for compatibility

#### New Installations
- Use updated `install.sh` with automatic distribution detection
- Refer to updated README.md for distribution-specific information
- Use `env-template-windows.ps1` instead of deprecated files

### 📋 Supported Platforms

#### Linux Distributions (NEW)
| Distribution | Package Manager | User Creation | Status |
|--------------|----------------|---------------|---------|
| Ubuntu 18.04+ | apt | useradd | ✅ Tested |
| Debian 9+ | apt | useradd | ✅ Supported |
| CentOS 7+ | yum/dnf | useradd | ✅ Supported |
| RHEL 7+ | yum/dnf | useradd | ✅ Supported |
| Fedora 30+ | dnf | useradd | ✅ Supported |
| openSUSE | zypper | useradd | ✅ Supported |
| SLES | zypper | useradd | ✅ Supported |
| Alpine Linux | apk | adduser | ✅ Supported |

#### Windows
- Windows Server 2016+ (unchanged)
- PowerShell 5.1+ (unchanged)

### 🏗 Repository Structure Changes

#### Removed Files
```
❌ .env.ps1                                    # Duplicate of Windows template
❌ VM-Utilisation-Agent-Installation-Guide.md  # Replaced by ENVIRONMENT-SETUP.md
❌ test-simulation.sh                          # Replaced by live testing
❌ TEST-ANALYSIS-REPORT.md                     # Replaced by LIVE-TESTING-REPORT.md  
❌ WINDOWS-VM-SETUP.md                         # Environment-specific, not needed
```

#### Current Structure
```
✅ README.md                     # Updated with multi-distro support
✅ install.sh                    # Enhanced multi-distribution installer
✅ install.ps1                   # Windows installer (unchanged)
✅ env-template-windows.ps1      # Renamed for clarity
✅ LIVE-TESTING-REPORT.md        # Real Azure testing results
✅ ENVIRONMENT-SETUP.md          # Comprehensive setup guide
✅ SECURITY.md                   # Security best practices
```

### 🔮 Next Steps

#### Planned Enhancements
- [ ] Docker container support
- [ ] Kubernetes DaemonSet deployment
- [ ] CloudWatch integration option
- [ ] ARM64 binary testing
- [ ] Container orchestration metrics

#### Community
- [ ] Contribution guidelines
- [ ] Issue templates
- [ ] Community documentation
- [ ] Example configurations

---

For complete installation instructions, see [README.md](README.md)  
For live testing results, see [LIVE-TESTING-REPORT.md](LIVE-TESTING-REPORT.md)  
For security considerations, see [SECURITY.md](SECURITY.md) 