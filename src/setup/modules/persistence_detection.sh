#!/bin/bash

# Persistence Detection Module
# Part of HARDN-XDR Security Framework
# Purpose: Boot process integrity and sophisticated rootkit detection

set -euo pipefail

source "/usr/share/hardn-xdr/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    log_message() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"; }
    check_root() { [[ $EUID -eq 0 ]]; }
}

MODULE_NAME="Persistence Detection"
CONFIG_DIR="/etc/hardn-xdr/persistence-detection"
LOG_FILE="/var/log/security/persistence-detection.log"

persistence_detection_setup() {
    log_message "INFO: Setting up $MODULE_NAME"
    
    if ! check_root; then
        log_message "ERROR: This module requires root privileges"
        return 1
    fi
    
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Enhanced kernel module monitoring
    if command -v auditctl >/dev/null 2>&1; then
        auditctl -w /sbin/insmod -p x -k kernel_modules
        auditctl -w /sbin/rmmod -p x -k kernel_modules
        auditctl -w /sbin/modprobe -p x -k kernel_modules
        auditctl -a always,exit -F arch=b64 -S init_module -S delete_module -k kernel_modules
        log_message "INFO: Added auditd rules for kernel module monitoring"
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
        log_message "INFO: Created systemd services baseline"
    fi
    
    log_message "INFO: $MODULE_NAME setup completed"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    persistence_detection_setup
fi