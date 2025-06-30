#!/bin/bash
# HARDN-XDR installed entry point
# Author: SIG Team
check_root () {
    [ "$(id -u)" -ne 0 ] && echo "Please run this script as root." && exit 1
}
update_system() {
    printf "\033[1;31m[+] Updating system...\033[0m\n"
    apt update && apt upgrade -y
}
run_hardn() {
    # uncomment to run binary install packaging 
    MAIN_SCRIPT="/usr/share/hardn-xdr/src/setup/hardn-main.sh"
        
    if [ -f "$MAIN_SCRIPT" ]; then
        chmod +x "$MAIN_SCRIPT"
        "$MAIN_SCRIPT"
    else
        echo "Main script not found at $MAIN_SCRIPT"
        exit 1
    fi
}
main() {
    check_root
    update_system
    run_hardn
}
main
