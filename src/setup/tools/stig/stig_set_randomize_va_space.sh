#!/bin/bash
# STIG Set randomize_va_space
printf "\033[1;31m[+] Setting kernel.randomize_va_space...\033[0m\n"
echo "kernel.randomize_va_space = 2" > /etc/sysctl.d/hardn.conf
sysctl -w kernel.randomize_va_space=2 || printf "\033[1;31m[-] Failed to set randomize_va_space.\033[0m\n"
sysctl --system || printf "\033[1;31m[-] Failed to reload sysctl settings.\033[0m\n"
