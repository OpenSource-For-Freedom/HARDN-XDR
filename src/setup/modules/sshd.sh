#!/bin/bash
# sshd.sh - Install and basic setup for OpenSSH server

hardn_ssh_is_installed() {
    command -v sshd &>/dev/null || [ -f "/usr/sbin/sshd" ]
}

hardn_ssh_install() {
    local pkg_manager="" status=0

    # Determine package manager using built-in tests
    if command -v apt-get &>/dev/null; then
        pkg_manager="apt"
    elif command -v yum &>/dev/null; then
        pkg_manager="yum"
    elif command -v dnf &>/dev/null; then
        pkg_manager="dnf"
    else
        HARDN_STATUS "error" "Unsupported package manager. Please install OpenSSH server manually."
        return 1
    fi

    # Install SSH based on detected package manager
    HARDN_STATUS "info" "Installing OpenSSH server using ${pkg_manager}..."
    case "${pkg_manager}" in
        apt)
            apt-get update -qq && apt-get install -y openssh-server || status=1
            ;;
        yum|dnf)
            "${pkg_manager}" install -y openssh-server || status=1
            ;;
    esac

    if [ ${status} -eq 0 ]; then
        HARDN_STATUS "pass" "OpenSSH server installed successfully"
    else
        HARDN_STATUS "error" "Failed to install OpenSSH server"
    fi

    return ${status}
}

hardn_ssh_detect_service() {
    local service_name=""

    # Use read with process substitution to avoid subshell
    while read -r line; do
        case "${line}" in
            *ssh.service*)
                service_name="ssh.service"
                break
                ;;
            *sshd.service*)
                service_name="sshd.service"
                break
                ;;
        esac
    done < <(systemctl list-unit-files | grep -E '(ssh|sshd)\.service')

    if [ -z "${service_name}" ]; then
        HARDN_STATUS "error" "Could not find SSH service"
        return 1
    fi

    echo "${service_name}"
    return 0
}

hardn_ssh_secure_config() {
    local config_file="/etc/ssh/sshd_config"
    local status=0

    if [ ! -f "${config_file}" ]; then
        HARDN_STATUS "error" "SSH config file not found: ${config_file}"
        return 1
    fi

    HARDN_STATUS "info" "Applying secure SSH configuration..."

    # Create backup of original config
    cp -f "${config_file}" "${config_file}.hardn.bak" || status=1

    # Apply security settings using awk for efficiency (single pass)
    awk '
        # Disable root login
        $1 == "PermitRootLogin" { print "PermitRootLogin no"; next }
        /^#PermitRootLogin/ { print "PermitRootLogin no"; next }

        # Disable password authentication
        $1 == "PasswordAuthentication" { print "PasswordAuthentication no"; next }
        /^#PasswordAuthentication/ { print "PasswordAuthentication no"; next }

        # Disable empty passwords
        $1 == "PermitEmptyPasswords" { print "PermitEmptyPasswords no"; next }
        /^#PermitEmptyPasswords/ { print "PermitEmptyPasswords no"; next }

        # Disable X11 forwarding
        $1 == "X11Forwarding" { print "X11Forwarding no"; next }
        /^#X11Forwarding/ { print "X11Forwarding no"; next }

        # Enable strict mode
        $1 == "StrictModes" { print "StrictModes yes"; next }
        /^#StrictModes/ { print "StrictModes yes"; next }

        # Print unchanged lines
        { print }

        # Add missing settings at the end
        END {
            print "# Added by HARDN-XDR"
            print "Protocol 2"
            print "MaxAuthTries 4"
            print "ClientAliveInterval 300"
            print "ClientAliveCountMax 0"
            print "UsePAM yes"
        }
    ' "${config_file}" > "${config_file}.new" && \
    mv "${config_file}.new" "${config_file}" || status=1

    if [ ${status} -eq 0 ]; then
        HARDN_STATUS "pass" "SSH configuration hardened successfully"
    else
        HARDN_STATUS "error" "Failed to harden SSH configuration"
    fi

    return ${status}
}

# Main SSH hardening function
hardn_ssh_harden() {
    local service_name="" status=0

    if ! hardn_ssh_is_installed; then
        hardn_ssh_install || status=1
    else
        HARDN_STATUS "info" "OpenSSH server is already installed"
    fi

    # Get service name
    service_name=$(hardn_ssh_detect_service) || status=1

    if [ ${status} -eq 0 ]; then
        HARDN_STATUS "info" "Enabling and starting SSH service: ${service_name}"
        systemctl enable "${service_name}" && \
        systemctl start "${service_name}" || status=1

        hardn_ssh_secure_config || status=1

        # Restart service to apply changes
        HARDN_STATUS "info" "Restarting SSH service to apply changes"
        systemctl restart "${service_name}" || status=1

        if [ ${status} -eq 0 ]; then
            HARDN_STATUS "pass" "SSH hardening completed successfully"
            HARDN_STATUS "warning" "Password authentication has been disabled. Ensure you have SSH key-based access."
        fi
    fi

    return ${status}
}
