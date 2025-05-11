#!/bin/bash
set -e

printf "\033[1;31m[+] Installing UFW...\033[0m\n"
apt install -y ufw

printf "\033[1;32m[+] Setting up UFW firewall rules...\033[0m\n"

ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 53
ufw allow 123
ufw allow out 80/tcp
ufw --force enable
ufw reload
ufw status verbose
ufw logging on
printf "\033[1;32m[+] UFW installation and configuration complete.\033[0m\n"
