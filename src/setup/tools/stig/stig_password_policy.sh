#!/bin/bash
# STIG Password Policy
sed -i 's/^#\? *minlen *=.*/minlen = 14/' /etc/security/pwquality.conf
sed -i 's/^#\? *dcredit *=.*/dcredit = -1/' /etc/security/pwquality.conf
sed -i 's/^#\? *ucredit *=.*/ucredit = -1/' /etc/security/pwquality.conf
sed -i 's/^#\? *ocredit *=.*/ocredit = -1/' /etc/security/pwquality.conf
sed -i 's/^#\? *lcredit *=.*/lcredit = -1/' /etc/security/pwquality.conf

if command -v pam-auth-update > /dev/null; then
    pam-auth-update --package
    echo "[+] pam_pwquality profile activated via pam-auth-update"
else
    echo "[!] pam-auth-update not found. Install 'libpam-runtime' to manage PAM profiles safely."
fi
