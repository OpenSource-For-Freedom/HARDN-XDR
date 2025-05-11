#!/bin/bash
set -e

 printf "\033[1;31m[+] Installing AIDE and initializing database…\033[0m\n"
    apt install -y aide aide-common || {
        printf "\033[1;31m[-] Failed to install AIDE.\033[0m\n"
        return 1
    }
    aideinit || {
        printf "\033[1;31m[-] Failed to initialize AIDE database.\033[0m\n"
        return 1
    }
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db || {
        printf "\033[1;31m[-] Failed to replace AIDE database.\033[0m\n"
        return 1
    }

    printf "\033[1;32m[+] AIDE successfully installed and configured.\033[0m\n"