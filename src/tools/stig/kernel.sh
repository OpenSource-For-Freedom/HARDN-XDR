#!/bin/bash


stig_kernel_setup() {
    printf "\033[1;31m[+] Setting up STIG-compliant kernel parameters...\033[0m\n"
    tee /etc/sysctl.d/stig-kernel.conf > /dev/null <<EOF
kernel.randomize_va_space = 2
kernel.exec-shield = 1
kernel.panic_on_oops = 1
kernel.panic = 10
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.forwarding = 0
net.ipv4.conf.default.forwarding = 0
EOF

    
    echo "kernel.modules_disabled = 1" >> /etc/sysctl.d/stig-kernel.conf
    echo "kernel.kexec_load_disabled = 1" >> /etc/sysctl.d/stig-kernel.conf

    
    sysctl --system || printf "\033[1;31m[-] Failed to reload sysctl settings.\033[0m\n"

    
    printf "\033[1;31m[+] Blacklisting unnecessary kernel modules...\033[0m\n"
    tee /etc/modprobe.d/hardn-blacklist.conf > /dev/null <<EOF
install cramfs /bin/false
install freevxfs /bin/false
install jffs2 /bin/false
install hfs /bin/false
install hfsplus /bin/false
install squashfs /bin/false
install udf /bin/false
install usb-storage /bin/false
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false
EOF

    update-initramfs -u || printf "\033[1;31m[-] Failed to update initramfs.\033[0m\n"
}


main(){


stig_kernel_setup

}