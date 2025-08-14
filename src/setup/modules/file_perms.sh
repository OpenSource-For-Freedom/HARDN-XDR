#!/bin/bash
# Source common functions with fallback for development/CI environments
source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
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
}
#!/bin/bash
set -e

# Check for container environment
if is_container_environment; then
    HARDN_STATUS "info" "Container environment detected - file permission modifications may be restricted"
    HARDN_STATUS "info" "Some filesystems in containers may be read-only or have permission restrictions"
fi

HARDN_STATUS "info" "Setting secure file permissions..."

# Function to safely change permissions
safe_chmod() {
    local perm="$1"
    local file="$2"
    local description="$3"
    
    if [[ -e "$file" ]]; then
        if chmod "$perm" "$file" 2>/dev/null; then
            HARDN_STATUS "pass" "Set permissions $perm on $file ($description)"
        else
            HARDN_STATUS "warning" "Failed to set permissions on $file ($description) - may be read-only"
        fi
    else
        HARDN_STATUS "warning" "File $file not found, skipping permission change"
    fi
}

safe_chmod 700 /root "root home directory"
safe_chmod 644 /etc/passwd "user database"
safe_chmod 600 /etc/shadow "password hashes"
safe_chmod 644 /etc/group "group database"
safe_chmod 600 /etc/gshadow "group passwords"

# Set permissions for sshd_config only if it exists
if [ -f /etc/ssh/sshd_config ]; then
    safe_chmod 644 /etc/ssh/sshd_config "SSH daemon config"
else
    HARDN_STATUS "warning" "SSH configuration file not found, skipping"
fi

HARDN_STATUS "pass" "File permissions hardening completed."

return 0 2>/dev/null || hardn_module_exit 0
