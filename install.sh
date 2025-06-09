#!/bin/bash

# Christopher Bingham
# This installation script is responsible for installing and setting up the HARDN-XDR platform.
check_root () {
        [ "$(id -u)" -ne 0 ] && echo "Please run this script as root." && exit 1
}

update_system() {
        printf "\033[1;31m[+] Updating system...\033[0m\n"
        sudo apt update && sudo apt upgrade -y
}

# Check if git is installed, if not, then install it.
check_git() {
        if ! command -v git &> /dev/null; then
        printf "\033[1;31m[+] git is not installed. Please install git before proceeding.\033[0m\n"
        else
        sudo apt install git -y
        fi
}

# Git clone the repo
retrieve_repo() {
        git clone https://github.com/OpenSource-For-Freedom/HARDN-XDR.git
        # then cd into HARDN-XDR/src/setup and run the script hardn-main.sh
        cd HARDN-XDR/src/setup || exit 1
        sudo ./hardn-main.sh
}

main() {
        check_root
        update_system
        check_git
        retrieve_repo
}

main
