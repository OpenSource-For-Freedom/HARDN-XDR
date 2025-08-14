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
# STIG Password Quality Assessment Module
# Purpose: Provide STIG password policy recommendations and guidance
# Mode: WARNING/ASSESSMENT ONLY - Does not apply policies automatically
# Users must manually apply recommendations if desired


# --------- Password Validator --------
validate_password() {
    local pw="$1"
    local minlen="$2" u="$3" l="$4" d="$5" o="$6"

    # Check minimum length
    [[ ${#pw} -lt $minlen ]] && return 1

    # Check uppercase letters (if required)
    if [[ $u -gt 0 ]]; then
        [[ ! "$pw" =~ [A-Z] ]] && return 1
    fi

    # Check lowercase letters (if required)
    if [[ $l -gt 0 ]]; then
        [[ ! "$pw" =~ [a-z] ]] && return 1
    fi

    # Check digits (if required)
    if [[ $d -gt 0 ]]; then
        [[ ! "$pw" =~ [0-9] ]] && return 1
    fi

    # Check special characters (if required)
    if [[ $o -gt 0 ]]; then
        [[ ! "$pw" =~ [^a-zA-Z0-9] ]] && return 1
    fi

    exit 0
}

# --------- Detect PAM file ----------
PAM_FILE=""
if [ -f /etc/pam.d/common-password ]; then
    PAM_FILE="/etc/pam.d/common-password"
elif [ -f /etc/pam.d/system-auth ]; then
    PAM_FILE="/etc/pam.d/system-auth"
else
    HARDN_STATUS "error" "No standard PAM password file found."
    return 0 2>/dev/null || hardn_module_exit 0
fi

# --------- Skip if container ----------
if grep -qa container /proc/1/environ || systemd-detect-virt --quiet --container; then
    HARDN_STATUS "info" "Skipping password policy setup (container environment)."
    return 0 2>/dev/null || hardn_module_exit 0
fi

# --------- STIG Password Policy Recommendations (Warning Mode) ----------
HARDN_STATUS "warning" "Password Policy Assessment Mode - No automatic changes will be applied."

# STIG-recommended secure defaults
minlen=12
ucredit=1
lcredit=1
dcredit=1
ocredit=1

HARDN_STATUS "info" "STIG-recommended password policy settings:"
HARDN_STATUS "info" "• Minimum length: $minlen characters"
HARDN_STATUS "info" "• Uppercase letters: $ucredit required"
HARDN_STATUS "info" "• Lowercase letters: $lcredit required"
HARDN_STATUS "info" "• Digits: $dcredit required"
HARDN_STATUS "info" "• Special characters: $ocredit required"

# --------- Check Current Policy Status ----------
HARDN_STATUS "info" "Checking current password policy configuration..."

# Check if PAM password quality is configured
if grep -q "pam_pwquality.so\|pam_cracklib.so" "$PAM_FILE"; then
    HARDN_STATUS "info" "Password quality module is already configured in $PAM_FILE"
    
    # Show current configuration
    current_config=$(grep -E "pam_pwquality\.so|pam_cracklib\.so" "$PAM_FILE" 2>/dev/null || echo "Configuration not found")
    HARDN_STATUS "info" "Current configuration: $current_config"
else
    HARDN_STATUS "warning" "No password quality module found in $PAM_FILE"
    HARDN_STATUS "warning" "System may not enforce strong password requirements"
fi

# --------- Password Policy Recommendations ----------
echo ""
echo "================================================================"
echo "        STIG PASSWORD POLICY RECOMMENDATIONS"
echo "================================================================"
echo ""
echo "CURRENT STATUS: Password policy is in ASSESSMENT MODE"
echo "No automatic changes have been applied to your system."
echo ""
echo "STIG REQUIREMENTS:"
echo "• Minimum password length: $minlen characters"
echo "• Must contain at least $ucredit uppercase letter(s)"
echo "• Must contain at least $lcredit lowercase letter(s)"  
echo "• Must contain at least $dcredit digit(s)"
echo "• Must contain at least $ocredit special character(s)"
echo ""
echo "TO MANUALLY APPLY STIG PASSWORD POLICY:"
echo "1. Install password quality package:"
echo "   sudo apt install libpam-pwquality  # (Debian/Ubuntu)"
echo "   sudo dnf install pam_pwquality     # (Fedora/CentOS)"
echo ""
echo "2. Edit $PAM_FILE and add:"
echo "   password requisite pam_pwquality.so retry=3 minlen=$minlen ucredit=-$ucredit lcredit=-$lcredit dcredit=-$dcredit ocredit=-$ocredit"
echo ""
echo "3. Test the configuration:"
echo "   sudo passwd \$USER"
echo ""
echo "================================================================"
echo ""

# --------- Check if pwquality package is available ----------
if command -v apt &>/dev/null; then
    if ! command -v pwscore &>/dev/null; then
        HARDN_STATUS "info" "Password quality tools not installed."
        HARDN_STATUS "info" "To install: sudo apt install libpam-pwquality"
    else
        HARDN_STATUS "info" "Password quality tools are available."
    fi
elif command -v dnf &>/dev/null; then
    if ! command -v pwscore &>/dev/null; then
        HARDN_STATUS "info" "Password quality tools not installed."
        HARDN_STATUS "info" "To install: sudo dnf install pam_pwquality"
    else
        HARDN_STATUS "info" "Password quality tools are available."
    fi
elif command -v yum &>/dev/null; then
    if ! command -v pwscore &>/dev/null; then
        HARDN_STATUS "info" "Password quality tools not installed."
        HARDN_STATUS "info" "To install: sudo yum install pam_pwquality"
    else
        HARDN_STATUS "info" "Password quality tools are available."
    fi
fi

# --------- CLI Interactive Password Reset Help (Optional and Safe) ----------
# Provide helpful guidance for password changes without forcing policy
if [ -t 0 ] && [ -t 1 ] && [ -z "$HARDN_SKIP_PASSWORD_HELP" ] && [ -z "$CI" ]; then
    echo ""
    echo "================================================================"
    echo "        INTERACTIVE PASSWORD CHANGE ASSISTANCE"
    echo "================================================================"
    echo ""
    echo "STIG password requirements recommend the following:"
    echo "• Minimum length: $minlen characters"
    echo "• Must contain: $ucredit uppercase, $lcredit lowercase, $dcredit digits, $ocredit special characters"
    echo ""
    read -p "Would you like to change your password now to meet STIG requirements? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        HARDN_STATUS "info" "Starting interactive password guidance for current user..."
        
        # Get current username
        CURRENT_USER=$(whoami)
        HARDN_STATUS "info" "Password change assistance for user: $CURRENT_USER"
        
        echo ""
        echo "PASSWORD REQUIREMENTS GUIDE:"
        echo "• Minimum length: $minlen characters"
        echo "• Must contain: $ucredit uppercase letter(s)"
        echo "• Must contain: $lcredit lowercase letter(s)"
        echo "• Must contain: $dcredit digit(s)"
        echo "• Must contain: $ocredit special character(s)"
        echo ""
        echo "EXAMPLES OF STRONG PASSWORDS:"
        echo "• MyP@ssw0rd2024! (15 chars, mixed case, digits, symbols)"
        echo "• Secure#Login99 (15 chars, mixed case, digits, symbols)"
        echo "• Admin2024@Safe (15 chars, mixed case, digits, symbols)"
        echo ""
        echo "The system will now run the standard 'passwd' command."
        echo "Enter a password that meets the above requirements."
        echo ""
        read -p "Press Enter to continue with password change, or Ctrl+C to cancel..."
        
        # Use the standard passwd command for safety
        if passwd; then
            HARDN_STATUS "pass" "Password change completed for user: $CURRENT_USER"
            echo ""
            echo "Password successfully changed!"
            echo "Your new password should now meet STIG security requirements."
        else
            HARDN_STATUS "warning" "Password change was cancelled or failed for user: $CURRENT_USER"
            echo ""
            echo "Password change was not completed."
            echo "You can run 'passwd' manually anytime to change your password."
        fi
    else
        HARDN_STATUS "info" "Password change skipped. You can run 'passwd' anytime to update your password."
        echo ""
        echo "To change your password later, run: passwd"
        echo "Remember to follow STIG requirements when choosing a new password."
    fi
else
    HARDN_STATUS "info" "Non-interactive mode: Password guidance provided in assessment output above."
    HARDN_STATUS "info" "Users can run 'passwd' anytime to update passwords to meet STIG requirements."
fi

# --------- Final Message ----------
HARDN_STATUS "pass" "STIG password policy assessment completed."
HARDN_STATUS "info" "Assessment mode: No automatic policy changes were applied."
HARDN_STATUS "info" "Review the recommendations above and apply manually if desired."
HARDN_STATUS "info" "Users can run 'passwd' to change passwords according to STIG requirements."

return 0 2>/dev/null || hardn_module_exit 0
set -e
