# HARDN-XDR Maintenance and Issue Resolution Playbook

## Overview

This playbook provides systematic approaches for fixing and updating HARDN-XDR based on current GitHub issues and ongoing security compliance requirements. **HARDN-XDR is now optimized for container and VM deployments** with a focus on DISA/FEDHIVE compliance while maintaining desktop compatibility.

## Container and VM-First Architecture

### Environment Detection and Module Selection
HARDN-XDR automatically detects deployment environments and applies appropriate security hardening:

- **Container/VM Environment**: Applies 21 essential DISA compliance modules + 10 optional modules
- **Desktop/Physical Environment**: Maintains full compatibility with all 41+ security modules
- **Performance Optimization**: Skips desktop-focused modules in containers/VMs for better performance

### Module Categories
1. **Essential Container/VM** (21 modules): Core DISA/FEDHIVE compliance requirements
2. **Conditional Container/VM** (10 modules): Optional security vs performance trade-offs  
3. **Desktop-Focused** (10 modules): Physical hardware specific (USB, FireWire, GUI sandboxing)

### Key Optimizations
- Intelligent systemd service handling in containers
- Container-aware network security configuration
- Optimized resource usage for virtualized environments
- Maintained audit logging and compliance requirements

## Current Issue Inventory and Resolution Plan

### Issue #188: Container and VM-First Refactoring (CURRENT)
**Status**: ✅ Completed  
**Priority**: High  
**Category**: Architecture Refactoring

**Objectives**:
- ✅ Refactor project to prioritize container and VM compliance
- ✅ Focus on DISA/FEDHIVE compliance over desktop features  
- ✅ Optimize performance for containerized and virtualized environments
- ✅ Maintain backwards compatibility for desktop users

**Implementation Summary**:
1. **Environment Detection**: Added intelligent container/VM detection
2. **Module Categorization**: 
   - 21 essential modules for DISA/FEDHIVE compliance
   - 10 conditional modules for performance trade-offs
   - 10 desktop-focused modules (skipped in containers/VMs)
3. **Smart Module Selection**: Automatic environment-based module selection
4. **Performance Optimization**: Reduced overhead in container/VM environments
5. **Documentation Updates**: Updated README and playbook for container/VM focus

**Benefits**:
- Faster deployment in container/VM environments
- Reduced resource consumption 
- Maintained security compliance standards
- Preserved desktop functionality

### Issue #182: Build - Copilot Instructions and Playbook
**Status**: In Progress  
**Priority**: High  
**Category**: Documentation and Infrastructure

**Objectives**:
- ✅ Create `.github/copilot-instructions.md`
- ✅ Develop comprehensive maintenance playbook
- 🔄 Focus on Lynis, CIS, DISA compliance frameworks
- 🔄 Enhance CI testing for headless deployment

**Action Items**:
1. Review overall project architecture and security modules
2. Document best practices for security compliance
3. Enhance CI workflow for container/VM/desktop headless testing
4. Create standardized procedures for future maintenance

### Issue #177: Missing Function `create_scheduled_task`
**Status**: Open  
**Priority**: High  
**Category**: Critical Bug Fix

**Problem Analysis**:
- Function `create_scheduled_task` is called but not defined
- Will cause runtime errors when modules are executed
- Affects system scheduling and automation features

**Resolution Steps**:
1. **Locate Function Usage**:
   ```bash
   grep -r "create_scheduled_task" src/setup/modules/
   ```

2. **Implement Missing Function**:
   ```bash
   # Add to hardn-common.sh
   create_scheduled_task() {
       local task_name="$1"
       local command="$2"
       local schedule="$3"
       
       # Implementation using systemd timers or cron
       # STIG compliance requires proper scheduling mechanisms
   }
   ```

3. **Testing Protocol**:
   - Test in CI environment with SKIP_WHIPTAIL=1
   - Verify on both AMD64 and ARM64 architectures
   - Ensure STIG compliance for scheduled tasks

### Issue #175: Security Research Spike - CVE Management
**Status**: Open  
**Priority**: Medium  
**Category**: Security Research and Patching

**CVE Inventory for Debian Bookworm**:
- CVE-2024-3094: Backdoor in xz-utils (fixed in Bookworm)
- CVE-2024-38541: Linux kernel (drm/arm/malidp fix)
- CVE-2024-45490: expat/libxmltok (fixed in Bookworm)
- CVE-2024-48877: catdoc (exec/DOS vulnerabilities)
- CVE-2024-52035: catdoc
- CVE-2024-54028: catdoc
- CVE-2024-56406: Perl heap overflow
- CVE-2024-6387: OpenSSH (Bookworm fixed)
- CVE-2025-1390: libcap2 (fixed in Bookworm)
- CVE-2025-24855: libxslt (fixed in Bookworm)
- CVE-2025-26601: xorg-server / Xwayland (Bookworm fixed)
- CVE-2025-32463: sudo (Bookworm not vulnerable)
- CVE-2025-4802: glibc LD_LIBRARY_PATH preload (still vulnerable in Bookworm, fixed upstream)

**Action Plan**:
1. **Create CVE Monitoring Module**:
   ```bash
   # src/setup/modules/cve_monitoring.sh
   # Automated CVE checking and mitigation
   ```

2. **Package Version Validation**:
   - Implement automated package version checking
   - Alert on vulnerable package versions
   - Integrate with compliance dashboard

3. **Patch Management Process**:
   - Automated security update scheduling
   - Critical patch priority handling
   - Rollback procedures for failed updates

### Issue #173: UNC2891 Research Spike - Advanced Threat Detection
**Status**: Open  
**Priority**: Medium  
**Category**: Threat Research and Detection

**Threat Analysis - UNC2891 Banking Malware**:
- **Target**: ATM switching servers
- **Payload**: CAKETAP rootkit for HSM response manipulation
- **Vector**: Network monitoring server as pivot point
- **Persistence**: Mail server backdoor with internet connectivity

**Security Enhancements**:
1. **Network Monitoring Hardening**:
   ```bash
   # Enhance src/setup/modules/network_protocols.sh
   # Implement network segmentation controls
   # Add network traffic monitoring capabilities
   ```

2. **Mail Server Security**:
   ```bash
   # Create src/setup/modules/mail_security.sh
   # Disable unnecessary mail services
   # Implement mail server hardening
   ```

3. **Behavioral Analysis Enhancement**:
   ```bash
   # Update src/setup/modules/behavioral_analysis.sh
   # Add UNC2891 attack pattern detection
   # Implement network pivot detection
   ```

### Issues #137-138: STIG Compliance Gaps
**Status**: Open  
**Priority**: High  
**Category**: Compliance Enhancement

**Gap Analysis and Resolution**:

#### 1. Privileged Access & Sudo Configuration
**Current Gap**: `sudoers` file not audited or hardened
**Resolution**:
```bash
# Enhance src/setup/modules/credential_protection.sh
# Add sudoers auditing and RBAC enforcement
audit_sudoers_config() {
    # STIG requirement: Restrict sudo access
    # Implement command logging and restrictions
}
```

#### 2. Service Hardening & Network Daemons
**Current Gap**: Unused services not explicitly disabled
**Resolution**:
```bash
# Update src/setup/modules/service_disable.sh
# Add comprehensive service auditing
disable_insecure_services() {
    # Disable Telnet, NFS, RPC services
    # Implement TCP Wrappers controls
}
```

#### 3. Time Synchronization Security
**Current Gap**: NTP lacks authentication
**Resolution**:
```bash
# Enhance src/setup/modules/ntp.sh
# Add NTP authentication and security
secure_ntp_config() {
    # Implement symmetric or PKI authentication
    # Add fallback mechanisms
}
```

#### 4. File Integrity Monitoring
**Current Gap**: AIDE rules need periodic review
**Resolution**:
```bash
# Update src/setup/modules/aide.sh
# Add SIEM integration capabilities
enhance_aide_monitoring() {
    # Implement remote log forwarding
    # Add alerting mechanisms
}
```

#### 5. Audit Log Management
**Current Gap**: Log retention and forwarding not configured
**Resolution**:
```bash
# Enhance src/setup/modules/auditd.sh
# Add secure log rotation and forwarding
configure_audit_retention() {
    # Set retention policies
    # Implement remote log forwarding
}
```

#### 6. Disk and Swap Encryption
**Current Gap**: No encrypted swap enforcement
**Resolution**:
```bash
# Create src/setup/modules/disk_encryption.sh
# Add swap encryption validation
check_swap_encryption() {
    # Validate encrypted swap
    # Recommend full-disk encryption
}
```

#### 7. Secure Bootloader Configuration
**Current Gap**: GRUB password protection not enforced
**Resolution**:
```bash
# Create src/setup/modules/bootloader_security.sh
# Implement GRUB hardening
secure_grub_config() {
    # Set GRUB passwords
    # Disable recovery mode editing
}
```

#### 8. AppArmor Profile Hardening
**Current Gap**: Profiles in complain mode, not enforced
**Resolution**:
```bash
# Enhance src/setup/modules/apparmor.sh
# Move profiles to enforce mode
enforce_apparmor_profiles() {
    # Custom profile creation
    # Enforcement mode activation
}
```

#### 9. Backup and Recovery Security
**Current Gap**: No hardened backup procedures
**Resolution**:
```bash
# Create src/setup/modules/backup_security.sh
# Implement secure backup procedures
configure_secure_backups() {
    # Offline backup validation
    # Recovery process hardening
}
```

#### 10. Automated Compliance Validation
**Current Gap**: No SCAP/OVAL scanning
**Resolution**:
```bash
# Create src/setup/modules/compliance_validation.sh
# Integrate OpenSCAP scanning
run_scap_validation() {
    # DISA STIG profile validation
    # Automated compliance reporting
}
```

## Compliance Framework Integration

### Lynis Integration
**Objective**: Integrate Lynis system auditing tool for comprehensive security assessment

**Implementation Plan**:
1. **Add Lynis Package**:
   ```bash
   # Update debian/control to include lynis dependency
   # Install in setup process
   ```

2. **Create Lynis Module**:
   ```bash
   # src/setup/modules/lynis_audit.sh
   lynis_system_audit() {
       lynis audit system --quick --quiet
       # Parse results for compliance dashboard
   }
   ```

3. **Dashboard Integration**:
   - Add Lynis score to compliance metrics
   - Include Lynis recommendations in dashboard
   - Generate Lynis reports in HTML format

### CIS Controls Implementation
**Objective**: Full implementation of CIS Controls framework

**Priority Controls**:
1. **Inventory and Control of Hardware Assets**
2. **Inventory and Control of Software Assets**
3. **Continuous Vulnerability Management**
4. **Controlled Use of Administrative Privileges**
5. **Secure Configuration for Hardware and Software**

**Implementation**:
```bash
# Create src/setup/modules/cis_controls.sh
implement_cis_controls() {
    # Asset inventory automation
    # Vulnerability scanning integration
    # Administrative privilege controls
}
```

### DISA STIG Enhancement
**Objective**: Complete DISA STIG compliance coverage

**Key Areas**:
1. **Access Control** (STIG-ID: AC-*)
2. **Audit and Accountability** (STIG-ID: AU-*)
3. **Configuration Management** (STIG-ID: CM-*)
4. **Identification and Authentication** (STIG-ID: IA-*)
5. **System and Information Integrity** (STIG-ID: SI-*)

**Validation Process**:
```bash
# Use OpenSCAP for STIG validation
oscap xccdf eval --profile xccdf_mil.disa.stig_profile_MAC-1_Public \
    /usr/share/xml/scap/ssg/content/ssg-debian10-ds.xml
```

## CI/CD Enhancement for Headless Deployment

### Container Testing Enhancement
**Current Implementation**: Docker-based multi-architecture testing
**Enhancements Needed**:

1. **Expand Test Matrix**:
   ```yaml
   # .github/workflows/ci.yml enhancement
   strategy:
     matrix:
       arch: [amd64, arm64]
       distro: [debian, ubuntu]
       deployment: [container, vm, desktop]
   ```

2. **Headless Validation**:
   ```bash
   # Add comprehensive headless testing
   test_headless_deployment() {
       # Test all modules in non-interactive mode
       # Validate dashboard generation
       # Check compliance metrics
   }
   ```

3. **VM Testing Integration**:
   ```bash
   # Add VM testing with QEMU
   test_vm_deployment() {
       # Full VM simulation
       # Boot process validation
       # Complete system hardening test
   }
   ```

### Desktop Environment Testing
**Objective**: Ensure compatibility with desktop deployments

**Implementation**:
1. **Desktop Package Testing**:
   - Test with GNOME, KDE, XFCE environments
   - Validate desktop security modules
   - Ensure GUI compatibility when available

2. **Display Manager Hardening**:
   ```bash
   # Create src/setup/modules/desktop_security.sh
   harden_desktop_environment() {
       # Display manager security
       # Desktop privilege controls
       # User session hardening
   }
   ```

## Monitoring and Maintenance Procedures

### Automated Security Updates
**Objective**: Implement automated security patch management

**Implementation**:
```bash
# Create scheduled security update process
configure_security_updates() {
    # Enable unattended-upgrades for security patches
    # Configure automatic reboot for kernel updates
    # Implement rollback procedures
}
```

### Compliance Monitoring
**Objective**: Continuous compliance validation

**Components**:
1. **Daily Compliance Checks**
2. **Weekly Security Scans**
3. **Monthly Compliance Reports**
4. **Quarterly Security Reviews**

### Performance Impact Assessment
**Objective**: Monitor hardening impact on system performance

**Metrics**:
- Boot time impact
- Memory usage changes
- Network performance effects
- Application responsiveness

## Testing and Validation Protocols

### Module Testing Standards
**Requirements**:
1. Each module must pass in headless mode
2. Timeout protection (300 seconds maximum)
3. Proper error handling and logging
4. Multi-architecture compatibility
5. Rollback capability where possible

### Compliance Testing
**Validation Methods**:
1. **OpenSCAP Scanning**: Automated STIG validation
2. **Lynis Auditing**: System security assessment
3. **Custom Compliance Checks**: HARDN-specific validations
4. **Performance Testing**: Impact assessment

### Security Testing
**Test Categories**:
1. **Penetration Testing**: Simulated attack scenarios
2. **Vulnerability Scanning**: Automated vulnerability detection
3. **Configuration Testing**: Security setting validation
4. **Incident Response Testing**: Security event simulation

## Documentation Maintenance

### Required Documentation Updates
1. **Module Documentation**: Each module requires compliance mapping
2. **Deployment Guides**: Container, VM, and desktop specific guides
3. **Troubleshooting Guides**: Common issue resolution
4. **Security Advisory Process**: CVE response procedures

### Change Management Process
1. **Security Impact Assessment**: For all changes
2. **Compliance Validation**: Before deployment
3. **Rollback Procedures**: For failed deployments
4. **Documentation Updates**: Synchronized with code changes

## Emergency Response Procedures

### Security Incident Response
1. **Immediate Containment**: Isolate affected systems
2. **Impact Assessment**: Determine scope and severity
3. **Remediation**: Apply patches or workarounds
4. **Validation**: Confirm issue resolution
5. **Documentation**: Update procedures and lessons learned

### Critical CVE Response
1. **CVE Assessment**: Impact on HARDN-XDR deployments
2. **Patch Development**: Emergency module updates
3. **Testing**: Rapid validation in CI environment
4. **Deployment**: Emergency release procedures
5. **Communication**: User notification and guidance

This playbook provides a comprehensive framework for maintaining and enhancing HARDN-XDR while addressing all current GitHub issues and security compliance requirements.