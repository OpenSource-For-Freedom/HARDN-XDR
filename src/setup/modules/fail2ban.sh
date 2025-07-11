#!/bin/bash

# Fail2ban installation and configuration module for HARDN-XDR
# This script is meant to be sourced by hardn-main.sh

# Install fail2ban based on detected package manager
hardn_install_fail2ban() {
        HARDN_STATUS "info" "Installing fail2ban..."

        # Use case statement for package manager detection
        local pkg_mgr=""
        for cmd in apt dnf yum; do
            if command -v "$cmd" >/dev/null 2>&1; then
                pkg_mgr="$cmd"
                break
            fi
        done

        local install_status=1

        case "$pkg_mgr" in
            apt)
                HARDN_STATUS "info" "Using apt package manager"
                if apt update && apt install -y fail2ban; then
                    install_status=0
                fi
                ;;
            dnf|yum)
                HARDN_STATUS "info" "Using ${pkg_mgr} package manager"
                if "$pkg_mgr" install -y epel-release fail2ban; then
                    install_status=0
                fi
                ;;
            *)
                HARDN_STATUS "error" "No supported package manager found (apt, dnf, yum)"
                return 1
                ;;
        esac

        # Verify installation regardless of package manager result
        if [ "$install_status" -eq 0 ] && command -v fail2ban-client >/dev/null 2>&1; then
            HARDN_STATUS "pass" "Fail2ban installed successfully"
            return 0
        else
            HARDN_STATUS "error" "Fail2ban installation failed"
            return 1
        fi
}

hardn_enable_fail2ban() {
        HARDN_STATUS "info" "Enabling and starting fail2ban service..."

        if systemctl enable fail2ban &&
           systemctl start fail2ban; then
            HARDN_STATUS "pass" "Fail2ban service enabled and started"
            return 0
        else
            HARDN_STATUS "error" "Failed to enable or start fail2ban service"
            return 1
        fi
}

hardn_create_override_dir() {
        local dir="$1"

        HARDN_STATUS "info" "Creating systemd override directory: $dir"

        if ! mkdir -p "$dir"; then
            HARDN_STATUS "error" "Failed to create directory: $dir"
            return 1
        fi

        HARDN_STATUS "pass" "Created systemd override directory"
        return 0
}

# Create fail2ban service override file with security hardening options
hardn_create_service_override() {
    local file="$1"

    HARDN_STATUS "info" "Creating fail2ban service override file"

    cat > "$file" << EOF || {
        HARDN_STATUS "error" "Failed to create $file";
        return 1;
    }
[Service]
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
NoNewPrivileges=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
MemoryDenyWriteExecute=true
RestrictRealtime=true
EOF

    # Set proper permissions
    chmod 644 "$file" || {
        HARDN_STATUS "error" "Failed to set permissions on $file"
        return 1
    }

    HARDN_STATUS "pass" "Created fail2ban service override file"
    return 0
}

hardn_reload_systemd() {
        HARDN_STATUS "info" "Reloading systemd daemon"

        if systemctl daemon-reload; then
            HARDN_STATUS "pass" "Systemd daemon reloaded successfully"
            return 0
        else
            HARDN_STATUS "error" "Failed to reload systemd daemon"
            return 1
        fi
}

# Apply security hardening to fail2ban systemd service
hardn_harden_fail2ban() {
        HARDN_STATUS "info" "Applying security hardening to fail2ban service..."

        local override_dir="/etc/systemd/system/fail2ban.service.d"
        local override_file="${override_dir}/override.conf"

        # Execute each step in sequence, stopping if any fails
        if hardn_create_override_dir "$override_dir" &&
           hardn_create_service_override "$override_file" &&
           hardn_reload_systemd; then
            HARDN_STATUS "pass" "Fail2ban service hardened successfully"
            return 0
        else
            HARDN_STATUS "error" "Failed to harden fail2ban service"
            return 1
        fi
}

hardn_setup_fail2ban() {
        HARDN_STATUS "info" "Setting up fail2ban..."

        # Run all steps in sequence, stopping if any fails
        if hardn_install_fail2ban &&
           hardn_harden_fail2ban &&
           hardn_enable_fail2ban; then
            HARDN_STATUS "pass" "Fail2ban installation and setup completed successfully"
            return 0
        else
            HARDN_STATUS "error" "Fail2ban setup failed"
            return 1
        fi
}

# SOURCE THIS SCRIPT ONLY!
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    printf "Error: This script should be sourced by hardn-main.sh, not executed directly.\n" >&2
    exit 1
fi
# Run a syntax check on the script if needed.
# bash -n HARDN-XDR/src/setup/modules/fail2ban.sh

# End of script
