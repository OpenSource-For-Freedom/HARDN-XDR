#!/bin/bash
# Firmware Update
printf "\033[1;31m[+] Checking for firmware updates...\033[0m\n"
apt install -y fwupd
fwupdmgr refresh || printf "\033[1;31m[-] Failed to refresh firmware metadata.\033[0m\n"
fwupdmgr get-updates || printf "\033[1;31m[-] Failed to check for firmware updates.\033[0m\n"
if fwupdmgr update; then
    printf "\033[1;32m[+] Firmware updates applied successfully.\033[0m\n"
else
    printf "\033[1;33m[+] No firmware updates available or update process skipped.\033[0m\n"
fi
apt update -y
