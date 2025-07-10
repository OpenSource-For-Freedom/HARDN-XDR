#!/bin/bash

# HARDN-XDR - GRUB Password Hardening Module
# Complies: LYNIS BOOT-5122 
# VM/ container detection
# supplies hardn.env for storage 

LOG_DIR="/var/log/hardn"
LOG_FILE="$LOG_DIR/grub_password.log"
GRUB_USER_FILE="/etc/grub.d/01_users"
ENV_FILE="/etc/hardn/hardn.env"

HARDN_STATUS() {
    local status="$1"
    local message="$2"
    local color="\033[0m"
    case "$status" in
        info) color="\033[1;34m" ;;
        pass) color="\033[1;32m" ;;
        warning) color="\033[1;33m" ;;
        error) color="\033[1;31m" ;;
    esac
    echo -e "${color}[${status^^}]\033[0m $message"
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

is_virtualized() {
    grep -qa 'docker\|lxc\|wsl' /proc/1/cgroup && return 0
    [[ "$(systemd-detect-virt)" != "none" ]] && return 0
    return 1
}

load_env_values() {
    if [ -f "$ENV_FILE" ]; then

        source "$ENV_FILE"
        export GRUB_USERNAME GRUB_PASSWORD_HASH
    fi
}

prompt_password_hash() {
    echo -e "\n\033[1;36m[INPUT]\033[0m Enter a GRUB username (e.g., admin):"
    read -r grub_user
    echo -e "\n\033[1;36m[INPUT]\033[0m Enter a password for GRUB superuser '$grub_user':"
    grub_hash=$(grub-mkpasswd-pbkdf2 | awk '/PBKDF2 hash of your password is/ {print $NF}')
    echo "$grub_user:$grub_hash"
}

write_grub_user_file() {
    local user="$1"
    local hash="$2"

    cat <<EOF > "$GRUB_USER_FILE"
#!/bin/sh
cat <<EOM
set superuser="$user"
password_pbkdf2 $user $hash
EOM
EOF

    chmod 755 "$GRUB_USER_FILE"
    HARDN_STATUS "pass" "GRUB user file created at $GRUB_USER_FILE"
    log "Set GRUB superuser '$user' with password hash."
}

update_grub_config() {
    if command -v update-grub >/dev/null 2>&1; then
        update-grub && HARDN_STATUS "pass" "GRUB configuration updated."
    elif command -v grub2-mkconfig >/dev/null 2>&1; then
        grub2-mkconfig -o /boot/grub2/grub.cfg && HARDN_STATUS "pass" "GRUB config updated (grub2-mkconfig)."
    else
        HARDN_STATUS "error" "No GRUB configuration tool found."
    fi
}

grub_protect() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"

    # Skip if already configured
    if [ -f "$GRUB_USER_FILE" ] && grep -q 'password_pbkdf2' "$GRUB_USER_FILE"; then
        HARDN_STATUS "info" "GRUB password already set."
        return 0
    fi

    # Skip if VM or container
    if is_virtualized; then
        HARDN_STATUS "info" "Running in a virtualized/container environment — skipping GRUB password protection."
        log "GRUB hardening skipped (VM/container detected)."
        return 0
    fi


    load_env_values
    local user=""
    local hash=""

    if [[ -n "$GRUB_USERNAME" && -n "$GRUB_PASSWORD_HASH" ]]; then
        user="$GRUB_USERNAME"
        hash="$GRUB_PASSWORD_HASH"
        HARDN_STATUS "info" "Loaded GRUB credentials from $ENV_FILE"
    else
        # Fallback to interactive
        if [ -t 0 ]; then
            user_and_hash=$(prompt_password_hash)
            user="${user_and_hash%%:*}"
            hash="${user_and_hash#*:}"
        else
            HARDN_STATUS "warning" "Interactive prompt disabled and no preset hash found — skipping GRUB protection."
            log "No GRUB credentials could be set (non-interactive mode)."
            return 0
        fi
    fi

    write_grub_user_file "$user" "$hash"
    update_grub_config

    HARDN_STATUS "pass" "GRUB password protection applied."
    return 0
}

# if called directly/locally 
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    grub_protect "$@"
fi