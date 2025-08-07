#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

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

    return 0
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

# --------- Apply STIG-Compliant Password Policy (Automated) ----------
HARDN_STATUS "info" "Applying STIG-compliant password policy automatically..."

# STIG-recommended secure defaults
minlen=12
ucredit=1
lcredit=1
dcredit=1
ocredit=1

HARDN_STATUS "info" "Password policy settings:"
HARDN_STATUS "info" "• Minimum length: $minlen"
HARDN_STATUS "info" "• Uppercase letters: $ucredit"
HARDN_STATUS "info" "• Lowercase letters: $lcredit"
HARDN_STATUS "info" "• Digits: $dcredit"
HARDN_STATUS "info" "• Special characters: $ocredit"

# --------- Ensure Package Installed ----------
if command -v apt &>/dev/null && ! command -v pwscore &>/dev/null; then
    apt install -y libpam-pwquality
elif command -v dnf &>/dev/null && ! command -v pwscore &>/dev/null; then
    dnf install -y pam_pwquality
elif command -v yum &>/dev/null && ! command -v pwscore &>/dev/null; then
    yum install -y pam_pwquality
fi

# --------- Backup Current PAM File ----------
STAMP=$(date +%Y%m%d%H%M%S)
if ! cp "$PAM_FILE" "${PAM_FILE}.bak-$STAMP"; then
    HARDN_STATUS "error" "Failed to backup PAM file. Aborting password policy changes."
    return 0 2>/dev/null || hardn_module_exit 0
fi
HARDN_STATUS "info" "Backup saved to ${PAM_FILE}.bak-$STAMP"

# Validate backup was created successfully
if [[ ! -f "${PAM_FILE}.bak-$STAMP" ]]; then
    HARDN_STATUS "error" "PAM backup validation failed. Aborting password policy changes."
    return 0 2>/dev/null || hardn_module_exit 0
fi

# --------- Apply Password Policy ----------
if grep -q "pam_pwquality.so" "$PAM_FILE"; then
    sed -i '/pam_pwquality\.so/ s/^.*$/password requisite pam_pwquality.so retry=3 minlen='"$minlen"' ucredit=-'"$ucredit"' lcredit=-'"$lcredit"' dcredit=-'"$dcredit"' ocredit=-'"$ocredit"'/' "$PAM_FILE"
elif grep -q "pam_cracklib.so" "$PAM_FILE"; then
    sed -i '/pam_cracklib\.so/ s/^.*$/password requisite pam_cracklib.so retry=3 minlen='"$minlen"' ucredit=-'"$ucredit"' lcredit=-'"$lcredit"' dcredit=-'"$dcredit"' ocredit=-'"$ocredit"'/' "$PAM_FILE"
else
    echo "password requisite pam_pwquality.so retry=3 minlen=$minlen ucredit=-$ucredit lcredit=-$lcredit dcredit=-$dcredit ocredit=-$ocredit" >> "$PAM_FILE"
    HARDN_STATUS "warning" "Added new line to $PAM_FILE — review manually if needed."
fi

# Validate PAM configuration syntax
if ! pam-config --create 2>/dev/null && ! pamtester login root authenticate 2>/dev/null; then
    # Basic syntax check - ensure the file is readable and has expected content
    if ! grep -q "pam_pwquality.so\|pam_cracklib.so" "$PAM_FILE"; then
        HARDN_STATUS "error" "PAM configuration appears corrupted. Restoring backup."
        cp "${PAM_FILE}.bak-$STAMP" "$PAM_FILE"
        return 0 2>/dev/null || hardn_module_exit 0
    fi
fi

# --------- CLI Interactive Password Reset (Optional and Safe) ----------
# Only perform interactive password reset if explicitly requested and in safe conditions
if [ -t 0 ] && [ -t 1 ] && [ -z "$HARDN_SKIP_PASSWORD_RESET" ] && [ -z "$CI" ]; then
    # Ask user if they want to reset password immediately
    echo ""
    echo "Password policy has been updated. Current user password may need to be changed."
    read -p "Do you want to reset your password now? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        HARDN_STATUS "info" "Starting interactive password reset for current user..."
    
    # Get current username
    CURRENT_USER=$(whoami)
    HARDN_STATUS "info" "Password reset for user: $CURRENT_USER"
    
    # Password validation loop
    while true; do
        echo ""
        echo "Password Requirements:"
        echo "• Minimum length: $minlen characters"
        echo "• Must contain: $ucredit uppercase, $lcredit lowercase, $dcredit digits, $ocredit special characters"
        echo ""
        
        # Read password securely
        read -s -p "Enter new password: " new_password
        echo ""
        read -s -p "Confirm new password: " confirm_password
        echo ""
        
        # Check if passwords match
        if [ "$new_password" != "$confirm_password" ]; then
            echo "!!! Passwords do not match. Please try again."
            continue
        fi
        
        # Validate password against policy
        if validate_password "$new_password" "$minlen" "$ucredit" "$lcredit" "$dcredit" "$ocredit"; then
            echo "Password meets policy requirements."
            
            # Apply the password
            if echo "$CURRENT_USER:$new_password" | chpasswd; then
                HARDN_STATUS "pass" "Password successfully updated for user: $CURRENT_USER"
                echo "Password has been successfully changed!"
                break
            else
                HARDN_STATUS "error" "Failed to update password for user: $CURRENT_USER"
                echo "Failed to update password. Please try again or contact administrator."
            fi
        else
            echo "Password does not meet policy requirements:"
            echo "   Required: ${minlen}+ chars, ${ucredit}+ uppercase, ${lcredit}+ lowercase, ${dcredit}+ digits, ${ocredit}+ special"
            echo "   Please try again."
        fi
    done
    else
        HARDN_STATUS "info" "Password reset skipped. Users can run 'passwd' to update passwords when ready."
    fi
else
    HARDN_STATUS "info" "Non-interactive mode or automated environment: Password policy applied without user interaction."
    HARDN_STATUS "info" "Users can run 'passwd' to update passwords to meet new requirements."
fi

# --------- Final Message ----------
HARDN_STATUS "pass" "STIG-compliant password policy successfully applied."
HARDN_STATUS "info" "Password policy is now active. Users can run 'passwd' to update passwords."

return 0 2>/dev/null || hardn_module_exit 0
