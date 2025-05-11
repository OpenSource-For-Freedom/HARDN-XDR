#!/bin/bash
# STIG Secure Filesystem
printf "\033[1;31m[+] Securing filesystem permissions...\033[0m\n"
chown root:root /etc/passwd /etc/group /etc/gshadow
chmod 644 /etc/passwd
chmod 640 /etc/group
chown root:shadow /etc/shadow /etc/gshadow
chmod 640 /etc/shadow /etc/gshadow

printf "\033[1;31m[+] Configuring audit rules...\033[0m\n"
apt install -y auditd audispd-plugins
tee /etc/audit/rules.d/stig.rules > /dev/null <<EOF
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
# -e 2  # Immutable mode. Uncomment only for production.
EOF
chown root:root /etc/audit/rules.d/*.rules
chmod 600 /etc/audit/rules.d/*.rules
mkdir -p /var/log/audit
chown -R root:root /var/log/audit
chmod 700 /var/log/audit
augenrules --load
systemctl enable auditd || { printf "\033[1;31m[-] Failed to enable auditd.\033[0m\n"; exit 1; }
systemctl start auditd || { printf "\033[1;31m[-] Failed to start auditd.\033[0m\n"; exit 1; }
systemctl restart auditd || { printf "\033[1;31m[-] Failed to restart auditd.\033[0m\n"; exit 1; }
auditctl -e 1 || printf "\033[1;31m[-] Failed to enable auditd.\033[0m\n"
