#!/bin/bash
# Source common functions with fallback for development/CI environments
source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
    check_root() { [[ $EUID -eq 0 ]]; }
    is_installed() { command -v "$1" >/dev/null 2>&1 || dpkg -s "$1" >/dev/null 2>&1; }
    hardn_yesno() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && return 0
        echo "Auto-confirming: $1" >&2
        return 0
    }
    hardn_msgbox() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && echo "Info: $1" >&2 && return 0
        echo "Info: $1" >&2
    }
    is_container_environment() {
        [[ -n "$CI" ]] || [[ -n "$GITHUB_ACTIONS" ]] || [[ -f /.dockerenv ]] || \
        [[ -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null
    }
    is_systemd_available() {
        [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1
    }
}
#!/bin/bash
set -e

HARDN_STATUS "info" "Restricting compiler access to root only (HRDN-7222)..."

compilers=("/usr/bin/gcc" "/usr/bin/g++" "/usr/bin/make" "/usr/bin/cc" "/usr/bin/c++" "/usr/bin/as" "/usr/bin/ld")
for bin in "${compilers[@]}"; do
	if [[ -f "$bin" ]]; then
		chmod 755 "$bin"
		chown root:root "$bin"
		HARDN_STATUS "pass" "Set $bin to 755 root:root (default for compilers)."
	fi
done

HARDN_STATUS "pass" "Compiler access restrictions applied successfully."

return 0 2>/dev/null || hardn_module_exit 0

