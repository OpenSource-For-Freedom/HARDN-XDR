#!/bin/bash

# author: Christopher Bingham

check_root () {
        [ "$(id -u)" -ne 0 ] && echo "Please run this script as root." && exit 1
}

update_system() {
        printf "\033[1;31m[+] Updating system...\033[0m\n"
        apt update && apt upgrade -y
}

# Git clone the repo, then cd into the repo and run the script hardn-main.sh
run() {
        cd HARDN-XDR/src/setup && chmod +x hardn-main.sh && sudo ./hardn-main.sh
}

main() {
        check_root
        update_system
        run
}

main
