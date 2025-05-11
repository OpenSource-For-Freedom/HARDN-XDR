#!/bin/bash
# This script installs and enables AppArmor on a Debian-based system.
    printf "\033[1;31m[+] Installing and enabling AppArmor…\033[0m\n"
    apt install -y apparmor apparmor-utils apparmor-profiles || {
        printf "\033[1;31m[-] Failed to install AppArmor.\033[0m\n"
        return 1
    }

    systemctl enable --now apparmor || {
        printf "\033[1;31m[-] Failed to enable AppArmor service.\033[0m\n"
        return 1
    }

    aa-complain /etc/apparmor.d/* || {
        printf "\033[1;31m[-] Failed to set profiles to complain mode. Continuing...\033[0m\n"
    }

    printf "\033[1;32m[+] AppArmor installed. Profiles are in complain mode for testing.\033[0m\n"
    printf "\033[1;33m[!] Review profile behavior before switching to enforce mode.\033[0m\n"
