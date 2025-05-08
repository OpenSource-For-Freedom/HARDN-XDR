#!/bin/bash
# Secures filesystem permissions for STIG compliance
chown root:root /etc/passwd /etc/group /etc/gshadow
chmod 644 /etc/passwd /etc/group
chown root:shadow /etc/shadow /etc/gshadow
chmod 640 /etc/shadow /etc/gshadow

# Configures audit rules
apt install -y auditd audispd-plugins
tee /etc/audit/rules.d/stig.rules > /dev/null <<EOF
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
-e 2
EOF

chown root:root /etc/audit/rules.d/*.rules
chmod 600 /etc/audit/rules.d/*.rules
mkdir -p /var/log/audit
chown -R root:root /var/log/audit
chmod 700 /var/log/audit

augenrules --load
systemctl enable auditd
systemctl start auditd
systemctl restart auditd
auditctl -e 1