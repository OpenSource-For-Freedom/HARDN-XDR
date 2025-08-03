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

# --------- Skip if no TTY or container ----------
if grep -qa container /proc/1/environ || systemd-detect-virt --quiet --container || ! [ -t 0 ]; then
    HARDN_STATUS "info" "Skipping password policy setup (container or non-interactive)."
    return 0 2>/dev/null || hardn_module_exit 0
fi

# --------- Check whiptail ----------
if ! command -v whiptail &>/dev/null; then
    HARDN_STATUS "warning" "whiptail not found. Skipping password policy wizard."
    return 0 2>/dev/null || hardn_module_exit 0
fi

# --------- Intro Message ----------
whiptail --title "Password Policy Setup" --msgbox \
"This application will configure password strength rules.\n\n\
Be careful: improper settings may lock out users.\n\
After applying, you should run 'passwd' to verify compliance." 12 70

# --------- Prompt User for Policy Values ----------
minlen=$(whiptail --title "Minimum Length" --inputbox "Minimum password length (e.g. 12):" 10 60 12 3>&1 1>&2 2>&3)
ucredit=$(whiptail --title "Uppercase Letters" --inputbox "Minimum uppercase letters (e.g. 1):" 10 60 1 3>&1 1>&2 2>&3)
lcredit=$(whiptail --title "Lowercase Letters" --inputbox "Minimum lowercase letters (e.g. 1):" 10 60 1 3>&1 1>&2 2>&3)
dcredit=$(whiptail --title "Digits" --inputbox "Minimum digits (e.g. 1):" 10 60 1 3>&1 1>&2 2>&3)
ocredit=$(whiptail --title "Special Characters" --inputbox "Minimum special characters (e.g. 1):" 10 60 1 3>&1 1>&2 2>&3)

# --------- Prompt for a Test Password ----------
while true; do
    user_pw=$(whiptail --title "Test Password" --passwordbox \
"Enter a sample password to ensure it meets your policy before continuing.\n\
You can change this later, this is just to validate the policy." 12 70 3>&1 1>&2 2>&3)

    if validate_password "$user_pw" "$minlen" "$ucredit" "$lcredit" "$dcredit" "$ocredit"; then
        break
    else
        whiptail --title "Password Failed" --msgbox \
"The password you entered does not meet the requirements.\n\n\
Required:\n\
• Length: $minlen\n• Uppercase: $ucredit\n• Lowercase: $lcredit\n\
• Digits: $dcredit\n• Special Chars: $ocredit" 15 70
    fi
done

# --------- Confirm Policy Summary ----------
if ! whiptail --title "Confirm Policy and Test Result" --yesno \
"The sample password meets your policy.\n\n\
The following password policy will be applied to $PAM_FILE:\n\
• Minimum length: $minlen\n• Uppercase letters: $ucredit\n• Lowercase letters: $lcredit\n\
• Digits: $dcredit\n• Special characters: $ocredit\n\n\
Continue?" 18 70; then
    HARDN_STATUS "info" "User cancelled password policy setup."
    return 0 2>/dev/null || hardn_module_exit 0
fi

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
cp "$PAM_FILE" "${PAM_FILE}.bak-$STAMP"
HARDN_STATUS "info" "Backup saved to ${PAM_FILE}.bak-$STAMP"

# --------- Apply Password Policy ----------
if grep -q "pam_pwquality.so" "$PAM_FILE"; then
    sed -i '/pam_pwquality\.so/ s/^.*$/password requisite pam_pwquality.so retry=3 minlen='"$minlen"' ucredit=-'"$ucredit"' lcredit=-'"$lcredit"' dcredit=-'"$dcredit"' ocredit=-'"$ocredit"'/' "$PAM_FILE"
elif grep -q "pam_cracklib.so" "$PAM_FILE"; then
    sed -i '/pam_cracklib\.so/ s/^.*$/password requisite pam_cracklib.so retry=3 minlen='"$minlen"' ucredit=-'"$ucredit"' lcredit=-'"$lcredit"' dcredit=-'"$dcredit"' ocredit=-'"$ocredit"'/' "$PAM_FILE"
else
    echo "password requisite pam_pwquality.so retry=3 minlen=$minlen ucredit=-$ucredit lcredit=-$lcredit dcredit=-$dcredit ocredit=-$ocredit" >> "$PAM_FILE"
    HARDN_STATUS "warning" "Added new line to $PAM_FILE — review manually if needed."
fi

# --------- Final Message ----------
HARDN_STATUS "pass" "Password policy successfully applied."
whiptail --title "Reminder" --msgbox \
"The policy is now active.\nRun 'passwd' to change your password and test compliance." 10 60

return 0 2>/dev/null || hardn_module_exit 0
