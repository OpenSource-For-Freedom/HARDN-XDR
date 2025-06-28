########################### UFW
HARDN_STATUS "info" "UFW Setup"
apt install ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw logging medium
ufw --force enable
systemctl enable ufw
