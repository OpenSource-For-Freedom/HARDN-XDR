#!/bin/bash
set -e

printf "\033[1;31m[+] Installing rkhunter...\033[0m\n"
    if ! apt install -y rkhunter; then
        return 0
    fi

   
    sudo chown -R root:root /var/lib/rkhunter
    sudo chmod -R 755 /var/lib/rkhunter

   
    sed -i 's|^#*MIRRORS_MODE=.*|MIRRORS_MODE=1|' /etc/rkhunter.conf
    sed -i 's|^#*UPDATE_MIRRORS=.*|UPDATE_MIRRORS=1|' /etc/rkhunter.conf
    sed -i 's|^WEB_CMD=.*|#WEB_CMD=|' /etc/rkhunter.conf

    
    if ! rkhunter --update; then
        printf "\033[1;33m[!] rkhunter update failed. Check your network connection or proxy settings.\033[0m\n"
    fi

    rkhunter --propupd
    printf "\033[1;32m[+] rkhunter installed and updated.\033[0m\n"