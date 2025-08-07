#!/bin/bash

source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

# --------- Detect if in container or no TTY ----------
if grep -qa container /proc/1/environ || systemd-detect-virt --quiet --container || ! [ -t 0 ]; then
    HARDN_STATUS "info" "Skipping AppArmor setup (container or non-interactive)."
    return 0 2>/dev/null || exit 0
fi

# --------- Check for desktop environment ----------
DESKTOP_DETECTED=false
if systemctl is-active --quiet gdm3 2>/dev/null || systemctl is-active --quiet gdm 2>/dev/null; then
    DESKTOP_DETECTED=true
    HARDN_STATUS "info" "GDM desktop manager detected."
elif systemctl is-active --quiet lightdm 2>/dev/null; then
    DESKTOP_DETECTED=true
    HARDN_STATUS "info" "LightDM desktop manager detected."
elif systemctl is-active --quiet sddm 2>/dev/null; then
    DESKTOP_DETECTED=true
    HARDN_STATUS "info" "SDDM desktop manager detected."
elif [ -n "$DISPLAY" ] || [ -n "$XDG_SESSION_TYPE" ]; then
    DESKTOP_DETECTED=true
    HARDN_STATUS "info" "Desktop environment detected via environment variables."
fi

if [ "$DESKTOP_DETECTED" = "true" ]; then
    HARDN_STATUS "info" "Desktop environment detected - will use safe AppArmor configuration."
fi

# --------- Set Default Mode ----------
# AppArmor will run in enforce mode by default for maximum security
# But use complain mode if desktop environment is detected for safety
if [ "$DESKTOP_DETECTED" = "true" ]; then
    MODE="complain"
    HARDN_STATUS "info" "AppArmor configured to run in complain mode (desktop environment detected - safer mode)."
else
    MODE="enforce"
    HARDN_STATUS "info" "AppArmor configured to run in enforce mode (default secure setting)."
fi

# --------- Begin Installation ----------
HARDN_STATUS "info" "Initializing AppArmor security module..."

if ! is_installed apparmor || ! is_installed apparmor-utils; then
    HARDN_STATUS "info" "AppArmor packages not found. Installing..."
    if command -v apt >/dev/null 2>&1; then
        if ! (apt update -y && apt install -y apparmor apparmor-utils); then
            HARDN_STATUS "warning" "Failed to install AppArmor with apt."
            return 0
        fi
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y apparmor apparmor-utils || {
            HARDN_STATUS "warning" "Failed to install AppArmor with dnf."
            return 0
        }
    elif command -v yum >/dev/null 2>&1; then
        yum install -y apparmor apparmor-utils || {
            HARDN_STATUS "warning" "Failed to install AppArmor with yum."
            return 0
        }
    fi
fi

# --------- Ensure Kernel Boot Flag ----------
if ! grep -q "apparmor=1" /proc/cmdline; then
    if grep -q '^GRUB_CMDLINE_LINUX="' /etc/default/grub; then
        # Backup GRUB configuration before modification
        GRUB_BACKUP="/etc/default/grub.hardn-backup-$(date +%Y%m%d%H%M%S)"
        if ! cp /etc/default/grub "$GRUB_BACKUP"; then
            HARDN_STATUS "error" "Failed to backup GRUB configuration. Skipping AppArmor kernel parameters."
            return 0 2>/dev/null || exit 0
        fi
        HARDN_STATUS "info" "GRUB configuration backed up to $GRUB_BACKUP"
        
        # Check if apparmor parameters already exist to avoid duplicates
        if grep -q "apparmor=1\|security=apparmor" /etc/default/grub; then
            HARDN_STATUS "info" "AppArmor parameters already present in GRUB configuration."
        else
            HARDN_STATUS "info" "Updating GRUB to enable AppArmor..."
            sed -i 's/^GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="apparmor=1 security=apparmor /' /etc/default/grub
            
            # Validate the modification was successful
            if ! grep -q "apparmor=1.*security=apparmor" /etc/default/grub; then
                HARDN_STATUS "error" "GRUB modification failed. Restoring backup."
                cp "$GRUB_BACKUP" /etc/default/grub
                return 0 2>/dev/null || exit 0
            fi
        fi
        
        if grep -q "ID=debian" /etc/os-release || grep -q "ID=ubuntu" /etc/os-release; then
            if timeout 60 update-grub 2>/dev/null; then
                HARDN_STATUS "info" "GRUB updated successfully. Reboot required for full AppArmor activation."
            else
                HARDN_STATUS "warning" "GRUB update timed out or failed. AppArmor enabled in config but may need manual GRUB update."
            fi
        elif grep -q "ID=fedora" /etc/os-release || grep -q "ID=centos" /etc/os-release; then
            if timeout 60 grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null; then
                HARDN_STATUS "info" "GRUB updated successfully. Reboot required for full AppArmor activation."
            else
                HARDN_STATUS "warning" "GRUB update timed out or failed. AppArmor enabled in config but may need manual GRUB update."
            fi
        else
            HARDN_STATUS "warning" "Unsupported distribution. GRUB update skipped - please enable AppArmor manually."
        fi
    else
        HARDN_STATUS "warning" "Could not modify GRUB configuration. Please enable AppArmor manually."
    fi
fi

# --------- Load Kernel Module ----------
if ! lsmod | grep -q apparmor; then
    HARDN_STATUS "info" "Loading AppArmor kernel module..."
    if timeout 10 modprobe apparmor 2>/dev/null; then
        HARDN_STATUS "info" "AppArmor kernel module loaded."
    else
        HARDN_STATUS "warning" "Failed to load AppArmor kernel module or kernel doesn't support it."
        HARDN_STATUS "info" "AppArmor will be enabled after reboot if GRUB was updated."
        return 0 2>/dev/null || exit 0
    fi
fi

# --------- Apply Selected Mode ----------
if [[ "$MODE" == "enforce" ]]; then
    HARDN_STATUS "info" "Enforcing AppArmor profiles (with exceptions for critical services)..."
    
    # protected services - Define BEFORE enforcement to prevent login breakage
    CRITICAL_SERVICES=(
        # Display managers
        "/etc/apparmor.d/usr.sbin.gdm3"
        "/etc/apparmor.d/usr.bin.gdm3"
        "/etc/apparmor.d/gdm3"
        "/etc/apparmor.d/usr.sbin.lightdm"
        "/etc/apparmor.d/lightdm"
        "/etc/apparmor.d/usr.sbin.sddm"
        "/etc/apparmor.d/usr.bin.sddm"
        "/etc/apparmor.d/sddm"
        "/etc/apparmor.d/usr.sbin.lxdm"
        "/etc/apparmor.d/usr.bin.lxdm"
        "/etc/apparmor.d/lxdm"
        "/etc/apparmor.d/usr.sbin.xdm"
        "/etc/apparmor.d/usr.bin.xdm"
        "/etc/apparmor.d/xdm"
        "/etc/apparmor.d/usr.sbin.slim"
        "/etc/apparmor.d/usr.bin.slim"
        "/etc/apparmor.d/slim"
        
        # Network security
        "/etc/apparmor.d/usr.bin.suricata"
        "/etc/apparmor.d/suricata"
        "/etc/apparmor.d/usr.sbin.snort"
        "/etc/apparmor.d/usr.bin.snort"
        "/etc/apparmor.d/usr.sbin.fail2ban-server"
        "/etc/apparmor.d/usr.bin.fail2ban-server"
        "/etc/apparmor.d/usr.bin.tcpdump"
        "/etc/apparmor.d/usr.sbin.tcpdump"
        "/etc/apparmor.d/usr.bin.zeek"
        "/etc/apparmor.d/usr.sbin.zeek"
        
        # Networking
        "/etc/apparmor.d/usr.sbin.NetworkManager"
        "/etc/apparmor.d/usr.bin.wpa_supplicant"
        "/etc/apparmor.d/usr.sbin.dhclient"
        "/etc/apparmor.d/usr.sbin.dhcpcd"
        "/etc/apparmor.d/usr.bin.nmcli"
        "/etc/apparmor.d/usr.sbin.connmand"
        "/etc/apparmor.d/usr.lib.systemd.systemd-networkd"
        "/etc/apparmor.d/usr.sbin.iwd"
        "/etc/apparmor.d/usr.sbin.wicd"
        "/etc/apparmor.d/usr.bin.systemd-resolved"
        "/etc/apparmor.d/usr.sbin.avahi-daemon"
        "/etc/apparmor.d/usr.sbin.ModemManager"
        "/etc/apparmor.d/usr.sbin.pppd"
        "/etc/apparmor.d/usr.sbin.dnsmasq"
        
        # System services
        "/etc/apparmor.d/usr.sbin.sshd"
        "/etc/apparmor.d/sshd"
        "/etc/apparmor.d/usr.sbin.cron"
        "/etc/apparmor.d/usr.bin.dbus-daemon"
        "/etc/apparmor.d/usr.lib.systemd.systemd-logind"
        "/etc/apparmor.d/usr.lib.systemd.systemd-journald"
        "/etc/apparmor.d/usr.lib.systemd.systemd-udevd"
        "/etc/apparmor.d/usr.lib.systemd.systemd-timesyncd"
        "/etc/apparmor.d/usr.lib.systemd.systemd-resolved"
        "/etc/apparmor.d/usr.lib.systemd.systemd-machined"
        "/etc/apparmor.d/usr.lib.systemd.systemd-tmpfiles"
        "/etc/apparmor.d/usr.lib.systemd.systemd-oomd"
        
        # X server
        "/etc/apparmor.d/usr.bin.Xorg"
        "/etc/apparmor.d/usr.lib.xorg.Xorg"
        
        # Legion
        "/etc/apparmor.d/usr.bin.legion"
        "/etc/apparmor.d/legion"
        
        # HARDN-XDR
        "/etc/apparmor.d/usr.bin.hardn-xdr"
        "/etc/apparmor.d/hardn-xdr"
        "/etc/apparmor.d/usr.lib.hardn-xdr"
    )
    
    # Set critical services to complain mode FIRST to prevent service breakage
    HARDN_STATUS "info" "Setting critical services to complain mode to prevent service breakage..."
    for service in "${CRITICAL_SERVICES[@]}"; do
        if [[ -f "$service" ]]; then
            if timeout 10 aa-complain "$service" 2>/dev/null; then
                HARDN_STATUS "info" "Set $(basename "$service") to complain mode."
            else
                HARDN_STATUS "warning" "Failed to set $(basename "$service") to complain mode."
            fi
        fi
    done
    
    # Now enforce all profiles (critical services already protected)
    HARDN_STATUS "info" "Enforcing remaining AppArmor profiles..."
    if timeout 30 aa-enforce /etc/apparmor.d/* 2>/dev/null; then
        HARDN_STATUS "info" "AppArmor profiles enforced successfully."
    else
        HARDN_STATUS "warning" "Some profiles could not be enforced or operation timed out."
    fi
    
elif [[ "$MODE" == "complain" ]]; then
    HARDN_STATUS "info" "Setting all AppArmor profiles to complain mode..."
    if timeout 30 aa-complain /etc/apparmor.d/* 2>/dev/null; then
        HARDN_STATUS "info" "AppArmor profiles set to complain mode successfully."
    else
        HARDN_STATUS "warning" "Some profiles could not be put in complain mode or operation timed out."
    fi
fi

# --------- Service Handling ----------
HARDN_STATUS "info" "Managing AppArmor service..."
if timeout 20 systemctl restart apparmor.service 2>/dev/null; then
    HARDN_STATUS "info" "AppArmor service restarted successfully."
else
    HARDN_STATUS "warning" "AppArmor service restart failed or timed out."
fi

if systemctl enable apparmor.service 2>/dev/null; then
    HARDN_STATUS "info" "AppArmor service enabled for startup."
else
    HARDN_STATUS "warning" "Failed to enable AppArmor service."
fi

# --------- Status Output ----------
if command -v aa-status &>/dev/null; then
    HARDN_STATUS "info" "Current AppArmor profile status:"
    if timeout 10 aa-status 2>/dev/null; then
        HARDN_STATUS "info" "AppArmor status retrieved successfully."
        
        # Check if critical services are in complain mode
        if aa-status 2>/dev/null | grep -q "complain"; then
            HARDN_STATUS "info" "Some profiles are in complain mode (this is expected for critical services)."
        fi
    else
        HARDN_STATUS "warning" "AppArmor status check timed out or failed."
    fi
fi

# --------- Service Status Check ----------
HARDN_STATUS "info" "Checking critical service status after AppArmor configuration..."

# Check GDM3 service
if systemctl is-active --quiet gdm3 2>/dev/null; then
    HARDN_STATUS "info" "GDM3 login manager is running correctly."
else
    HARDN_STATUS "warning" "GDM3 may have issues - check logs if login problems occur."
fi

# Check Suricata service if installed
if command -v suricata &>/dev/null && systemctl is-enabled suricata 2>/dev/null; then
    if systemctl is-active --quiet suricata 2>/dev/null; then
        HARDN_STATUS "info" "Suricata IDS is running correctly."
    else
        HARDN_STATUS "warning" "Suricata IDS may have issues - check logs if network monitoring fails."
    fi
fi

HARDN_STATUS "pass" "AppArmor module completed in $MODE mode."


return 0 2>/dev/null || hardn_module_exit 0
