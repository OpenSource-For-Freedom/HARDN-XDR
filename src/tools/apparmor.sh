#!/bin/bash


enable_apparmor() {
    printf "\033[1;31m[+] Installing and enabling AppArmor…\033[0m\n"
    apt install -y apparmor apparmor-utils apparmor-profiles || {
        printf "\033[1;31m[-] Failed to install AppArmor.\033[0m\n"
        return 1
    }

  
    systemctl restart apparmor || {
        printf "\033[1;31m[-] Failed to restart AppArmor service.\033[0m\n"
        return 1
    }

    systemctl enable --now apparmor || {
        printf "\033[1;31m[-] Failed to enable AppArmor service.\033[0m\n"
        return 1
    }

    printf "\033[1;32m[+] AppArmor successfully installed and reloaded.\033[0m\n"
}

main(){

enable_apparmor

}