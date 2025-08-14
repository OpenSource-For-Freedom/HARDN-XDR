#!/usr/bin/env bash

# Disk and Swap Encryption Module
# Part of HARDN-XDR Security Framework
# Purpose: STIG compliance for disk and swap encryption validation and recommendations
# STIG Requirements: Encrypted swap space, full-disk encryption recommendations

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

MODULE_NAME="Disk and Swap Encryption"
CONFIG_DIR="/etc/hardn-xdr/disk-encryption"
LOG_FILE="/var/log/security/disk-encryption.log"

disk_encryption_main() {
    HARDN_STATUS "info" "Starting $MODULE_NAME validation and configuration..."

    if ! check_root; then
        HARDN_STATUS "error" "This module requires root privileges"
        return 1
    fi

    mkdir -p "$CONFIG_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"

    # Check for encrypted swap
    check_swap_encryption

    # Check for full-disk encryption
    check_disk_encryption

    # Provide recommendations
    provide_encryption_recommendations

    HARDN_STATUS "pass" "$MODULE_NAME validation completed"
    exit 0
}

check_swap_encryption() {
    HARDN_STATUS "info" "Checking swap encryption status..."
    
    local swap_devices
    swap_devices=$(swapon --show=NAME --noheadings 2>/dev/null || true)
    
    if [[ -z "$swap_devices" ]]; then
        HARDN_STATUS "info" "No swap devices detected - this is acceptable for security"
        echo "$(date): No swap devices found" >> "$LOG_FILE"
        return 0
    fi

    local encrypted_swap=false
    local unencrypted_found=false

    while IFS= read -r swap_device; do
        if [[ -n "$swap_device" ]]; then
            HARDN_STATUS "info" "Checking swap device: $swap_device"
            
            # Check if swap device is encrypted (cryptsetup or dm-crypt)
            if cryptsetup status "$(basename "$swap_device")" >/dev/null 2>&1; then
                HARDN_STATUS "pass" "Swap device $swap_device is encrypted"
                encrypted_swap=true
                echo "$(date): Encrypted swap found: $swap_device" >> "$LOG_FILE"
            elif dmsetup info "$swap_device" 2>/dev/null | grep -q "crypt"; then
                HARDN_STATUS "pass" "Swap device $swap_device uses dm-crypt encryption"
                encrypted_swap=true
                echo "$(date): dm-crypt encrypted swap found: $swap_device" >> "$LOG_FILE"
            else
                HARDN_STATUS "warning" "Swap device $swap_device is NOT encrypted - STIG violation"
                unencrypted_found=true
                echo "$(date): UNENCRYPTED swap found: $swap_device" >> "$LOG_FILE"
            fi
        fi
    done <<< "$swap_devices"

    if [[ "$unencrypted_found" == true ]]; then
        HARDN_STATUS "warning" "STIG Compliance Gap: Unencrypted swap space detected"
        cat >> "$CONFIG_DIR/swap-encryption-recommendations.txt" << 'EOF'
STIG Requirement: Swap space must be encrypted to prevent memory dumps from exposing sensitive data.

To encrypt swap space:

1. Disable current swap:
   sudo swapoff -a

2. Set up encrypted swap using cryptsetup:
   sudo cryptsetup luksFormat /dev/sdXY  # Replace with your swap partition
   sudo cryptsetup luksOpen /dev/sdXY swap_crypt

3. Create swap on encrypted device:
   sudo mkswap /dev/mapper/swap_crypt
   sudo swapon /dev/mapper/swap_crypt

4. Update /etc/fstab:
   /dev/mapper/swap_crypt none swap sw 0 0

5. Update /etc/crypttab:
   swap_crypt /dev/sdXY /dev/urandom swap,cipher=aes-xts-plain64,size=256

For automated setup, consider using the Debian installer's encrypted LVM option.
EOF
        HARDN_STATUS "info" "Recommendations saved to $CONFIG_DIR/swap-encryption-recommendations.txt"
    fi
}

check_disk_encryption() {
    HARDN_STATUS "info" "Checking disk encryption status..."
    
    # Check for LUKS encrypted devices
    local luks_devices
    luks_devices=$(blkid -t TYPE=crypto_LUKS -o device 2>/dev/null || true)
    
    if [[ -n "$luks_devices" ]]; then
        HARDN_STATUS "pass" "LUKS encrypted devices detected:"
        while IFS= read -r device; do
            if [[ -n "$device" ]]; then
                HARDN_STATUS "info" "  - $device"
                echo "$(date): LUKS encrypted device: $device" >> "$LOG_FILE"
            fi
        done <<< "$luks_devices"
    else
        HARDN_STATUS "warning" "No LUKS encrypted devices detected"
        echo "$(date): No LUKS encryption found" >> "$LOG_FILE"
    fi

    # Check if root filesystem is encrypted
    local root_device
    root_device=$(findmnt -n -o SOURCE / 2>/dev/null || true)
    
    if [[ -n "$root_device" ]]; then
        if cryptsetup status "$(basename "$root_device")" >/dev/null 2>&1; then
            HARDN_STATUS "pass" "Root filesystem appears to be encrypted"
            echo "$(date): Root filesystem encrypted: $root_device" >> "$LOG_FILE"
        elif echo "$root_device" | grep -q "/dev/mapper/"; then
            HARDN_STATUS "info" "Root filesystem uses device mapper (possibly encrypted)"
            echo "$(date): Root filesystem on device mapper: $root_device" >> "$LOG_FILE"
        else
            HARDN_STATUS "warning" "Root filesystem does not appear to be encrypted"
            echo "$(date): Root filesystem NOT encrypted: $root_device" >> "$LOG_FILE"
        fi
    fi
}

provide_encryption_recommendations() {
    HARDN_STATUS "info" "Generating full-disk encryption recommendations..."
    
    cat > "$CONFIG_DIR/full-disk-encryption-guide.txt" << 'EOF'
HARDN-XDR Full-Disk Encryption Recommendations
===============================================

STIG Requirements:
- All sensitive data must be encrypted at rest
- Swap space must be encrypted to prevent memory dumps
- Encryption keys must be properly managed

Recommended Encryption Setup:

1. During Installation:
   - Use the Debian installer's "Guided - use entire disk and set up encrypted LVM" option
   - Choose strong passphrase (minimum 20 characters with mixed case, numbers, symbols)
   - Enable encrypted swap

2. For Existing Systems:
   WARNING: Full-disk encryption on existing systems requires complete reinstallation
   or complex migration procedures. Back up all data before proceeding.

3. Key Management Best Practices:
   - Use strong passphrases
   - Consider hardware security modules (HSM) for enterprise environments
   - Implement key escrow procedures for recovery
   - Regular passphrase rotation

4. Verification Commands:
   - Check LUKS devices: lsblk -f | grep crypto_LUKS
   - Check encrypted swap: swapon --show
   - Verify encryption status: cryptsetup status <device>

5. Performance Considerations:
   - AES-NI hardware acceleration recommended
   - XTS mode preferred for disk encryption
   - Consider SSD trim support with encryption

For assistance with encryption setup, consult your security team or 
refer to the Debian Security Handbook.
EOF

    HARDN_STATUS "info" "Full-disk encryption guide saved to $CONFIG_DIR/full-disk-encryption-guide.txt"
    
    # Create a simple encryption status report
    cat > "$CONFIG_DIR/encryption-status-report.txt" << EOF
HARDN-XDR Encryption Status Report
Generated: $(date)
================================

$(if blkid -t TYPE=crypto_LUKS >/dev/null 2>&1; then
    echo "✓ LUKS encryption detected"
    blkid -t TYPE=crypto_LUKS -o device 2>/dev/null | while read dev; do
        echo "  - $dev"
    done
else
    echo "✗ No LUKS encryption detected"
fi)

$(if swapon --show >/dev/null 2>&1; then
    if swapon --show | tail -n +2 | while read line; do
        swap_dev=$(echo "$line" | awk '{print $1}')
        if cryptsetup status "$(basename "$swap_dev")" >/dev/null 2>&1; then
            echo "✓ Encrypted swap: $swap_dev"
        else
            echo "✗ Unencrypted swap: $swap_dev"
        fi
    done | grep -q "✗"
    then
        echo "⚠ Some swap devices are unencrypted"
    else
        echo "✓ All swap devices encrypted"
    fi
else
    echo "ℹ No swap devices configured"
fi)

Recommendations:
$(if ! blkid -t TYPE=crypto_LUKS >/dev/null 2>&1; then
    echo "- Consider implementing full-disk encryption for sensitive systems"
fi)
$(if swapon --show >/dev/null 2>&1 && ! (swapon --show | tail -n +2 | while read line; do swap_dev=$(echo "$line" | awk '{print $1}'); cryptsetup status "$(basename "$swap_dev")" >/dev/null 2>&1 && exit 0; done; exit 1); then
    echo "- Implement encrypted swap to meet STIG requirements"
fi)
- Regular review of encryption status
- Key management and rotation procedures
- Hardware security module consideration for high-security environments

EOF

    HARDN_STATUS "info" "Encryption status report saved to $CONFIG_DIR/encryption-status-report.txt"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    disk_encryption_main "$@"
fi

return 0 2>/dev/null || exit 0
set -e
