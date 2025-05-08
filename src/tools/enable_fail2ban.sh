#!/bin/bash
# Enables and configures Fail2Ban
apt update
apt install -y fail2ban
systemctl enable --now fail2ban

cat << EOF > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
EOF

systemctl restart fail2ban