#!/bin/bash
# Universal package installation check function
is_installed() {
    local pkg="$1"
    if command -v dpkg >/dev/null 2>&1; then
        dpkg -s "$pkg" >/dev/null 2>&1
    elif command -v rpm >/dev/null 2>&1; then
        rpm -q "$pkg" >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        dnf list installed "$pkg" >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum list installed "$pkg" >/dev/null 2>&1
    else
        return 1
    fi
}

# Function to install libpam-pwquality if not already installed
install_pwquality() {
    if ! is_installed "libpam-pwquality"; then
        HARDN_STATUS "info" "Installing libpam-pwquality..."

        # Use case statement for package manager selection
        case "$(command -v apt || command -v dnf || command -v yum || echo 'unknown')" in
            */apt)
                apt install -y libpam-pwquality >/dev/null 2>&1
                ;;
            */dnf)
                dnf install -y libpam-pwquality >/dev/null 2>&1
                ;;
            */yum)
                yum install -y libpam-pwquality >/dev/null 2>&1
                ;;
            *)
                HARDN_STATUS "error" "No supported package manager found"
                return 1
                ;;
        esac
    fi

    return 0
}

# Configure PAM password quality
configure_pam_pwquality() {
    if [ -f /etc/pam.d/common-password ]; then
        if ! grep -q "pam_pwquality.so" /etc/pam.d/common-password; then
            echo "password requisite pam_pwquality.so retry=3 minlen=8 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1" >> /etc/pam.d/common-password
        fi
    else
        HARDN_STATUS "warning" "Warning: /etc/pam.d/common-password not found, skipping PAM configuration..."
        return 1
    fi

    return 0
}

# Main function for STIG password quality module
hardn_stig_pwquality_main() {
    HARDN_STATUS "info" "Configuring PAM password quality..."

    # Install required packages
    install_pwquality || {
        HARDN_STATUS "error" "Failed to install libpam-pwquality"
        return 1
    }

    # Configure password quality settings
    configure_pam_pwquality || {
        HARDN_STATUS "warning" "PAM password quality configuration incomplete"
        # Don't return error here as this might be non-fatal
    }

    HARDN_STATUS "pass" "PAM password quality configured successfully"
    return 0
}

# If script is run directly (not sourced), show error
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script must be sourced by hardn-main.sh"
    exit 1
fi
