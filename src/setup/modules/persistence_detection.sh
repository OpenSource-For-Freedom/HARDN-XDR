#!/bin/bash

# Persistence Detection Module
# Part of HARDN-XDR Security Framework
# Purpose: Boot process integrity and sophisticated rootkit detection

source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

HARDN_STATUS "info" "Setting up Persistence Detection..."

CONFIG_DIR="/etc/hardn-xdr/persistence-detection"
LOG_FILE="/var/log/security/persistence-detection.log"

mkdir -p "$CONFIG_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Enhanced kernel module monitoring
if command -v auditctl >/dev/null 2>&1; then
    auditctl -w /sbin/insmod -p x -k kernel_modules
    auditctl -w /sbin/rmmod -p x -k kernel_modules
    auditctl -w /sbin/modprobe -p x -k kernel_modules
    auditctl -a always,exit -F arch=b64 -S init_module -S delete_module -k kernel_modules
    HARDN_STATUS "pass" "Added auditd rules for kernel module monitoring"
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
