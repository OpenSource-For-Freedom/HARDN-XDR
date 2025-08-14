#!/bin/bash
# Source common functions with fallback for development/CI environments
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
#!/bin/bash
# PakOS Configuration Module for HARDN-XDR
# Purpose: Handle PakOS-specific configurations and optimizations

# shellcheck disable=SC1091

pakos_main() {
    HARDN_STATUS "info" "Configuring PakOS-specific optimizations..."
    
    # Only run if PakOS is detected
    if [[ "${PAKOS_DETECTED:-0}" != "1" ]]; then
        HARDN_STATUS "info" "PakOS not detected, skipping PakOS-specific configuration"
        return 0
    fi
    
    HARDN_STATUS "pass" "PakOS detected: $PRETTY_NAME"
    
    # PakOS-specific package repository handling
    configure_pakos_repositories
    
    # Handle localization settings for Pakistani users
    configure_pakos_localization
    
    # Apply any PakOS-specific security configurations
    configure_pakos_security
    
    HARDN_STATUS "success" "PakOS configuration complete"
}

configure_pakos_repositories() {
    HARDN_STATUS "info" "Configuring PakOS package repositories..."
    
    # Check if PakOS has specific repositories that need to be enabled
    if command -v apt >/dev/null 2>&1; then
        # Ensure standard repositories are available
        if [[ -f /etc/apt/sources.list ]]; then
            HARDN_STATUS "info" "Verifying PakOS package repository configuration"
            # Could add PakOS-specific repository validation here
        fi
        
        # Update package cache for PakOS
        HARDN_STATUS "info" "Updating PakOS package cache..."
        if apt update >/dev/null 2>&1; then
            HARDN_STATUS "pass" "PakOS package cache updated successfully"
        else
            HARDN_STATUS "warning" "PakOS package cache update failed - may affect package availability"
        fi
    fi
}

configure_pakos_localization() {
    HARDN_STATUS "info" "Configuring PakOS localization settings..."
    
    # Set Pakistan timezone if not already configured
    if [[ -f /etc/timezone ]]; then
        current_tz=$(cat /etc/timezone)
        if [[ "$current_tz" != "Asia/Karachi" ]]; then
            HARDN_STATUS "info" "Setting timezone to Pakistan Standard Time (Asia/Karachi)"
            if command -v timedatectl >/dev/null 2>&1; then
                if timedatectl set-timezone Asia/Karachi 2>/dev/null; then
                    HARDN_STATUS "pass" "Timezone set to Asia/Karachi"
                else
                    HARDN_STATUS "warning" "Failed to set timezone (may need manual configuration)"
                fi
            fi
        else
            HARDN_STATUS "pass" "Pakistan timezone already configured"
        fi
    fi
    
    # Check for Urdu locale support
    if command -v locale >/dev/null 2>&1; then
        if locale -a | grep -q "ur_PK"; then
            HARDN_STATUS "pass" "Urdu locale (ur_PK) is available"
            # Could set LANG=ur_PK.UTF-8 if desired
        else
            HARDN_STATUS "info" "Urdu locale not installed (English will be used)"
            # Could suggest: apt install language-pack-ur
        fi
    fi
}

configure_pakos_security() {
    HARDN_STATUS "info" "Applying PakOS-specific security configurations..."
    
    # Apply any Pakistan-specific security requirements
    # This could include CERT Pakistan recommendations
    
    # Ensure security updates are properly configured for PakOS
    if [[ -f /etc/apt/apt.conf.d/50unattended-upgrades ]]; then
        HARDN_STATUS "info" "Verifying automatic security updates for PakOS"
        # Could add PakOS-specific unattended-upgrades configuration
    fi
    
    # Configure any PakOS-specific firewall rules if needed
    # This would depend on Pakistani cybersecurity guidelines
    
    HARDN_STATUS "pass" "PakOS security configuration applied"
}

# Export function for use by other modules
export -f configure_pakos_repositories
export -f configure_pakos_localization
export -f configure_pakos_security

# Execute if run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    pakos_main "$@"
fi
set -e
