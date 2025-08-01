# Security Modules Reference

This document provides a comprehensive mapping of HARDN-XDR security modules, including both existing and UNC2891-enhanced modules, with their tags, extended names, and purposes.

## UNC2891-Enhanced Security Modules

### process_protection.sh
- **Tag**: PROC_PROTECT
- **Extended Name**: Advanced Process Protection Module
- **Purpose**: Detect and prevent process injection techniques (MITRE T1055)
- **Why**: UNC2891 uses sophisticated process injection methods to evade detection. Current HARDN-XDR lacks specific protection against these techniques.
- **Coverage**: Addresses critical gap in defense evasion tactics

### credential_protection.sh
- **Tag**: CRED_PROTECT
- **Extended Name**: Enhanced Credential Security Module
- **Purpose**: Advanced credential dumping protection and token manipulation prevention (MITRE T1003, T1134)
- **Why**: UNC2891 employs advanced credential harvesting techniques beyond basic file permissions. Enhanced protection is needed for memory-based credential access.
- **Coverage**: Extends existing file_perms.sh with runtime protection

### behavioral_analysis.sh
- **Tag**: BEHAV_ANALYSIS
- **Extended Name**: Behavioral Anomaly Detection Module
- **Purpose**: System behavior baselining and anomaly detection for masquerading detection (MITRE T1036)
- **Why**: UNC2891 uses sophisticated masquerading techniques that require behavioral analysis to detect. Static signatures are insufficient.
- **Coverage**: Provides proactive threat hunting capabilities

### persistence_detection.sh
- **Tag**: PERSIST_DETECT
- **Extended Name**: Advanced Persistence Detection Module
- **Purpose**: Boot process integrity monitoring and sophisticated rootkit detection (MITRE T1547.006)
- **Why**: UNC2891 may use advanced kernel-level persistence mechanisms. Current chkrootkit.sh and rkhunter.sh provide basic detection only.
- **Coverage**: Enhances existing kernel_sec.sh with runtime monitoring

## Existing HARDN-XDR Modules (Reference)

### Core Security Modules
- **aide.sh** - File integrity monitoring
- **auditd.sh** - System audit logging
- **fail2ban.sh** - Intrusion prevention
- **ufw.sh** - Uncomplicated firewall configuration
- **yara.sh** - Malware signature detection

### Access Control Modules
- **apparmor.sh** - Mandatory access control
- **selinux.sh** - Security-Enhanced Linux
- **sshd.sh** - SSH daemon hardening
- **file_perms.sh** - File permissions hardening

### System Hardening Modules
- **kernel_sec.sh** - Kernel security parameters
- **auto_updates.sh** - Automatic security updates
- **compilers.sh** - Compiler removal/restriction
- **usb.sh** - USB device restrictions

## Integration Strategy

### Enhanced Modules (Extend Existing)
- **suricata.sh** - Add UNC2891-specific network signatures
- **yara.sh** - Include UNC2891 malware signatures and behavioral patterns
- **auditd.sh** - Add UNC2891-specific audit rules for process injection and credential access
- **aide.sh** - Enhanced file integrity monitoring with UNC2891 IOCs

### Module Dependencies
- process_protection.sh → requires auditd.sh
- credential_protection.sh → enhances file_perms.sh
- behavioral_analysis.sh → integrates with auditd.sh, aide.sh
- persistence_detection.sh → enhances kernel_sec.sh, chkrootkit.sh, rkhunter.sh

## Implementation Notes

All modules follow the HARDN-XDR standard pattern:
- Source hardn-common.sh for logging and utilities
- Check root privileges
- Create configuration directories
- Log activities with HARDN_STATUS integration
- Support CI environment detection
- Provide standalone execution capability

The modular architecture allows seamless integration without disrupting existing functionality.