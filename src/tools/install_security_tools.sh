#!/bin/bash
# Installs required system security tools
apt install -y ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums \
    libpam-pwquality libvirt-daemon-system libvirt-clients qemu-system-x86 openssh-server openssh-client rkhunter