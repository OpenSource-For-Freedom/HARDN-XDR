#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../hardn-common.sh" 2>/dev/null || {
    # Fallback if common file not found
    HARDN_STATUS() {
        local status="$1"
        local message="$2"
        case "$status" in
            "pass")    echo -e "\033[1;32m[PASS]\033[0m $message" ;;
            "warning") echo -e "\033[1;33m[WARNING]\033[0m $message" ;;
            "error")   echo -e "\033[1;31m[ERROR]\033[0m $message" ;;
            "info")    echo -e "\033[1;34m[INFO]\033[0m $message" ;;
            *)         echo -e "\033[1;37m[UNKNOWN]\033[0m $message" ;;
        esac
    }
}

HARDN_STATUS "error" "Restricting compiler access to root only (HRDN-7222)..."

local compilers
compilers="/usr/bin/gcc /usr/bin/g++ /usr/bin/make /usr/bin/cc /usr/bin/c++ /usr/bin/as /usr/bin/ld"
for bin in $compilers; do
	if [[ -f "$bin" ]]; then
		chmod 755 "$bin"
		chown root:root "$bin"
		HARDN_STATUS "pass" "Set $bin to 755 root:root (default for compilers)."
	fi
done

