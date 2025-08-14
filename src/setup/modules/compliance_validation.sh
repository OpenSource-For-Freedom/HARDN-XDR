#!/usr/bin/env bash

# Compliance Validation Module
# Part of HARDN-XDR Security Framework
# Purpose: Enhanced OpenSCAP/OVAL scanning and DISA STIG profile validation
# STIG Requirements: Automated compliance validation, SCAP scanning, STIG profile mapping

# Source common functions with fallback for development/CI environments
source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
    log_message() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"; }
    check_root() { [[ $EUID -eq 0 ]]; }
    is_installed() { command -v "$1" >/dev/null 2>&1 || dpkg -s "$1" >/dev/null 2>&1; }
    hardn_yesno() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && return 0
        echo "Auto-confirming: $1" >&2
        return 0
    }
    hardn_msgbox() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && echo "Info: $1" >&2 && return 0
        echo "Info: $1" >&2
    }
    is_container_environment() {
        [[ -n "$CI" ]] || [[ -n "$GITHUB_ACTIONS" ]] || [[ -f /.dockerenv ]] || \
        [[ -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null
    }
    is_systemd_available() {
        [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1
    }
    create_scheduled_task() {
        echo "Info: Scheduled task creation skipped in CI environment" >&2
        return 0
    }
    check_container_limitations() {
        if [[ ! -w /proc/sys ]] || [[ -f /.dockerenv ]]; then
            echo "Warning: Container limitations detected:" >&2
            echo "  - read-only /proc/sys - kernel parameter changes limited" >&2
        fi
        return 0
    }
    hardn_module_exit() {
        local exit_code="${1:-0}"
        exit "$exit_code"
    }
    safe_package_install() {
        local package="$1"
        if [[ "$CI" == "true" ]] || ! check_root; then
            echo "Info: Package installation skipped in CI environment: $package" >&2
            return 0
        fi
        echo "Warning: Package installation not implemented in fallback: $package" >&2
        return 1
    }
}

MODULE_NAME="Compliance Validation"
CONFIG_DIR="/etc/hardn-xdr/compliance-validation"
LOG_FILE="/var/log/security/compliance-validation.log"
REPORT_DIR="/var/log/security/compliance-reports"

compliance_validation_main() {
    HARDN_STATUS "info" "Starting $MODULE_NAME setup..."

    if ! check_root; then
        HARDN_STATUS "error" "This module requires root privileges"
        return 1
    fi

    mkdir -p "$CONFIG_DIR"
    mkdir -p "$REPORT_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"

    # Install and configure OpenSCAP
    install_openscap_tools

    # Download SCAP security content
    download_scap_content

    # Create DISA STIG profile mapping
    create_stig_profile_mapping

    # Set up automated scanning
    setup_automated_scanning

    # Create compliance reporting
    setup_compliance_reporting

    HARDN_STATUS "pass" "$MODULE_NAME setup completed"
    exit 0
}

install_openscap_tools() {
    HARDN_STATUS "info" "Installing OpenSCAP tools and dependencies..."
    
    local packages=(
        "libopenscap8"
        "openscap-utils" 
        "scap-security-guide"
        "openscap-scanner"
        "ssg-debian"
        "ssg-debderived"
    )
    
    # Update package list
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq 2>/dev/null || true
        
        for package in "${packages[@]}"; do
            if ! dpkg -s "$package" >/dev/null 2>&1; then
                HARDN_STATUS "info" "Installing $package..."
                if apt-get install -y "$package" >/dev/null 2>&1; then
                    HARDN_STATUS "pass" "$package installed successfully"
                else
                    HARDN_STATUS "warning" "Failed to install $package (may not be available)"
                fi
            else
                HARDN_STATUS "info" "$package already installed"
            fi
        done
    else
        HARDN_STATUS "error" "apt-get not available - cannot install packages"
        return 1
    fi

    # Verify OpenSCAP installation
    if command -v oscap >/dev/null 2>&1; then
        local oscap_version
        oscap_version=$(oscap --version | head -1)
        HARDN_STATUS "pass" "OpenSCAP installed: $oscap_version"
        echo "$(date): OpenSCAP installed: $oscap_version" >> "$LOG_FILE"
    else
        HARDN_STATUS "error" "OpenSCAP installation failed"
        return 1
    fi
}

download_scap_content() {
    HARDN_STATUS "info" "Downloading and configuring SCAP security content..."
    
    local content_dir="$CONFIG_DIR/scap-content"
    mkdir -p "$content_dir"
    
    # Check for system-installed SCAP content
    local scap_locations=(
        "/usr/share/scap-security-guide"
        "/usr/share/xml/scap/ssg/content"
        "/usr/share/ssg"
    )
    
    local found_content=false
    for location in "${scap_locations[@]}"; do
        if [[ -d "$location" ]]; then
            HARDN_STATUS "info" "Found SCAP content at $location"
            
            # Link to our content directory
            if [[ ! -L "$content_dir/system-content" ]]; then
                ln -sf "$location" "$content_dir/system-content"
            fi
            
            # List available content
            find "$location" -name "*.xml" -type f > "$content_dir/available-content.txt" 2>/dev/null || true
            found_content=true
        fi
    done
    
    if [[ "$found_content" == false ]]; then
        HARDN_STATUS "warning" "No system SCAP content found - downloading from upstream"
        download_upstream_scap_content
    fi
    
    # Create content inventory
    create_scap_content_inventory
}

download_upstream_scap_content() {
    HARDN_STATUS "info" "Downloading SCAP Security Guide from upstream..."
    
    local content_dir="$CONFIG_DIR/scap-content"
    local upstream_dir="$content_dir/upstream"
    mkdir -p "$upstream_dir"
    
    # Download SCAP Security Guide
    local ssg_version="v0.1.69"  # Latest stable version
    local download_url="https://github.com/ComplianceAsCode/content/releases/download/$ssg_version/scap-security-guide-$ssg_version.zip"
    
    if command -v wget >/dev/null 2>&1; then
        HARDN_STATUS "info" "Downloading SCAP Security Guide..."
        if wget -q "$download_url" -O "$upstream_dir/ssg.zip" 2>/dev/null; then
            if command -v unzip >/dev/null 2>&1; then
                cd "$upstream_dir"
                if unzip -q ssg.zip 2>/dev/null; then
                    HARDN_STATUS "pass" "SCAP Security Guide downloaded and extracted"
                    rm -f ssg.zip
                else
                    HARDN_STATUS "warning" "Failed to extract SCAP Security Guide"
                fi
                cd - >/dev/null
            else
                HARDN_STATUS "warning" "unzip not available - cannot extract SCAP content"
            fi
        else
            HARDN_STATUS "warning" "Failed to download SCAP Security Guide"
        fi
    else
        HARDN_STATUS "warning" "wget not available - cannot download SCAP content"
    fi
}

create_scap_content_inventory() {
    HARDN_STATUS "info" "Creating SCAP content inventory..."
    
    local inventory_file="$CONFIG_DIR/scap-content-inventory.txt"
    local content_dir="$CONFIG_DIR/scap-content"
    
    cat > "$inventory_file" << 'EOF'
HARDN-XDR SCAP Content Inventory
===============================

Generated: $(date)

Available SCAP Content Files:
EOF
    
    # Find all SCAP content files
    if [[ -d "$content_dir" ]]; then
        find "$content_dir" -name "*.xml" -type f 2>/dev/null | while read -r file; do
            echo "" >> "$inventory_file"
            echo "File: $file" >> "$inventory_file"
            
            # Get basic info about the SCAP file
            if command -v oscap >/dev/null 2>&1; then
                echo "Profiles available in this file:" >> "$inventory_file"
                timeout 30 oscap info "$file" 2>/dev/null | grep -A 50 "Profiles:" | head -20 >> "$inventory_file" || true
                echo "" >> "$inventory_file"
            fi
        done
    fi
    
    HARDN_STATUS "info" "SCAP content inventory created at $inventory_file"
}

create_stig_profile_mapping() {
    HARDN_STATUS "info" "Creating DISA STIG profile mapping..."
    
    cat > "$CONFIG_DIR/stig-profile-mapping.txt" << 'EOF'
HARDN-XDR DISA STIG Profile Mapping
===================================

This document maps HARDN-XDR security modules to DISA STIG requirements
and provides guidance for compliance validation.

STIG CATEGORY: ACCESS CONTROL (AC)
==================================
AC-2: Account Management
- Module: credential_protection.sh
- Validation: Check user account policies, password complexity

AC-3: Access Enforcement  
- Module: apparmor.sh, selinux.sh
- Validation: Verify mandatory access controls are enforced

AC-6: Least Privilege
- Module: credential_protection.sh
- Validation: Check sudo configuration, privilege restrictions

AC-7: Unsuccessful Logon Attempts
- Module: fail2ban.sh
- Validation: Verify account lockout policies

STIG CATEGORY: AUDIT AND ACCOUNTABILITY (AU)
===========================================
AU-2: Audit Events
- Module: auditd.sh, audit_system.sh
- Validation: Verify comprehensive audit rules

AU-3: Content of Audit Records
- Module: auditd.sh
- Validation: Check audit record format and content

AU-4: Audit Storage Capacity
- Module: auditd.sh
- Validation: Verify audit log rotation and storage

AU-9: Protection of Audit Information
- Module: auditd.sh, file_perms.sh
- Validation: Check audit log permissions and integrity

STIG CATEGORY: CONFIGURATION MANAGEMENT (CM)
===========================================
CM-2: Baseline Configuration
- Module: All HARDN-XDR modules
- Validation: System baseline compliance check

CM-6: Configuration Settings
- Module: kernel_sec.sh, sshd.sh, network_protocols.sh
- Validation: Verify security configuration parameters

CM-7: Least Functionality
- Module: service_disable.sh, unnecesary_services.sh
- Validation: Check disabled services and unused components

STIG CATEGORY: IDENTIFICATION AND AUTHENTICATION (IA)
====================================================
IA-2: Identification and Authentication
- Module: credential_protection.sh, sshd.sh
- Validation: Multi-factor authentication where applicable

IA-4: Identifier Management
- Module: credential_protection.sh
- Validation: User identifier management

IA-5: Authenticator Management
- Module: credential_protection.sh, stig_pwquality.sh
- Validation: Password policy enforcement

STIG CATEGORY: SYSTEM AND COMMUNICATIONS PROTECTION (SC)
=======================================================
SC-4: Information in Shared Resources
- Module: shared_mem.sh, coredumps.sh
- Validation: Memory and storage protection

SC-7: Boundary Protection
- Module: ufw.sh, fail2ban.sh, network_protocols.sh
- Validation: Network boundary controls

SC-8: Transmission Confidentiality and Integrity
- Module: sshd.sh, network_protocols.sh
- Validation: Encrypted communications

SC-12: Cryptographic Key Establishment and Management
- Module: disk_encryption.sh, bootloader_security.sh
- Validation: Encryption key management

SC-13: Cryptographic Protection
- Module: disk_encryption.sh, kernel_sec.sh
- Validation: FIPS-approved cryptographic modules

STIG CATEGORY: SYSTEM AND INFORMATION INTEGRITY (SI)
===================================================
SI-2: Flaw Remediation
- Module: auto_updates.sh
- Validation: Patch management and vulnerability remediation

SI-3: Malicious Code Protection
- Module: chkrootkit.sh, rkhunter.sh, yara.sh, suricata.sh
- Validation: Anti-malware protection and scanning

SI-4: Information System Monitoring
- Module: suricata.sh, behavioral_analysis.sh, central_logging.sh
- Validation: Security monitoring and alerting

SI-7: Software, Firmware, and Information Integrity
- Module: aide.sh, debsums.sh
- Validation: File integrity monitoring

SI-10: Information Input Validation
- Module: apparmor.sh, kernel_sec.sh
- Validation: Input validation and filtering

VALIDATION COMMANDS FOR EACH CATEGORY:
=====================================

Access Control Validation:
oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_stig \
  --results /tmp/ac-results.xml \
  --report /tmp/ac-report.html \
  /usr/share/scap-security-guide/ssg-debian10-ds.xml

Audit Validation:
oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_cis \
  --results /tmp/au-results.xml \
  --report /tmp/au-report.html \
  /usr/share/scap-security-guide/ssg-debian10-ds.xml

[Additional validation commands for each STIG category...]

AUTOMATED VALIDATION SCRIPT:
============================
Use the companion validate-stig-compliance.sh script for automated
validation of all STIG requirements against HARDN-XDR configurations.
EOF

    HARDN_STATUS "info" "STIG profile mapping created at $CONFIG_DIR/stig-profile-mapping.txt"
}

setup_automated_scanning() {
    HARDN_STATUS "info" "Setting up automated SCAP scanning..."
    
    # Create comprehensive scanning script
    cat > "$CONFIG_DIR/run-compliance-scan.sh" << 'EOF'
#!/bin/bash
# HARDN-XDR Comprehensive Compliance Scanner
# Automated SCAP/OVAL scanning with multiple profiles

set -euo pipefail

REPORT_DIR="/var/log/security/compliance-reports"
SCAP_CONTENT_DIR="/etc/hardn-xdr/compliance-validation/scap-content"
LOG_FILE="/var/log/security/compliance-validation.log"

# Create report directory with timestamp
SCAN_DATE=$(date +%Y%m%d_%H%M%S)
CURRENT_REPORT_DIR="$REPORT_DIR/$SCAN_DATE"
mkdir -p "$CURRENT_REPORT_DIR"

echo "$(date): Starting comprehensive compliance scan" >> "$LOG_FILE"

# Find available SCAP content
SCAP_FILES=()
if [[ -d "$SCAP_CONTENT_DIR" ]]; then
    while IFS= read -r -d '' file; do
        SCAP_FILES+=("$file")
    done < <(find "$SCAP_CONTENT_DIR" -name "*.xml" -type f -print0 2>/dev/null)
fi

if [[ ${#SCAP_FILES[@]} -eq 0 ]]; then
    echo "$(date): No SCAP content files found" >> "$LOG_FILE"
    
    # Try system locations
    SYSTEM_LOCATIONS=(
        "/usr/share/scap-security-guide"
        "/usr/share/xml/scap/ssg/content"
        "/usr/share/ssg"
    )
    
    for location in "${SYSTEM_LOCATIONS[@]}"; do
        if [[ -d "$location" ]]; then
            while IFS= read -r -d '' file; do
                SCAP_FILES+=("$file")
            done < <(find "$location" -name "*.xml" -type f -print0 2>/dev/null)
            break
        fi
    done
fi

# Run scans on available content
SCANS_COMPLETED=0
SCAN_ERRORS=0

for scap_file in "${SCAP_FILES[@]}"; do
    if [[ -f "$scap_file" ]]; then
        filename=$(basename "$scap_file" .xml)
        echo "$(date): Scanning with $filename" >> "$LOG_FILE"
        
        # Get available profiles
        profiles=()
        if timeout 30 oscap info "$scap_file" 2>/dev/null | grep -A 100 "Profiles:" | grep "^\s*\w" | head -10; then
            while IFS= read -r line; do
                if [[ $line =~ ^[[:space:]]*([^[:space:]]+) ]]; then
                    profiles+=("${BASH_REMATCH[1]}")
                fi
            done < <(timeout 30 oscap info "$scap_file" 2>/dev/null | grep -A 100 "Profiles:" | grep "^\s*\w" | head -10)
        fi
        
        # Run scan for each profile
        for profile in "${profiles[@]}"; do
            if [[ -n "$profile" ]]; then
                report_file="$CURRENT_REPORT_DIR/${filename}-${profile}-report.html"
                results_file="$CURRENT_REPORT_DIR/${filename}-${profile}-results.xml"
                
                echo "$(date): Running scan with profile $profile" >> "$LOG_FILE"
                
                if timeout 300 oscap xccdf eval \
                    --profile "$profile" \
                    --results "$results_file" \
                    --report "$report_file" \
                    "$scap_file" >/dev/null 2>&1; then
                    
                    echo "$(date): Scan completed successfully for $profile" >> "$LOG_FILE"
                    ((SCANS_COMPLETED++))
                else
                    echo "$(date): Scan failed for profile $profile" >> "$LOG_FILE"
                    ((SCAN_ERRORS++))
                fi
            fi
        done
    fi
done

# Generate summary report
cat > "$CURRENT_REPORT_DIR/scan-summary.txt" << SUMMARY
HARDN-XDR Compliance Scan Summary
================================
Scan Date: $(date)
Scans Completed: $SCANS_COMPLETED
Scan Errors: $SCAN_ERRORS

Report Location: $CURRENT_REPORT_DIR

Available Reports:
$(find "$CURRENT_REPORT_DIR" -name "*.html" -type f | sort)

Results Files:
$(find "$CURRENT_REPORT_DIR" -name "*.xml" -type f | sort)

To view reports, open the HTML files in a web browser.
For detailed analysis, examine the XML results files.
SUMMARY

echo "$(date): Compliance scan completed - $SCANS_COMPLETED scans, $SCAN_ERRORS errors" >> "$LOG_FILE"

# Create symlink to latest report
if [[ -L "$REPORT_DIR/latest" ]]; then
    rm "$REPORT_DIR/latest"
fi
ln -sf "$CURRENT_REPORT_DIR" "$REPORT_DIR/latest"

echo "Compliance scan completed. Reports available at: $CURRENT_REPORT_DIR"
echo "View latest reports at: $REPORT_DIR/latest"
EOF

    chmod +x "$CONFIG_DIR/run-compliance-scan.sh"
    chown root:root "$CONFIG_DIR/run-compliance-scan.sh"
    
    # Create quick validation script
    cat > "$CONFIG_DIR/quick-stig-check.sh" << 'EOF'
#!/bin/bash
# HARDN-XDR Quick STIG Compliance Check
# Fast validation of key STIG requirements

set -euo pipefail

echo "HARDN-XDR Quick STIG Compliance Check"
echo "====================================="
echo ""

# Check critical STIG requirements
echo "Checking critical STIG requirements..."

# AC-2: Account Management
echo -n "✓ Password policy (AC-2): "
if [[ -f "/etc/pam.d/common-password" ]] && grep -q "pam_pwquality" /etc/pam.d/common-password; then
    echo "COMPLIANT"
else
    echo "NON-COMPLIANT"
fi

# AU-2: Audit Events  
echo -n "✓ Audit system (AU-2): "
if systemctl is-active auditd >/dev/null 2>&1; then
    echo "COMPLIANT"
else
    echo "NON-COMPLIANT"
fi

# CM-7: Least Functionality
echo -n "✓ Firewall enabled (CM-7): "
if systemctl is-active ufw >/dev/null 2>&1; then
    echo "COMPLIANT"
else
    echo "NON-COMPLIANT"
fi

# SC-7: Boundary Protection
echo -n "✓ SSH hardening (SC-7): "
if [[ -f "/etc/ssh/sshd_config" ]] && grep -q "PermitRootLogin no" /etc/ssh/sshd_config; then
    echo "COMPLIANT"
else
    echo "NON-COMPLIANT"
fi

# SI-3: Malicious Code Protection
echo -n "✓ Anti-malware tools (SI-3): "
if command -v rkhunter >/dev/null 2>&1 || command -v chkrootkit >/dev/null 2>&1; then
    echo "COMPLIANT"
else
    echo "NON-COMPLIANT"
fi

# SI-7: Software Integrity
echo -n "✓ File integrity monitoring (SI-7): "
if command -v aide >/dev/null 2>&1 && [[ -f "/var/lib/aide/aide.db" ]]; then
    echo "COMPLIANT"
else
    echo "NON-COMPLIANT"
fi

echo ""
echo "For comprehensive compliance validation, run:"
echo "/etc/hardn-xdr/compliance-validation/run-compliance-scan.sh"
EOF

    chmod +x "$CONFIG_DIR/quick-stig-check.sh"
    chown root:root "$CONFIG_DIR/quick-stig-check.sh"
    
    HARDN_STATUS "info" "Automated scanning scripts created"
}

setup_compliance_reporting() {
    HARDN_STATUS "info" "Setting up compliance reporting system..."
    
    # Create compliance dashboard generator
    cat > "$CONFIG_DIR/generate-compliance-dashboard.sh" << 'EOF'
#!/bin/bash
# HARDN-XDR Compliance Dashboard Generator
# Creates HTML dashboard from scan results

set -euo pipefail

REPORT_DIR="/var/log/security/compliance-reports"
DASHBOARD_FILE="$REPORT_DIR/compliance-dashboard.html"

# Find latest scan results
LATEST_DIR="$REPORT_DIR/latest"
if [[ ! -d "$LATEST_DIR" ]]; then
    echo "Error: No scan results found. Run compliance scan first."
    exit 1
fi

# Generate HTML dashboard
cat > "$DASHBOARD_FILE" << 'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HARDN-XDR Compliance Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .header { background: #2c3e50; color: white; padding: 20px; text-align: center; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; }
        .compliant { color: #27ae60; }
        .non-compliant { color: #e74c3c; }
        .warning { color: #f39c12; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background: #f2f2f2; }
        .metric { display: inline-block; margin: 10px; padding: 15px; background: #ecf0f1; text-align: center; }
    </style>
</head>
<body>
    <div class="header">
        <h1>HARDN-XDR Compliance Dashboard</h1>
        <p>Generated: $(date)</p>
    </div>
    
    <div class="container">
        <div class="section">
            <h2>Compliance Overview</h2>
            <div class="metric">
                <h3>Total Scans</h3>
                <p>$(find "$LATEST_DIR" -name "*.html" | wc -l)</p>
            </div>
            <div class="metric">
                <h3>Last Scan</h3>
                <p>$(basename "$LATEST_DIR")</p>
            </div>
        </div>
        
        <div class="section">
            <h2>Available Reports</h2>
            <table>
                <tr><th>Report</th><th>Size</th><th>Generated</th></tr>
HTML

# Add report listings
find "$LATEST_DIR" -name "*.html" -type f | sort | while read -r report; do
    filename=$(basename "$report")
    size=$(ls -lh "$report" | awk '{print $5}')
    date=$(ls -l "$report" | awk '{print $6, $7, $8}')
    
    cat >> "$DASHBOARD_FILE" << HTML
                <tr>
                    <td><a href="$(realpath --relative-to="$REPORT_DIR" "$report")" target="_blank">$filename</a></td>
                    <td>$size</td>
                    <td>$date</td>
                </tr>
HTML
done

cat >> "$DASHBOARD_FILE" << 'HTML'
            </table>
        </div>
        
        <div class="section">
            <h2>Quick Actions</h2>
            <p><strong>Run New Scan:</strong> <code>/etc/hardn-xdr/compliance-validation/run-compliance-scan.sh</code></p>
            <p><strong>Quick STIG Check:</strong> <code>/etc/hardn-xdr/compliance-validation/quick-stig-check.sh</code></p>
            <p><strong>View STIG Mapping:</strong> <code>/etc/hardn-xdr/compliance-validation/stig-profile-mapping.txt</code></p>
        </div>
    </div>
</body>
</html>
HTML

echo "Compliance dashboard generated: $DASHBOARD_FILE"
echo "View in browser: file://$DASHBOARD_FILE"
EOF

    chmod +x "$CONFIG_DIR/generate-compliance-dashboard.sh"
    chown root:root "$CONFIG_DIR/generate-compliance-dashboard.sh"
    
    HARDN_STATUS "info" "Compliance reporting system configured"
    
    # Create schedule suggestions
    cat > "$CONFIG_DIR/scheduling-suggestions.txt" << 'EOF'
HARDN-XDR Compliance Validation Scheduling
==========================================

Recommended Schedule:
- Daily: Quick STIG checks
- Weekly: Full compliance scans  
- Monthly: Detailed compliance review and reporting

Cron Job Examples:

# Daily quick STIG check (6 AM)
0 6 * * * /etc/hardn-xdr/compliance-validation/quick-stig-check.sh >> /var/log/security/daily-stig-check.log 2>&1

# Weekly full compliance scan (Sunday 3 AM)
0 3 * * 0 /etc/hardn-xdr/compliance-validation/run-compliance-scan.sh

# Monthly dashboard generation (1st of month, 4 AM)
0 4 1 * * /etc/hardn-xdr/compliance-validation/generate-compliance-dashboard.sh

Installation:
echo "0 6 * * * /etc/hardn-xdr/compliance-validation/quick-stig-check.sh >> /var/log/security/daily-stig-check.log 2>&1" | crontab -
EOF

    HARDN_STATUS "info" "Scheduling suggestions created at $CONFIG_DIR/scheduling-suggestions.txt"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    compliance_validation_main "$@"
fi

return 0 2>/dev/null || exit 0
