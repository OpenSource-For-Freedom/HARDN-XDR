# GitHub Copilot Instructions for HARDN-XDR

## Project Overview

HARDN-XDR is a Debian-based security hardening solution focused on government and enterprise compliance standards. This repository implements comprehensive endpoint security with multi-architecture support (AMD64/ARM64) and targets STIG compliance for Linux systems.

## Core Architecture

### Main Components
- **hardn-xdr**: Main executable wrapper script
- **src/setup/hardn-main.sh**: Core hardening orchestration script
- **src/setup/modules/**: 41 individual security hardening modules
- **hardn_audit.sh**: Compliance auditing and dashboard generation
- **frontend/dashboard/**: Matrix-themed compliance reporting dashboard
- **.github/workflows/ci.yml**: Multi-architecture CI/CD pipeline

### Key Technologies
- **Shell Scripting**: Primary language for system hardening
- **Debian Packaging**: `.deb` package generation and distribution
- **Docker**: Multi-architecture testing (AMD64/ARM64)
- **HTML/CSS/JavaScript**: Compliance dashboard frontend
- **GitHub Actions**: Automated testing and release workflow

## Security Frameworks Implemented

### 1. DISA STIG (Security Technical Implementation Guide)
- Government-mandated security standards
- Focus on access control, audit logging, and system hardening
- Module examples: `auditd.sh`, `sshd.sh`, `credential_protection.sh`

### 2. CIS Controls (Center for Internet Security)
- Industry-standard security benchmarks
- Inventory, configuration, and continuous monitoring
- Module examples: `auto_updates.sh`, `service_disable.sh`, `network_protocols.sh`

### 3. FIPS 140-2 Compliance
- Federal cryptographic standards
- Secure cryptographic implementations
- Module examples: `kernel_sec.sh`, `shared_mem.sh`

### 4. Debian Security Standards
- Distribution-specific hardening
- Package management and system integrity
- Module examples: `debsums.sh`, `purge_old_pkgs.sh`, `file_perms.sh`

## Development Guidelines

### Code Style and Standards
```bash
# Always use proper error handling
set -euo pipefail

# Source common functions
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh

# Use standardized logging
HARDN_STATUS "info" "Starting module execution"
HARDN_STATUS "error" "Error message with context"

# Check for root privileges
[[ $EUID -eq 0 ]] || { HARDN_STATUS "error" "Root required"; exit 1; }
```

### Module Development Pattern
```bash
#!/usr/bin/env bash
# Module: module_name.sh
# Purpose: Brief description of security objective
# Compliance: STIG-ID, CIS-Control-X, etc.

# Source common functions
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh

module_main() {
    HARDN_STATUS "info" "Applying [Module Name] hardening..."
    
    # Implementation here
    
    HARDN_STATUS "success" "[Module Name] hardening complete"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    module_main "$@"
fi
```

### Testing Patterns
- All modules must work in headless/CI environments
- Use `SKIP_WHIPTAIL=1` for non-interactive mode
- Implement proper exit codes and error handling
- Test on both AMD64 and ARM64 architectures

## Common Issues and Solutions

### 1. Missing Function Definitions
**Problem**: Functions called but not defined (e.g., `create_scheduled_task`)
**Solution**: 
- Check `hardn-common.sh` for shared functions
- Implement missing functions in appropriate location
- Ensure proper sourcing of common libraries

### 2. CI/CD Environment Compatibility
**Problem**: Scripts failing in Docker/CI environments
**Solution**:
- Auto-detect CI environment: `[[ -n "$CI" || -n "$GITHUB_ACTIONS" ]]`
- Set non-interactive mode: `export SKIP_WHIPTAIL=1`
- Use `DEBIAN_FRONTEND=noninteractive`

### 3. Multi-Architecture Support
**Problem**: Architecture-specific issues
**Solution**:
- Test on both AMD64 and ARM64
- Use architecture-agnostic commands
- Leverage QEMU emulation in CI

### 4. Package Dependencies
**Problem**: Missing required packages
**Solution**:
- Update `debian/control` with dependencies
- Use `apt-get install -f` for dependency resolution
- Handle missing packages gracefully

## Security Module Categories

### Network Security
- `ufw.sh`: Uncomplicated Firewall configuration
- `fail2ban.sh`: Intrusion prevention system
- `sshd.sh`: SSH daemon hardening
- `dns_config.sh`: DNS security configuration
- `suricata.sh`: Network threat detection

### System Hardening
- `kernel_sec.sh`: Kernel parameter security
- `coredumps.sh`: Core dump restrictions
- `shared_mem.sh`: Shared memory protection
- `binfmt.sh`: Binary format restrictions
- `firewire.sh`: FireWire interface controls

### Access Control
- `credential_protection.sh`: Password policies
- `selinux.sh`: Security-Enhanced Linux
- `apparmor.sh`: Application armor profiles
- `audit_system.sh`: System audit configuration
- `process_protection.sh`: Process isolation

### Malware Detection
- `chkrootkit.sh`: Rootkit detection
- `rkhunter.sh`: Rootkit hunter
- `yara.sh`: Malware signature detection
- `behavioral_analysis.sh`: Behavioral monitoring
- `unhide.sh`: Hidden process detection

### File Integrity
- `aide.sh`: Advanced Intrusion Detection Environment
- `debsums.sh`: Debian package integrity
- `deleted_files.sh`: Deleted file monitoring
- `file_perms.sh`: File permission hardening

## CI/CD Workflow Understanding

### Build Process
1. **Multi-Architecture Matrix**: Builds for AMD64 and ARM64
2. **Package Creation**: Generates `.deb` packages using `dpkg-buildpackage`
3. **Linting**: Uses `lintian` for package validation
4. **Deployment Testing**: Full simulation in Docker containers

### Testing Strategy
- **Headless Execution**: All modules tested in non-interactive mode
- **Timeout Protection**: 300-second timeout per module
- **Log Collection**: Comprehensive logging for debugging
- **Pass/Fail Tracking**: Automated test result aggregation

### Release Automation
- **Version Bumping**: Automatic patch version increment
- **Asset Generation**: Multi-architecture packages and logs
- **GitHub Releases**: Automated release creation with assets

## Contributing Guidelines

### When Adding New Modules
1. Follow the module development pattern
2. Include proper compliance documentation
3. Implement both interactive and headless modes
4. Add comprehensive error handling
5. Update documentation and module lists

### When Fixing Existing Issues
1. Understand the security implications
2. Test on both architectures
3. Maintain backward compatibility
4. Document changes in compliance context
5. Update relevant tests

### Security Considerations
- **Never hardcode secrets**: Use environment variables or secure input
- **Validate inputs**: Sanitize all user inputs and file paths
- **Principle of least privilege**: Apply minimal necessary permissions
- **Audit trail**: Ensure all changes are logged
- **Rollback capability**: Provide methods to undo changes when possible

## Debugging and Troubleshooting

### Log Locations
- Module execution logs: `/var/log/hardn-ci-debian/`
- Compliance audit logs: `frontend/dashboard/compliance.log`
- CI test logs: Artifact downloads from GitHub Actions

### Common Debug Commands
```bash
# Test module individually
sudo bash src/setup/modules/module_name.sh

# Run in debug mode
SKIP_WHIPTAIL=1 bash -x src/setup/hardn-main.sh

# Check compliance status
sudo ./hardn_audit.sh

# View dashboard
# Visit: http://localhost:8021/hardn-compliance.html
```

### Environment Variables
- `SKIP_WHIPTAIL=1`: Non-interactive mode
- `DEBIAN_FRONTEND=noninteractive`: Suppress debconf prompts
- `CI=true`: Indicates CI environment
- `GITHUB_ACTIONS=true`: GitHub Actions environment

## Integration Points

### External Tools Integration
- **Lynis**: System auditing tool (consider integration)
- **OpenSCAP**: SCAP protocol implementation
- **AIDE**: File integrity monitoring
- **Fail2Ban**: Intrusion prevention
- **Suricata**: Network threat detection

### Dashboard Integration
- Real-time compliance metrics
- Multi-standard progress tracking (STIG, FIPS, CIS, Debian)
- Visual reporting with charts and progress bars
- Auto-server deployment after audit completion

This documentation should guide GitHub Copilot in understanding the project structure, security objectives, and development patterns specific to HARDN-XDR.