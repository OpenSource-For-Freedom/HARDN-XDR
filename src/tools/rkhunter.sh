#!/bin/bash


enable_rkhunter(){
    printf "\033[1;31m[+] Installing rkhunter...\033[0m\n"
    if ! apt install -y rkhunter; then
        printf "\033[1;33m[-] rkhunter install failed, skipping rkhunter setup.\033[0m\n"
        return 0
    fi

   
    sed -i 's|^WEB_CMD=.*|#WEB_CMD=|' /etc/rkhunter.conf

    
    sed -i 's|^MIRRORS_MODE=.*|MIRRORS_MODE=1|' /etc/rkhunter.conf

    
    chown -R root:root /var/lib/rkhunter
    chmod -R 755 /var/lib/rkhunter

    
    if ! rkhunter --update; then
        printf "\033[1;33m[-] rkhunter update failed, skipping propupd.\033[0m\n"
        return 0
    fi

    rkhunter --propupd
    printf "\033[1;32m[+] rkhunter installed and updated.\033[0m\n"
}

main(){

enable_rkhunter

}