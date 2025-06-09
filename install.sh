#!/bin/bash

# Christopher Bingham
# This installation script is responsible for installing and setting up HARDN-XDR
check_root () {
        [ "$(id -u)" -ne 0 ] && echo "Please run this script as root." && exit 1
}

update_system() {
        printf "\033[1;31m[+] Updating system...\033[0m\n"
        apt update && apt upgrade -y
}

# 1. Check if git is installed.
# 2. If git is not currently installed,
# 3.then install it.
check_git() {
        printf "\033[1;31m[+] Checking if git is installed, and installing it if not..\033[0m\n"
        if [ -x "$(command -v git)" ]; then
          printf "\033[1;32m[+] Git is installed.\033[0m\n"
        else
           sudo apt install git -y
           printf "\033[1;32m[+] Git is now installed.\033[0m\n""]"
         fi
}

# Git clone the repo, then cd into the repo and run the script hardn-main.sh
retrieve_repo() {
        # Tim's repository git clone https://github.com/OpenSource-For-Freedom/HARDN-XDR.git
        # Christopher's repository git clone https://github.com/ChristopherBingham/HARDN-XDR.git'
        git clone https://github.com/LinuxUser255/HARDN-XDR.git
        # then cd into HARDN-XDR/src/setup and run the script hardn-main.sh
        cd HARDN-XDR/src/setup &&  chmod +x hardn-main.sh && sudo ./hardn-main.sh
}

main() {
        check_root
        update_system
        check_git
        retrieve_repo
}

main
