#!/bin/bash
set -e

printf "\033[1;31m[+] Installing AppArmor profiles...\033[0m\n"
apt install -y apparmor-profiles
