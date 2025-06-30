# In-Depth Technical Analysis of hardn-main.sh

## Overview

The `hardn-main.sh` script is a comprehensive system hardening tool designed for Debian-based Linux distributions. It implements a wide range of security measures following industry best practices and STIG (Security Technical Implementation Guide) compliance standards. The script systematically hardens various aspects of the system to create a "golden image" with enhanced security posture.

## Table of Contents
- [Script Structure and Architecture](#script-structure-and-architecture)
- [Key Security Components](#key-security-components)
  - [1. System Package Management](#1-system-package-management)
  - [2. Kernel Security Hardening](#2-kernel-security-hardening)
  - [3. Network Security](#3-network-security)
  - [4. Intrusion Detection and Prevention](#4-intrusion-detection-and-prevention)
  - [5. Audit Framework Configuration](#5-audit-framework-configuration)
  - [6. System Integrity Monitoring](#6-system-integrity-monitoring)
  - [7. Rootkit Detection](#7-rootkit-detection)
  - [8. Attack Surface Reduction](#8-attack-surface-reduction)
  - [9. Centralized Logging](#9-centralized-logging)
  - [10. Penetration Testing](#10-penetration-testing)
- [Technical Implementation Details](#technical-implementation-details)
- [DNS Configuration Analysis](#dns-configuration-analysis)
- [Conclusion](#conclusion)

## Script Structure and Architecture

The script follows a modular design with distinct functions for different security domains:

1. **Main Function**: Orchestrates the execution flow by calling specialized functions in sequence
2. **Utility Functions**: Provides status reporting and user interaction capabilities
3. **Security Domain Functions**: Implements specific hardening measures for different system components

## Key Security Components

### 1. System Package Management

```bash
update_system_packages()
install_package_dependencies("../../progs.csv")
```

The script begins by updating the system and installing security-focused packages defined in `progs.csv`. This CSV file contains a comprehensive list of security tools including:

- Intrusion detection (Suricata)
- Malware detection (ClamAV, YARA)
- System integrity monitoring (AIDE, debsums)
- Rootkit detection (rkhunter, chkrootkit)
- Auditing tools (auditd)

### 2. Kernel Security Hardening

```bash
apply_kernel_security()
```

This function implements kernel-level security by configuring sysctl parameters in several categories:

- **Memory Protection**: Enables protected FIFOs, hardlinks, and symlinks
- **Information Leak Prevention**: Restricts kernel pointer exposure and dmesg access
- **Network Hardening**: Disables IP forwarding, ICMP redirects, and source routing
- **BPF Hardening**: Restricts Berkeley Packet Filter capabilities

### 3. Network Security

```bash
enable_nameservers()
```

The script configures DNS to use secure providers (Quad9 and Cloudflare) and handles different system configurations:

- Detects and configures systemd-resolved if present
- Falls back to direct `/etc/resolv.conf` modification if necessary
- Ensures persistent configuration across reboots

### 4. Intrusion Detection and Prevention

The script configures multiple layers of intrusion detection:

```bash
# Suricata configuration
if dpkg -s suricata >/dev/null 2>&1; then
    # Configuration logic...
else
    # Installation from source logic...
fi
```

Suricata is configured as a network-based intrusion detection system with automatic rule updates. If the package isn't available, the script attempts to compile it from source.

### 5. Audit Framework Configuration

```bash
# auditd configuration
if dpkg -s auditd >/dev/null 2>&1; then
    # Configuration logic...
fi
```

The script implements a comprehensive audit framework using auditd with optimized rules that:

- Monitor system calls related to authentication and authorization
- Track changes to critical system files
- Log privilege escalation attempts
- Monitor module loading/unloading
- Track network configuration changes

### 6. System Integrity Monitoring

Multiple tools are configured to ensure system integrity:

```bash
# AIDE configuration
if ! dpkg -s aide >/dev/null 2>&1; then
    # Installation and configuration logic...
fi
```

AIDE (Advanced Intrusion Detection Environment) is configured to create and maintain a database of file checksums for integrity verification.

```bash
# debsums configuration
if command -v debsums >/dev/null 2>&1; then
    # Configuration logic...
fi
```

Debsums is set up to verify installed package files against known good checksums.

### 7. Rootkit Detection

```bash
# rkhunter configuration
if ! dpkg -s rkhunter >/dev/null 2>&1; then
    # Installation and configuration logic...
fi

# chkrootkit configuration
if ! command -v chkrootkit >/dev/null 2>&1; then
    # Installation and configuration logic...
fi
```

Both rkhunter and chkrootkit are configured to run daily checks for rootkits and suspicious system modifications.

### 8. Attack Surface Reduction

Several functions reduce the attack surface:

```bash
disable_firewire_drivers()
disable_binfmt_misc()
restrict_compilers()
remove_unnecessary_services()
```

These functions:
- Disable unnecessary hardware interfaces (FireWire)
- Restrict non-native binary format support
- Limit compiler access to root only
- Remove or disable unnecessary network services

### 9. Centralized Logging

```bash
setup_central_logging()
```

This function creates a unified logging framework that:
- Configures rsyslog to collect security-related logs
- Sets up log rotation with appropriate retention policies
- Ensures proper permissions on log files
- Creates a central log file at `/usr/local/var/log/suricata/hardn-xdr.log`

### 10. Penetration Testing

```bash
pen_test()
```

The script includes a self-assessment component that:
- Runs Lynis in pentest mode to evaluate system security
- Performs an nmap scan to identify open ports and services
- Logs results for later review

## Technical Implementation Details

### Error Handling and Status Reporting

The script uses a custom `HARDN_STATUS` function to provide consistent status reporting:

```bash
HARDN_STATUS "info" "Message"  # Informational message
HARDN_STATUS "pass" "Message"  # Success message
HARDN_STATUS "error" "Message" # Error message
HARDN_STATUS "warning" "Message" # Warning message
```

### User Interface

The script uses `whiptail` for user interaction, providing a semi-graphical interface in the terminal:

```bash
whiptail --infobox "Message" 7 70
```

### Fallback Mechanisms

The script implements fallback mechanisms when primary installation methods fail:

```bash
# Example from rkhunter installation
if apt-get install -y rkhunter >/dev/null 2>&1; then
    HARDN_STATUS "pass" "rkhunter installed successfully via apt."
else
    HARDN_STATUS "warning" "Warning: Failed to install rkhunter via apt. Attempting to download and install from GitHub as a fallback..."
    # Fallback installation logic...
fi
```

### Configuration Backup

Before modifying critical configuration files, the script creates backups:

```bash
# Example from auditd configuration
if [ -f "$audit_rules_file" ]; then
    cp "$audit_rules_file" "${audit_rules_file}.bak.$(date +%F-%T)" 2>/dev/null || true
    HARDN_STATUS "pass" "Backed up existing audit rules to $audit_rules_file.bak."
fi
```

## DNS Configuration Analysis

The `enable_nameservers()` function (where your cursor was positioned) demonstrates sophisticated handling of DNS configuration:

```bash
enable_nameservers() {
    # Function implementation...
    local resolved_conf_systemd temp_resolved_conf
    resolved_conf_systemd="/etc/systemd/resolved.conf"
    temp_resolved_conf=$(mktemp)

    if [[ ! -f "$resolved_conf_systemd" ]]; then
        HARDN_STATUS "info" "Creating $resolved_conf_systemd as it does not exist."
        # ...
    }
```

This function:
1. Detects if systemd-resolved is managing DNS
2. Creates a temporary file for safe editing
3. Modifies DNS settings to use secure providers (Quad9 and Cloudflare)
4. Handles both systemd-resolved and traditional DNS configuration
5. Ensures changes persist across reboots

## Conclusion

The `hardn-main.sh` alongside the `/modules` scripts are comprehensive security hardening tools that implements defense-in-depth through multiple security layers. It follows security best practices by:

1. Implementing principle of least privilege
2. Reducing attack surface
3. Providing defense in depth with multiple security tools
4. Ensuring comprehensive logging and monitoring
5. Following STIG compliance guidelines
6. Including self-assessment capabilities

The script is well-structured, with modular functions that handle specific security domains, making it maintainable and extensible. It includes robust error handling, fallback mechanisms, and user feedback to ensure successful deployment across different system configurations.
