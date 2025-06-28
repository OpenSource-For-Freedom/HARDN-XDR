# Simple GRUB password protection for Debian systems
# This script is here as a possible alternative to grub.sh

HARDN_STATUS "info" "Basic Debian GRUB boot loader password..."

# Are you rot?
[ "$(id -u)" -ne 0 ] && echo "This script must be run as root" && exit 1

# Backup original 40_custom
if [ -f /etc/grub.d/40_custom ]; then
    cp /etc/grub.d/40_custom "/etc/grub.d/40_custom.bak.$(date +%Y%m%d-%H%M%S)"
    echo "Backup of original GRUB custom configuration created."
fi

echo "Generating password hash..."
PASSWORD="HelloPassword123!"
PASSWORD_HASH=$(echo -e "$PASSWORD\n$PASSWORD" | grub-mkpasswd-pbkdf2 | grep "PBKDF2 hash of your password" | sed 's/PBKDF2 hash of your password is //')

if [ -z "$PASSWORD_HASH" ]; then
    echo "Failed to generate password hash."
    exit 1
fi

# Create simple 40_custom file
cat > /etc/grub.d/40_custom << EOF
#!/bin/sh
exec tail -n +3 \$0
# This file provides an easy way to add custom menu entries.
# Simply type the menu entries you want to add after this comment.
# Be careful not to change the 'exec tail' line above.

set superusers="root"
password_pbkdf2 root $PASSWORD_HASH
EOF

chmod 755 /etc/grub.d/40_custom
echo "GRUB custom configuration updated with password protection."

echo "Updating GRUB configuration..."
if update-grub; then
    echo "GRUB configuration updated successfully."
    echo "Username: root"
    echo "Password: StrongPassword123!"
    echo "Please reboot to test the configuration."
else
    echo "Failed to update GRUB configuration."
    exit 1
fi
