#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../hardn-common.sh" 2>/dev/null || {
    # Fallback if common file not found
    HARDN_STATUS() {
        local status="$1"
        local message="$2"
        case "$status" in
            "pass")    echo -e "\033[1;32m[PASS]\033[0m $message" ;;
            "warning") echo -e "\033[1;33m[WARNING]\033[0m $message" ;;
            "error")   echo -e "\033[1;31m[ERROR]\033[0m $message" ;;
            "info")    echo -e "\033[1;34m[INFO]\033[0m $message" ;;
            *)         echo -e "\033[1;37m[UNKNOWN]\033[0m $message" ;;
        esac
    }
}

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
# Display a warning and guidance about password requirements
if command -v whiptail >/dev/null 2>&1; then
    hardn_msgbox \
"This script is about to configure system-wide password policies based on STIG requirements.

The new password requirements will be:
- Minimum 8 characters
- At least 1 uppercase letter
- At least 1 lowercase letter
- At least 1 digit
- At least 1 special character

IMPORTANT:
After this script finishes, you MUST change your password using the 'passwd' command.

Please ensure you create and save a new password that meets these requirements before you log out to avoid being locked out.

Press OK to continue." 20 78
else
    HARDN_STATUS "warning" "whiptail not found, skipping password policy warning."
    HARDN_STATUS "warning" "Please be aware that password policies will be enforced."
fi


HARDN_STATUS "info" "PAM password quality configuration - DISABLED FOR TESTING"

# COMMENTED OUT: Restrictive password policies causing login issues
if [ -f /etc/pam.d/common-password ]; then
	# DISABLED: if ! grep -q "pam_pwquality.so" /etc/pam.d/common-password; then
	# DISABLED: 	echo "password requisite pam_pwquality.so retry=3 minlen=8 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1" >> /etc/pam.d/common-password
	# DISABLED: fi
	echo "WARNING: PAM password quality rules are DISABLED for testing"
	echo "This prevents potential password lockout issues during testing"
else
	HARDN_STATUS "warning" "Warning: /etc/pam.d/common-password not found, skipping PAM configuration..."
fi
