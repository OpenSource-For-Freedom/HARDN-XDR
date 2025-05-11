#!/bin/bash
set -e
echo "installing lynis"
printf "\033[1;31m[+] Installing Lynis...\033[0m\n"
apt install -y lynis
