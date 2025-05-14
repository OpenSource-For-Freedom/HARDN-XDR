#!/bin/bash

enable_fail2ban() {
    printf "\033[1;31m[+] Installing and enabling Fail2Ban...\033[0m\n"
    apt update
    apt install -y fail2ban
    systemctl enable --now fail2ban
    printf "\033[1;32m[+] Fail2Ban installed and enabled successfully.\033[0m\n"

    printf "\033[1;31m[+] Configuring Fail2Ban for SSH...\033[0m\n"
    cat << EOF > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
EOF

    systemctl restart fail2ban
    printf "\033[1;32m[+] Fail2Ban configured and restarted successfully.\033[0m\n"
}


enable_apparmor() {
    printf "\033[1;31m[+] Installing and enabling AppArmor…\033[0m\n"
    apt install -y apparmor apparmor-utils apparmor-profiles || {
        printf "\033[1;31m[-] Failed to install AppArmor.\033[0m\n"
        return 1
    }

  
    systemctl restart apparmor || {
        printf "\033[1;31m[-] Failed to restart AppArmor service.\033[0m\n"
        return 1
    }

    systemctl enable --now apparmor || {
        printf "\033[1;31m[-] Failed to enable AppArmor service.\033[0m\n"
        return 1
    }

    printf "\033[1;32m[+] AppArmor successfully installed and reloaded.\033[0m\n"
}

main(){
    
    enable_fail2ban
}