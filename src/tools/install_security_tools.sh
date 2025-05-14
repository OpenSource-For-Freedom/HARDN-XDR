#!/bin/bash
<<<<<<< HEAD
# Installs required system security tools
apt install -y ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums \
    libpam-pwquality libvirt-daemon-system libvirt-clients qemu-system-x86 openssh-server openssh-client rkhunter
=======

install_security_tools() {
    printf "\033[1;31m[+] Installing required system security tools...\033[0m\n"
    apt install -y ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums \
        libpam-pwquality libvirt-daemon-system libvirt-clients qemu-system-x86 openssh-server openssh-client rkhunter 
}

main(){

install_security_tools

}

main
>>>>>>> 8476171ece892a945fa8f35384c0e87d9c361742
