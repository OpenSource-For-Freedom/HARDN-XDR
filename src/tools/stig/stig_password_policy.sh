#!/bin/bash
# Configures password policy for STIG compliance
apt install -y libpam-pwquality
sed -i 's/^# minlen.*/minlen = 14/' /etc/security/pwquality.conf
sed -i 's/^# dcredit.*/dcredit = -1/' /etc/security/pwquality.conf
sed -i 's/^# ucredit.*/ucredit = -1/' /etc/security/pwquality.conf
sed -i 's/^# ocredit.*/ocredit = -1/' /etc/security/pwquality.conf
sed -i 's/^# lcredit.*/lcredit = -1/' /etc/security/pwquality.conf
sed -i '/pam_pwquality.so/ s/$/ retry=3 enforce_for_root/' /etc/pam.d/common-password || true