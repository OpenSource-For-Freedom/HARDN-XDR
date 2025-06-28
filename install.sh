#!/bin/bash

# Author: Christopher Bingham

check_root () {
        [ "$(id -u)" -ne 0 ] && echo "Please run this script as root." && exit 1
}

update_system() {
        printf "\033[1;31m[+] Updating system...\033[0m\n"
        apt update && apt upgrade -y
}

# Git clone the repo, cd into it, and run the script hardn-main.sh
retrieve_and_run() {
        git clone https://github.com/OpenSource-For-Freedom/HARDN-XDR
        cd HARDN-XDR/src/setup &&  chmod +x hardn-main.sh && sudo ./hardn-main.sh
}


main() {
        check_root
        retrieve_and_run
}

main
