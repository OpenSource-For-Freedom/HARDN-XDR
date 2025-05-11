#!/bin/bash
# GRUB Security
cp /boot/grub/grub.cfg /boot/grub/grub.cfg.bak
printf "\033[1;31m[+] Configuring GRUB security settings...\033[0m\n"
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash security=1 /' /etc/default/grub
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub || echo "GRUB_TIMEOUT=5" >> /etc/default/grub
update-grub || printf "\033[1;31m[-] Failed to update GRUB.\033[0m\n"
chmod 600 /boot/grub/grub.cfg
chown root:root /boot/grub/grub.cfg
