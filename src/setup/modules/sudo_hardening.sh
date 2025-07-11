#!/bin/bash
# sudo_hardening.sh - STIG Compliance: Privileged Access & Sudo Configuration
# Implements sudoers hardening, RBAC enforcement, and command restrictions

set -e

# Fallback for CI
HARDN_STATUS() {
    local status="$1"
    local message="$2"
    case "$status" in
        "pass")    echo -e "\033[1;32m[PASS]\033[0m $message" ;;
        "warning") echo -e "\033[1;33m[WARNING]\033[0m $message" ;;
        "error")   echo -e "\033[1;31m[ERROR]\033[0m $message" ;;
        "info")    echo -e "\033[1;34m[INFO]\033[0m $message" ;;
        *)          echo -e "\033[1;37m[UNKNOWN]\033[0m $message" ;;
    esac
}

is_installed() {
    if command -v apt >/dev/null 2>&1; then
        dpkg -s "$1" >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        dnf list installed "$1" >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum list installed "$1" >/dev/null 2>&1
    elif command -v rpm >/dev/null 2>&1; then
        rpm -q "$1" >/dev/null 2>&1
    else
        return 1
    fi
}

backup_sudoers() {
    HARDN_STATUS "info" "Creating backup of sudoers configuration..."
    local backup_dir="/etc/sudoers.d/backups"
    mkdir -p "$backup_dir"
    cp /etc/sudoers "${backup_dir}/sudoers.bak.$(date +%F-%T)" 2>/dev/null || true
    if [ -d /etc/sudoers.d ]; then
        cp -r /etc/sudoers.d "${backup_dir}/sudoers.d.bak.$(date +%F-%T)" 2>/dev/null || true
    fi
    HARDN_STATUS "pass" "Sudoers backup created in $backup_dir"
}

install_sudo_if_needed() {
    if ! is_installed sudo; then
        HARDN_STATUS "info" "Installing sudo package..."
        if command -v apt >/dev/null 2>&1; then
            apt-get update >/dev/null 2>&1
            apt-get install -y sudo >/dev/null 2>&1
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y sudo >/dev/null 2>&1
        elif command -v yum >/dev/null 2>&1; then
            yum install -y sudo >/dev/null 2>&1
        fi
        HARDN_STATUS "pass" "Sudo package installed"
    else
        HARDN_STATUS "info" "Sudo package already installed"
    fi
}

create_hardened_sudoers_config() {
    HARDN_STATUS "info" "Creating hardened sudoers configuration..."
    
    # Create STIG-compliant sudoers drop-in file
    cat > /etc/sudoers.d/90-hardn-stig << 'EOF'
# HARDN-XDR STIG Compliant Sudoers Configuration
# This file implements STIG requirements for sudo hardening

# Command logging - log all sudo commands
Defaults logfile=/var/log/sudo.log
Defaults log_input,log_output
Defaults iolog_dir=/var/log/sudo-io

# Security defaults
Defaults requiretty
Defaults !visiblepw
Defaults always_set_home
Defaults match_group_by_gid
Defaults always_query_group_plugin

# Timeout and retry settings
Defaults passwd_timeout=1
Defaults passwd_tries=3
Defaults timestamp_timeout=5

# Environment restrictions
Defaults env_reset
Defaults env_keep="COLORS DISPLAY HOSTNAME HISTSIZE KDEDIR LS_COLORS"
Defaults env_keep+="MAIL PS1 PS2 QTDIR USERNAME LANG LC_ADDRESS LC_CTYPE"
Defaults env_keep+="LC_COLLATE LC_IDENTIFICATION LC_MEASUREMENT LC_MESSAGES"
Defaults env_keep+="LC_MONETARY LC_NAME LC_NUMERIC LC_PAPER LC_TELEPHONE"
Defaults env_keep+="LC_TIME LC_ALL LANGUAGE LINGUAS _XKB_CHARSET XAUTHORITY"

# Secure path
Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Command aliases for restricted access
Cmnd_Alias NETWORKING = /sbin/route, /sbin/ifconfig, /bin/ping, /sbin/dhclient, /usr/bin/net, /sbin/iptables, /usr/bin/rfcomm, /usr/bin/wvdial, /sbin/iwconfig, /sbin/mii-tool
Cmnd_Alias SOFTWARE = /bin/rpm, /usr/bin/up2date, /usr/bin/yum, /usr/bin/apt-get, /usr/bin/apt, /usr/bin/dpkg
Cmnd_Alias SERVICES = /sbin/service, /sbin/chkconfig, /usr/bin/systemctl, /bin/systemctl
Cmnd_Alias STORAGE = /sbin/fdisk, /sbin/sfdisk, /sbin/parted, /sbin/partprobe, /bin/mount, /bin/umount
Cmnd_Alias DELEGATING = /usr/sbin/visudo, /bin/chown, /bin/chmod, /bin/chgrp
Cmnd_Alias PROCESSES = /bin/nice, /bin/kill, /usr/bin/kill, /usr/bin/killall
Cmnd_Alias DRIVERS = /sbin/modprobe, /sbin/rmmod, /sbin/insmod

# User privilege specification - customize as needed
# Administrators group gets most privileges with logging
%sudo ALL=(ALL:ALL) NOPASSWD: SOFTWARE, SERVICES, STORAGE, NETWORKING
%admin ALL=(ALL:ALL) NOPASSWD: SOFTWARE, SERVICES, STORAGE, NETWORKING

# Security group gets limited privileges
%security ALL=(ALL:ALL) NOPASSWD: PROCESSES, /usr/bin/tail /var/log/*, /usr/bin/less /var/log/*

# Deny dangerous commands to all users
ALL ALL = !/bin/su, !/usr/bin/su, !/bin/bash, !/usr/bin/bash, !/bin/sh, !/usr/bin/sh
ALL ALL = !/usr/bin/passwd root, !/usr/bin/passwd
ALL ALL = !/sbin/shutdown, !/sbin/reboot, !/sbin/halt
EOF

    # Set proper permissions
    chmod 440 /etc/sudoers.d/90-hardn-stig
    chown root:root /etc/sudoers.d/90-hardn-stig
    
    HARDN_STATUS "pass" "Hardened sudoers configuration created"
}

setup_sudo_logging() {
    HARDN_STATUS "info" "Setting up sudo command logging..."
    
    # Create log directories
    mkdir -p /var/log/sudo-io
    chmod 750 /var/log/sudo-io
    chown root:adm /var/log/sudo-io
    
    # Create sudo log file
    touch /var/log/sudo.log
    chmod 640 /var/log/sudo.log
    chown root:adm /var/log/sudo.log
    
    # Configure logrotate for sudo logs
    cat > /etc/logrotate.d/sudo << 'EOF'
/var/log/sudo.log {
    monthly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 640 root adm
    postrotate
        # Send HUP signal to sudo to reopen log files
        /usr/bin/killall -HUP sudo 2>/dev/null || true
    endscript
}

/var/log/sudo-io/* {
    monthly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF
    
    chmod 644 /etc/logrotate.d/sudo
    
    HARDN_STATUS "pass" "Sudo logging configured with log rotation"
}

validate_sudoers_syntax() {
    HARDN_STATUS "info" "Validating sudoers syntax..."
    if visudo -c -f /etc/sudoers.d/90-hardn-stig; then
        HARDN_STATUS "pass" "Sudoers syntax validation successful"
        return 0
    else
        HARDN_STATUS "error" "Sudoers syntax validation failed - removing invalid configuration"
        rm -f /etc/sudoers.d/90-hardn-stig
        return 1
    fi
}

create_audit_script() {
    HARDN_STATUS "info" "Creating sudoers audit script..."
    
    cat > /usr/local/bin/audit-sudo.sh << 'EOF'
#!/bin/bash
# Sudoers Audit Script - STIG Compliance Check
# This script audits sudo configuration for STIG compliance

echo "=== SUDO CONFIGURATION AUDIT ==="
echo "Audit Date: $(date)"
echo

echo "1. Checking sudo package installation:"
if command -v sudo >/dev/null 2>&1; then
    echo "   ✓ sudo is installed"
    sudo --version | head -1
else
    echo "   ✗ sudo is NOT installed"
fi
echo

echo "2. Checking sudoers file permissions:"
ls -la /etc/sudoers /etc/sudoers.d/
echo

echo "3. Checking for HARDN hardening configuration:"
if [ -f /etc/sudoers.d/90-hardn-stig ]; then
    echo "   ✓ HARDN sudo hardening configuration present"
else
    echo "   ✗ HARDN sudo hardening configuration missing"
fi
echo

echo "4. Checking sudo logging configuration:"
if [ -f /var/log/sudo.log ]; then
    echo "   ✓ Sudo log file exists"
    echo "   Last 3 sudo commands:"
    tail -3 /var/log/sudo.log 2>/dev/null || echo "   (No recent commands)"
else
    echo "   ✗ Sudo log file missing"
fi
echo

echo "5. Checking sudo I/O logging:"
if [ -d /var/log/sudo-io ]; then
    echo "   ✓ Sudo I/O logging directory exists"
    echo "   Session count: $(find /var/log/sudo-io -type f | wc -l)"
else
    echo "   ✗ Sudo I/O logging directory missing"
fi
echo

echo "6. Validating sudoers syntax:"
if visudo -c; then
    echo "   ✓ Sudoers syntax is valid"
else
    echo "   ✗ Sudoers syntax errors detected"
fi

echo
echo "=== END OF SUDO AUDIT ==="
EOF

    chmod 755 /usr/local/bin/audit-sudo.sh
    chown root:root /usr/local/bin/audit-sudo.sh
    
    HARDN_STATUS "pass" "Sudo audit script created at /usr/local/bin/audit-sudo.sh"
}

sudo_hardening_main() {
    HARDN_STATUS "info" "Starting STIG-compliant sudo hardening..."
    
    install_sudo_if_needed
    backup_sudoers
    create_hardened_sudoers_config
    
    if validate_sudoers_syntax; then
        setup_sudo_logging
        create_audit_script
        HARDN_STATUS "pass" "Sudo hardening completed successfully"
        HARDN_STATUS "info" "Run '/usr/local/bin/audit-sudo.sh' to audit sudo configuration"
    else
        HARDN_STATUS "error" "Sudo hardening failed due to syntax errors"
        return 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    sudo_hardening_main "$@"
fi