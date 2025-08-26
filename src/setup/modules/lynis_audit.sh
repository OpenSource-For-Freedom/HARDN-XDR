#!/bin/bash

# Compliance: STIG-V-25000, CIS-001.1, DISA-STIG-LYAUD-01
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

LYNIS_VERSION="3.0.9"
LYNIS_CONFIG_DIR="/etc/hardn-xdr/lynis"
LYNIS_REPORTS_DIR="/var/log/hardn-xdr/lynis"
LYNIS_PROFILE="hardn-xdr-hardening"

# STIG compliance requirements for Lynis
REQUIRED_LYNIS_TESTS=(
    "AUTH-9234"  # Password aging settings
    "AUTH-9262"  # Password complexity requirements  
    "FIRE-4511"  # Firewall configuration
    "FILE-6310"  # File permissions validation
    "KRNL-6000"  # Kernel hardening parameters
    "NETW-3001"  # Network configuration
    "ACCT-9622"  # Audit configuration
    "SSH-7408"   # SSH configuration
    "BOOT-5122"  # Boot loader configuration
    "TIME-3104"  # Time synchronization
)

install_lynis() {
    HARDN_STATUS "info" "Installing Lynis security auditing tool..."
    
    if is_container_environment; then
        HARDN_STATUS "info" "Container environment detected - skipping Lynis installation"
        return 0
    fi
    
    # Check if Lynis is already installed
    if is_installed "lynis"; then
        local installed_version=$(lynis show version 2>/dev/null | grep -o '[0-9]*\.[0-9]*\.[0-9]*' | head -1)
        HARDN_STATUS "info" "Lynis already installed (version: ${installed_version:-unknown})"
        return 0
    fi
    
    # Install Lynis from Debian repository
    if ! safe_package_install "lynis"; then
        HARDN_STATUS "warning" "Could not install Lynis via package manager"
        
        # Alternative: Download and install manually
        if command -v wget >/dev/null 2>&1; then
            HARDN_STATUS "info" "Attempting manual Lynis installation..."
            local temp_dir="/tmp/lynis-install-$$"
            mkdir -p "$temp_dir"
            
            if wget -O "$temp_dir/lynis.tar.gz" "https://downloads.cisofy.com/lynis/lynis-${LYNIS_VERSION}.tar.gz" 2>/dev/null; then
                cd "$temp_dir" && tar -xzf lynis.tar.gz
                if [[ -d "lynis" ]]; then
                    cp -r lynis /opt/lynis
                    ln -sf /opt/lynis/lynis /usr/local/bin/lynis
                    HARDN_STATUS "pass" "Lynis installed manually"
                else
                    HARDN_STATUS "error" "Failed to extract Lynis"
                    return 1
                fi
            else
                HARDN_STATUS "error" "Failed to download Lynis"
                return 1
            fi
            
            rm -rf "$temp_dir"
        else
            HARDN_STATUS "error" "wget not available for manual Lynis installation"
            return 1
        fi
    fi
    
    HARDN_STATUS "pass" "Lynis installation completed"
    return 0
}

configure_lynis_profile() {
    HARDN_STATUS "info" "Configuring Lynis profile for HARDN-XDR..."
    
    # Create configuration directory
    mkdir -p "$LYNIS_CONFIG_DIR"
    mkdir -p "$LYNIS_REPORTS_DIR"
    
    # Create HARDN-XDR specific Lynis profile
    cat > "$LYNIS_CONFIG_DIR/hardn-xdr.prf" << 'EOF'
# HARDN-XDR Lynis Profile
# Purpose: STIG compliance validation and security auditing

# Skip tests that may conflict with HARDN-XDR hardening
skip-test=FILE-6310:file-permissions-test  # We handle this in file_perms.sh
skip-test=KRNL-6000:kernel-parameters      # We handle this in kernel_sec.sh

# Focus on STIG compliance tests
include-test=AUTH-9234  # Password aging
include-test=AUTH-9262  # Password complexity
include-test=FIRE-4511  # Firewall configuration
include-test=NETW-3001  # Network configuration
include-test=ACCT-9622  # Audit configuration
include-test=SSH-7408   # SSH configuration
include-test=BOOT-5122  # Boot loader configuration
include-test=TIME-3104  # Time synchronization

# Reporting configuration
report-file=/var/log/hardn-xdr/lynis/lynis-report.dat
log-file=/var/log/hardn-xdr/lynis/lynis.log

# Compliance standards
compliance-standards=stig,cis

# Advanced options
show-report-solution=yes
show-warnings-only=no
quick=no
quiet=no
EOF
    
    HARDN_STATUS "pass" "Lynis profile configured"
}

run_lynis_audit() {
    HARDN_STATUS "info" "Running Lynis security audit..."
    
    if is_container_environment; then
        HARDN_STATUS "info" "Container environment - running limited Lynis tests"
        
        # In container, focus on configuration tests only
        if command -v lynis >/dev/null 2>&1; then
            lynis audit system --profile "$LYNIS_CONFIG_DIR/hardn-xdr.prf" \
                --skip-plugins --no-colors --quiet \
                --report-file "$LYNIS_REPORTS_DIR/container-audit.dat" 2>/dev/null || {
                HARDN_STATUS "warning" "Lynis container audit completed with warnings"
            }
        else
            HARDN_STATUS "info" "Lynis not available in container - skipping audit"
        fi
        return 0
    fi
    
    if ! command -v lynis >/dev/null 2>&1; then
        HARDN_STATUS "error" "Lynis not available for audit"
        return 1
    fi
    
    # Run full Lynis audit
    local audit_report="$LYNIS_REPORTS_DIR/audit-$(date +%Y%m%d-%H%M%S).dat"
    
    if lynis audit system --profile "$LYNIS_CONFIG_DIR/hardn-xdr.prf" \
        --report-file "$audit_report" \
        --log-file "$LYNIS_REPORTS_DIR/audit.log" 2>/dev/null; then
        HARDN_STATUS "pass" "Lynis audit completed successfully"
    else
        HARDN_STATUS "warning" "Lynis audit completed with findings"
    fi
    
    # Generate STIG compliance summary
    generate_stig_compliance_summary "$audit_report"
}

generate_stig_compliance_summary() {
    local report_file="$1"
    local summary_file="$LYNIS_REPORTS_DIR/stig-compliance-summary.txt"
    
    if [[ ! -f "$report_file" ]]; then
        HARDN_STATUS "warning" "Lynis report file not found: $report_file"
        return 1
    fi
    
    HARDN_STATUS "info" "Generating STIG compliance summary..."
    
    cat > "$summary_file" << 'EOF'
# HARDN-XDR STIG Compliance Summary via Lynis
Generated: $(date)

## Required STIG Tests Status
EOF
    
    local compliant_tests=0
    local total_tests=${#REQUIRED_LYNIS_TESTS[@]}
    
    for test_id in "${REQUIRED_LYNIS_TESTS[@]}"; do
        if grep -q "test=$test_id" "$report_file" 2>/dev/null; then
            local status=$(grep "test=$test_id" "$report_file" | grep -o "result=[A-Z]*" | cut -d= -f2)
            case "$status" in
                "OK"|"FOUND"|"YES")
                    echo "✓ $test_id: COMPLIANT" >> "$summary_file"
                    ((compliant_tests++))
                    ;;
                "WARNING"|"SUGGESTION")
                    echo "⚠ $test_id: NEEDS ATTENTION" >> "$summary_file"
                    ;;
                *)
                    echo "✗ $test_id: NON-COMPLIANT" >> "$summary_file"
                    ;;
            esac
        else
            echo "? $test_id: NOT TESTED" >> "$summary_file"
        fi
    done
    
    local compliance_percentage=$((compliant_tests * 100 / total_tests))
    
    cat >> "$summary_file" << EOF

## Compliance Summary
Total Required Tests: $total_tests
Compliant Tests: $compliant_tests
Compliance Percentage: ${compliance_percentage}%

## Recommendations
EOF
    
    if [[ $compliance_percentage -ge 90 ]]; then
        echo "✓ Excellent STIG compliance achieved" >> "$summary_file"
    elif [[ $compliance_percentage -ge 75 ]]; then
        echo "⚠ Good STIG compliance - minor improvements needed" >> "$summary_file"
    else
        echo "✗ STIG compliance needs significant improvement" >> "$summary_file"
    fi
    
    HARDN_STATUS "info" "STIG compliance: ${compliance_percentage}% (${compliant_tests}/${total_tests})"
    HARDN_STATUS "pass" "Compliance summary generated: $summary_file"
}

setup_automated_lynis() {
    if is_container_environment; then
        HARDN_STATUS "info" "Skipping automated Lynis setup in container environment"
        return 0
    fi
    
    HARDN_STATUS "info" "Setting up automated Lynis auditing..."
    
    # Create audit script
    local audit_script="/usr/local/bin/hardn-lynis-audit"
    
    cat > "$audit_script" << 'EOF'
#!/bin/bash
# HARDN-XDR Automated Lynis Audit Script

LYNIS_CONFIG_DIR="/etc/hardn-xdr/lynis"
LYNIS_REPORTS_DIR="/var/log/hardn-xdr/lynis"

# Ensure directories exist
mkdir -p "$LYNIS_REPORTS_DIR"

# Run audit
if command -v lynis >/dev/null 2>&1; then
    lynis audit system --profile "$LYNIS_CONFIG_DIR/hardn-xdr.prf" \
        --report-file "$LYNIS_REPORTS_DIR/scheduled-audit-$(date +%Y%m%d).dat" \
        --log-file "$LYNIS_REPORTS_DIR/scheduled-audit.log" \
        --quiet
else
    echo "$(date): Lynis not available" >> "$LYNIS_REPORTS_DIR/audit-error.log"
fi
EOF
    
    chmod +x "$audit_script"
    
    # Create cron job for weekly audits
    if create_scheduled_task; then
        local cron_entry="0 2 * * 0 root $audit_script"
        if ! grep -q "hardn-lynis-audit" /etc/crontab 2>/dev/null; then
            echo "$cron_entry" >> /etc/crontab
            HARDN_STATUS "pass" "Weekly Lynis audit scheduled"
        fi
    fi
}

validate_module_compliance() {
    HARDN_STATUS "info" "Validating HARDN-XDR module STIG compliance..."
    
    local modules_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
    local validation_report="$LYNIS_REPORTS_DIR/module-compliance.txt"
    
    cat > "$validation_report" << 'EOF'
# HARDN-XDR Module STIG Compliance Validation
Generated: $(date)

## Module Compliance Status
EOF
    
    local stig_modules=(
        "auditd.sh:STIG-V-38464,STIG-V-38631"
        "sshd.sh:STIG-V-38607,STIG-V-38608"
        "credential_protection.sh:STIG-V-38475,STIG-V-38477"
        "kernel_sec.sh:STIG-V-38526,STIG-V-38539"
        "file_perms.sh:STIG-V-38340,STIG-V-38643"
        "ufw.sh:STIG-V-38513,STIG-V-38518"
    )
    
    for module_info in "${stig_modules[@]}"; do
        local module_name="${module_info%%:*}"
        local stig_ids="${module_info##*:}"
        
        if [[ -f "$modules_dir/$module_name" ]]; then
            echo "✓ $module_name: Available (STIG: $stig_ids)" >> "$validation_report"
        else
            echo "✗ $module_name: Missing (STIG: $stig_ids)" >> "$validation_report"
        fi
    done
    
    HARDN_STATUS "pass" "Module compliance validation completed"
}

# Main execution function
lynis_audit_main() {
    HARDN_STATUS "info" "Starting Lynis audit integration..."
    
    # Check root privileges
    if ! check_root; then
        HARDN_STATUS "error" "Root privileges required for Lynis audit"
        hardn_module_exit 1
    fi
    
    # Install Lynis if needed
    if ! install_lynis; then
        HARDN_STATUS "error" "Failed to install Lynis"
        hardn_module_exit 1
    fi
    
    # Configure Lynis profile
    configure_lynis_profile
    
    # Run security audit
    run_lynis_audit
    
    # Setup automated auditing
    setup_automated_lynis
    
    # Validate module compliance
    validate_module_compliance
    
    # Summary
    if [[ -f "$LYNIS_REPORTS_DIR/stig-compliance-summary.txt" ]]; then
        hardn_msgbox "Lynis STIG compliance summary available at: $LYNIS_REPORTS_DIR/stig-compliance-summary.txt"
    fi
    
    HARDN_STATUS "pass" "Lynis audit integration completed successfully"
    
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    lynis_audit_main "$@"
fi
