#!/bin/bash
# STIG Configure Firewall
printf "\033[1;31m[+] Configuring UFW...\033[0m\n"
if ! command -v ufw > /dev/null 2>&1; then
    printf "\033[1;31m[-] UFW is not installed. Installing UFW...\033[0m\n"
    apt install -y ufw || { printf "\033[1;31m[-] Failed to install UFW.\033[0m\n"; exit 1; }
fi
printf "\033[1;31m[+] Resetting UFW to default settings...\033[0m\n"
ufw --force reset || { printf "\033[1;31m[-] Failed to reset UFW.\033[0m\n"; exit 1; }
printf "\033[1;31m[+] Setting UFW default policies...\033[0m\n"
ufw default deny incoming
ufw default allow outgoing
printf "\033[1;31m[+] Allowing outbound HTTP and HTTPS traffic...\033[0m\n"
ufw allow out 80/tcp
ufw allow out 443/tcp
printf "\033[1;31m[+] Allowing traffic for Debian updates and app dependencies...\033[0m\n"
ufw allow out 53/udp
ufw allow out 53/tcp
ufw allow out 123/udp
ufw allow out to archive.debian.org port 80 proto tcp
ufw allow out to security.debian.org port 443 proto tcp
printf "\033[1;31m[+] Enabling and reloading UFW...\033[0m\n"
echo "y" | ufw enable || { printf "\033[1;31m[-] Failed to enable UFW.\033[0m\n"; exit 1; }
ufw reload || { printf "\033[1;31m[-] Failed to reload UFW.\033[0m\n"; exit 1; }
printf "\033[1;32m[+] UFW configuration completed successfully.\033[0m\n"
