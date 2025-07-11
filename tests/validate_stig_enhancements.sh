#!/bin/bash
# Manual validation script to test STIG compliance enhancements
# This script can be run on a test system to verify the functionality

set -e

echo "=== HARDN-XDR STIG Compliance Manual Validation ==="
echo "This script will test the enhanced STIG compliance modules"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Function to validate sudo hardening
validate_sudo_hardening() {
    echo "=== Testing Sudo Hardening ==="
    
    log_info "Running sudo hardening module..."
    if bash src/setup/modules/sudo_hardening.sh; then
        log_success "Sudo hardening module executed successfully"
    else
        log_error "Sudo hardening module failed"
        return 1
    fi
    
    # Check if configuration was created
    if [[ -f /etc/sudoers.d/90-hardn-stig ]]; then
        log_success "STIG sudoers configuration created"
    else
        log_warning "STIG sudoers configuration not found"
    fi
    
    # Check if audit script was created
    if [[ -f /usr/local/bin/audit-sudo.sh ]]; then
        log_success "Sudo audit script created"
        log_info "Running sudo audit..."
        /usr/local/bin/audit-sudo.sh
    else
        log_warning "Sudo audit script not found"
    fi
    
    echo
}

# Function to validate SSH hardening
validate_ssh_hardening() {
    echo "=== Testing SSH Hardening ==="
    
    log_info "Running SSH hardening module..."
    if bash src/setup/modules/sshd.sh; then
        log_success "SSH hardening module executed successfully"
    else
        log_error "SSH hardening module failed"
        return 1
    fi
    
    # Check FIPS ciphers
    if [[ -f /etc/ssh/sshd_config ]] && grep -q "aes256-ctr,aes192-ctr,aes128-ctr" /etc/ssh/sshd_config; then
        log_success "FIPS-approved ciphers configured"
    else
        log_warning "FIPS ciphers not properly configured"
    fi
    
    # Check SSH banner
    if [[ -f /etc/ssh/ssh_banner ]]; then
        log_success "SSH banner configured"
    else
        log_warning "SSH banner not found"
    fi
    
    echo
}

# Function to validate NTP hardening
validate_ntp_hardening() {
    echo "=== Testing NTP Hardening ==="
    
    log_info "Running NTP hardening module..."
    if bash src/setup/modules/ntp.sh; then
        log_success "NTP hardening module executed successfully"
    else
        log_error "NTP hardening module failed"
        return 1
    fi
    
    # Check authentication keys
    if [[ -f /etc/ntp.keys ]]; then
        log_success "NTP authentication keys created"
    else
        log_warning "NTP authentication keys not found"
    fi
    
    # Check monitoring script
    if [[ -f /usr/local/bin/ntp-monitor.sh ]]; then
        log_success "NTP monitoring script created"
    else
        log_warning "NTP monitoring script not found"
    fi
    
    echo
}

# Function to validate AIDE enhancements
validate_aide_enhancements() {
    echo "=== Testing AIDE Enhancements ==="
    
    log_info "Running AIDE enhancement module..."
    if bash src/setup/modules/aide.sh; then
        log_success "AIDE enhancement module executed successfully"
    else
        log_error "AIDE enhancement module failed"
        return 1
    fi
    
    # Check alerting script
    if [[ -f /usr/local/bin/aide-check-with-alerts.sh ]]; then
        log_success "AIDE alerting script created"
    else
        log_warning "AIDE alerting script not found"
    fi
    
    # Check status script
    if [[ -f /usr/local/bin/aide-status.sh ]]; then
        log_success "AIDE status script created"
        log_info "Running AIDE status check..."
        /usr/local/bin/aide-status.sh
    else
        log_warning "AIDE status script not found"
    fi
    
    echo
}

# Function to validate logging enhancements
validate_logging_enhancements() {
    echo "=== Testing Logging Enhancements ==="
    
    log_info "Running central logging enhancement module..."
    if bash src/setup/modules/central_logging.sh; then
        log_success "Central logging enhancement module executed successfully"
    else
        log_error "Central logging enhancement module failed"
        return 1
    fi
    
    # Check logrotate configuration
    if [[ -f /etc/logrotate.d/hardn-xdr ]] && grep -q "rotate 365" /etc/logrotate.d/hardn-xdr; then
        log_success "1-year log retention configured"
    else
        log_warning "Long-term log retention not properly configured"
    fi
    
    # Check remote forwarding script
    if [[ -f /usr/local/bin/configure-remote-logging.sh ]]; then
        log_success "Remote logging configuration script created"
    else
        log_warning "Remote logging configuration script not found"
    fi
    
    echo
}

# Function to validate service hardening
validate_service_hardening() {
    echo "=== Testing Service Hardening ==="
    
    log_info "Running unnecessary services removal module..."
    if bash src/setup/modules/unnecesary_services.sh; then
        log_success "Service hardening module executed successfully"
    else
        log_error "Service hardening module failed"
        return 1
    fi
    
    # Check if insecure services are disabled
    insecure_services=("telnet" "rpcbind" "nfs-server")
    for service in "${insecure_services[@]}"; do
        if systemctl is-enabled "$service" 2>/dev/null | grep -q "enabled"; then
            log_warning "Service $service is still enabled"
        else
            log_success "Service $service is properly disabled"
        fi
    done
    
    echo
}

# Main validation function
main() {
    echo "Starting manual validation of STIG compliance enhancements..."
    echo "Note: This test requires root privileges and may make changes to the system"
    echo
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root for proper testing"
        exit 1
    fi
    
    # Change to script directory
    cd "$(dirname "$0")/.."
    
    validate_sudo_hardening
    validate_ssh_hardening  
    validate_ntp_hardening
    validate_aide_enhancements
    validate_logging_enhancements
    validate_service_hardening
    
    echo "=== Validation Complete ==="
    log_success "All STIG compliance enhancement modules have been tested"
    log_info "Review the output above for any warnings or issues"
    log_info "Additional manual verification may be required for full STIG compliance"
}

# Only run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi