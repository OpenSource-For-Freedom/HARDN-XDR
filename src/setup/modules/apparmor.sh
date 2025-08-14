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


# --------- Detect if in container or no TTY ----------
if is_container_environment; then
    HARDN_STATUS "info" "Container environment detected, skipping AppArmor setup."
    HARDN_STATUS "info" "AppArmor is typically managed by the container runtime"
    return 0 2>/dev/null || exit 0
fi

# --------- Check for desktop environment ----------
DESKTOP_DETECTED=false
if safe_systemctl "status" "gdm3" "--quiet" || safe_systemctl "status" "gdm" "--quiet"; then
    DESKTOP_DETECTED=true
    HARDN_STATUS "info" "GDM desktop manager detected."
elif safe_systemctl "status" "lightdm" "--quiet"; then
    DESKTOP_DETECTED=true
    HARDN_STATUS "info" "LightDM desktop manager detected."
elif safe_systemctl "status" "sddm" "--quiet"; then
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
# STIG Compliance Enhancement: Support for enforce mode with selective complain mode
# Check for STIG_COMPLIANT environment variable to force enforcement
if [[ "${STIG_COMPLIANT:-false}" == "true" ]] || [[ "${FORCE_APPARMOR_ENFORCE:-false}" == "true" ]]; then
    MODE="enforce"
    HARDN_STATUS "info" "STIG compliance mode enabled - AppArmor will run in enforce mode for maximum security."
elif [ "$DESKTOP_DETECTED" = "true" ]; then
    MODE="complain"
    HARDN_STATUS "info" "AppArmor configured to run in complain mode (desktop environment detected - safer mode)."
    HARDN_STATUS "info" "To enable STIG compliance mode, set STIG_COMPLIANT=true or FORCE_APPARMOR_ENFORCE=true"
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
safe_systemctl "restart" "apparmor.service"
safe_systemctl "enable" "apparmor.service"

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

# --------- STIG Compliance Enhancements ----------
# Add STIG-specific AppArmor hardening measures
apply_stig_apparmor_enhancements

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

# --------- STIG AppArmor Enhancement Function ----------
apply_stig_apparmor_enhancements() {
    HARDN_STATUS "info" "Applying STIG-specific AppArmor enhancements..."
    
    local stig_config_dir="/etc/hardn-xdr/apparmor-stig"
    mkdir -p "$stig_config_dir"
    
    # Create STIG-compliant AppArmor profiles for common services
    create_stig_apparmor_profiles "$stig_config_dir"
    
    # Apply STIG-specific enforcement policies
    if [[ "${STIG_COMPLIANT:-false}" == "true" ]] || [[ "${FORCE_APPARMOR_ENFORCE:-false}" == "true" ]]; then
        apply_stig_enforcement_policies
    fi
    
    # Document current AppArmor compliance status
    document_apparmor_compliance "$stig_config_dir"
    
    HARDN_STATUS "info" "STIG AppArmor enhancements completed"
}

create_stig_apparmor_profiles() {
    local config_dir="$1"
    HARDN_STATUS "info" "Creating STIG-compliant AppArmor profiles..."
    
    # Create enhanced SSH profile
    cat > "$config_dir/sshd-stig-profile" << 'EOF'
# STIG-compliant SSH AppArmor profile
# Based on DISA STIG requirements for SSH access controls

#include <tunables/global>

/usr/sbin/sshd {
  #include <abstractions/authentication>
  #include <abstractions/base>
  #include <abstractions/consoles>
  #include <abstractions/nameservice>
  #include <abstractions/wutmp>
  
  capability sys_admin,
  capability sys_chroot,
  capability sys_resource,
  capability sys_tty_config,
  capability setgid,
  capability setuid,
  capability audit_control,
  capability audit_write,
  
  # STIG requirement: Restrict file access
  /etc/ssh/** r,
  /etc/hosts.allow r,
  /etc/hosts.deny r,
  /var/log/auth.log w,
  /var/log/secure w,
  
  # STIG requirement: Limit process execution
  /bin/sh ix,
  /usr/bin/passwd ix,
  /usr/bin/sudo ix,
  
  # Deny dangerous operations
  deny /etc/shadow w,
  deny /etc/gshadow w,
  deny /boot/** w,
  deny /sys/kernel/security/** w,
  
  # Network restrictions
  network inet stream,
  network inet6 stream,
  
  # Process restrictions
  ptrace (read, trace) peer=unconfined,
}
EOF

    # Create enhanced web server profile template
    cat > "$config_dir/web-server-stig-template" << 'EOF'
# STIG-compliant web server AppArmor profile template
# Customize for your specific web server (Apache, Nginx, etc.)

#include <tunables/global>

/usr/sbin/apache2 {
  #include <abstractions/base>
  #include <abstractions/nameservice>
  
  capability dac_override,
  capability setgid,
  capability setuid,
  
  # STIG requirement: Restrict document root access
  /var/www/html/** r,
  /var/log/apache2/** w,
  
  # STIG requirement: Deny system file access
  deny /etc/passwd r,
  deny /etc/shadow r,
  deny /home/** r,
  deny /root/** r,
  deny /tmp/** w,
  deny /var/tmp/** w,
  
  # STIG requirement: Limit executable access
  /usr/bin/php* ix,
  /usr/lib/apache2/modules/** mr,
  
  # Network access
  network inet stream,
  network inet6 stream,
}
EOF

    HARDN_STATUS "info" "STIG AppArmor profiles created in $config_dir"
}

apply_stig_enforcement_policies() {
    HARDN_STATUS "info" "Applying STIG enforcement policies..."
    
    # Get list of profiles currently in complain mode
    local complain_profiles=()
    if command -v aa-status >/dev/null 2>&1; then
        while IFS= read -r line; do
            if [[ $line =~ ^[[:space:]]*([^[:space:]]+)[[:space:]]+\(complain\) ]]; then
                complain_profiles+=("${BASH_REMATCH[1]}")
            fi
        done < <(aa-status 2>/dev/null | grep "(complain)" || true)
    fi
    
    # Create whitelist of profiles that MUST stay in complain mode for system stability
    local always_complain=(
        "/usr/sbin/gdm3"
        "/usr/bin/gdm3"
        "/usr/sbin/lightdm"
        "/usr/sbin/sddm"
        "/usr/sbin/xdm"
    )
    
    # Selectively enforce profiles that are safe to enforce
    local enforced_count=0
    for profile in "${complain_profiles[@]}"; do
        local should_complain=false
        
        # Check if this profile should remain in complain mode
        for always_complain_profile in "${always_complain[@]}"; do
            if [[ "$profile" == "$always_complain_profile" ]]; then
                should_complain=true
                break
            fi
        done
        
        # Enforce if it's safe to do so
        if [[ "$should_complain" == false ]]; then
            if timeout 10 aa-enforce "$profile" 2>/dev/null; then
                HARDN_STATUS "info" "Enforced AppArmor profile: $(basename "$profile")"
                ((enforced_count++))
            else
                HARDN_STATUS "warning" "Failed to enforce profile: $(basename "$profile")"
            fi
        else
            HARDN_STATUS "info" "Keeping critical service in complain mode: $(basename "$profile")"
        fi
    done
    
    HARDN_STATUS "info" "STIG enforcement applied to $enforced_count profiles"
}

document_apparmor_compliance() {
    local config_dir="$1"
    HARDN_STATUS "info" "Documenting AppArmor compliance status..."
    
    cat > "$config_dir/apparmor-stig-compliance.txt" << EOF
HARDN-XDR AppArmor STIG Compliance Report
========================================
Generated: $(date)

STIG Requirements Addressed:
- AC-3: Access Enforcement via mandatory access controls
- AC-6: Least Privilege through profile restrictions  
- CM-7: Least Functionality by restricting application capabilities
- SI-3: Malicious Code Protection through application sandboxing

Current AppArmor Status:
EOF

    # Add current status information
    if command -v aa-status >/dev/null 2>&1; then
        echo "" >> "$config_dir/apparmor-stig-compliance.txt"
        echo "Profiles in Enforce Mode:" >> "$config_dir/apparmor-stig-compliance.txt"
        aa-status 2>/dev/null | grep "(enforce)" | head -10 >> "$config_dir/apparmor-stig-compliance.txt" || true
        
        echo "" >> "$config_dir/apparmor-stig-compliance.txt"
        echo "Profiles in Complain Mode:" >> "$config_dir/apparmor-stig-compliance.txt"
        aa-status 2>/dev/null | grep "(complain)" | head -10 >> "$config_dir/apparmor-stig-compliance.txt" || true
        
        echo "" >> "$config_dir/apparmor-stig-compliance.txt"
        echo "Unconfined Processes:" >> "$config_dir/apparmor-stig-compliance.txt"
        aa-status 2>/dev/null | grep "processes are unconfined" >> "$config_dir/apparmor-stig-compliance.txt" || true
    fi
    
    cat >> "$config_dir/apparmor-stig-compliance.txt" << 'EOF'

STIG Compliance Recommendations:
1. Regularly review and update AppArmor profiles
2. Test profile changes in complain mode before enforcement
3. Monitor AppArmor logs for policy violations
4. Implement custom profiles for organization-specific applications
5. Regular compliance validation using OpenSCAP scans

STIG Controls Mapped:
- RHEL-08-010370: Mandatory access control policy implementation
- RHEL-08-010371: Mandatory access control policy enforcement
- RHEL-08-010372: Application restrictions via MAC policies

For enhanced STIG compliance, run AppArmor in enforce mode:
export STIG_COMPLIANT=true
or
export FORCE_APPARMOR_ENFORCE=true

Monitoring Commands:
- View current status: aa-status
- Check logs: grep apparmor /var/log/syslog
- Test profile: aa-complain <profile> && aa-enforce <profile>
EOF

    HARDN_STATUS "info" "AppArmor compliance documentation saved to $config_dir/apparmor-stig-compliance.txt"
}

HARDN_STATUS "pass" "AppArmor module completed in $MODE mode."


return 0 2>/dev/null || hardn_module_exit 0
set -e
