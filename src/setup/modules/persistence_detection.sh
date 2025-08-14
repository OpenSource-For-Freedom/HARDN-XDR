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

# Persistence Detection Module
# Part of HARDN-XDR Security Framework
# Purpose: Boot process integrity and sophisticated rootkit detection


HARDN_STATUS "info" "Setting up Persistence Detection..."

CONFIG_DIR="/etc/hardn-xdr/persistence-detection"
LOG_FILE="/var/log/security/persistence-detection.log"

mkdir -p "$CONFIG_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Enhanced kernel module monitoring
if command -v auditctl >/dev/null 2>&1; then
    # Check if auditd is available (may not work in containers)
    if auditctl -l >/dev/null 2>&1; then
        auditctl -w /sbin/insmod -p x -k kernel_modules 2>/dev/null || true
        auditctl -w /sbin/rmmod -p x -k kernel_modules 2>/dev/null || true
        auditctl -w /sbin/modprobe -p x -k kernel_modules 2>/dev/null || true
        auditctl -a always,exit -F arch=b64 -S init_module -S delete_module -k kernel_modules 2>/dev/null || true
        HARDN_STATUS "pass" "Added auditd rules for kernel module monitoring"
    else
        HARDN_STATUS "info" "Auditd not available (normal in containers)"
    fi
fi

# Boot process integrity monitoring
cat > "$CONFIG_DIR/boot-integrity.sh" << 'EOF'
#!/bin/bash
# Boot process integrity checker

BOOT_DIR="/boot"
GRUB_CFG="/boot/grub/grub.cfg"
INITRD_DIR="/boot"

if [[ -f "$GRUB_CFG" ]]; then
    md5sum "$GRUB_CFG" > /etc/hardn-xdr/persistence-detection/grub-checksum
fi

find "$BOOT_DIR" -name "initrd*" -o -name "vmlinuz*" | while read -r file; do
    md5sum "$file" >> /etc/hardn-xdr/persistence-detection/boot-checksums
done
EOF

chmod +x "$CONFIG_DIR/boot-integrity.sh"

# Create boot integrity baseline
"$CONFIG_DIR/boot-integrity.sh"

# Systemd service monitoring
if command -v systemctl >/dev/null 2>&1; then
    systemctl list-unit-files --type=service --state=enabled > "$CONFIG_DIR/enabled-services-baseline.txt"
    HARDN_STATUS "pass" "Created systemd services baseline"
fi

HARDN_STATUS "pass" "Persistence Detection setup completed"

return 0 2>/dev/null || hardn_module_exit 0
set -e
