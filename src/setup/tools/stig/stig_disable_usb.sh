#!/bin/bash
# STIG Disable USB
echo "install usb-storage /bin/false" > /etc/modprobe.d/hardn-blacklist.conf
update-initramfs -u || printf "\033[1;31m[-] Failed to update initramfs.\033[0m\n"
