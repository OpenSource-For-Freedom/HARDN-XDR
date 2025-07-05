#!/usr/bin/env bash

set -euo pipefail

PREFIX=/usr/lib/hardn-xdr
MAIN_SCRIPT="$PREFIX/src/setup/hardn-main.sh"
WRAPPER=/usr/bin/hardn-xdr
SKIP_WHIPTAIL=false

# Parse command-line arguments
for arg in "$@"; do
    case "$arg" in
        --no-whiptail)
            SKIP_WHIPTAIL=true
            ;;
    esac
done

check_root() {
    [ $EUID -eq 0 ] || { echo "Please run as root." >&2; exit 1; }
}

check_sudo_cve_vulnerability() {
    echo -e "\033[1;31m[+] Checking for sudo CVE-2025-32463 / CVE-2025-23381...\033[0m"

    local required_version="1.9.17p1"
    local installed_version

    if ! command -v sudo >/dev/null 2>&1; then
        echo -e "\033[1;33m[WARNING]\033[0m sudo not found. Cannot check vulnerability status."
        return
    fi

    installed_version=$(sudo -V | head -n1 | awk '{print $NF}')

    if command -v dpkg >/dev/null 2>&1; then
        if dpkg --compare-versions "$installed_version" lt "$required_version"; then
            echo -e "\033[1;31m[CRITICAL]\033[0m Detected vulnerable sudo version: $installed_version"

            if ! $SKIP_WHIPTAIL && command -v whiptail >/dev/null 2>&1; then
                whiptail --title "CVE-2025-23381 Detected" \
                    --yesno "Your system has a vulnerable version of sudo: $installed_version\n\nWould you like to auto-update it now?" 12 60 || {
                        echo -e "\033[1;31m[BLOCKED]\033[0m User declined sudo update. Exiting."
                        exit 1
                    }
            fi

            echo -e "\033[1;33m[+] Attempting to upgrade sudo automatically...\033[0m"
            DEBIAN_FRONTEND=noninteractive apt-get update -y
            DEBIAN_FRONTEND=noninteractive apt-get install sudo -y

            installed_version=$(sudo -V | head -n1 | awk '{print $NF}')
            if dpkg --compare-versions "$installed_version" lt "$required_version"; then
                echo -e "\033[1;31m[FAIL]\033[0m Upgrade unsuccessful. Sudo is still $installed_version"

                if ! $SKIP_WHIPTAIL && command -v whiptail >/dev/null 2>&1; then
                    whiptail --title "Sudo Upgrade Failed" \
                        --msgbox "Sudo could not be upgraded to a secure version.\nInstallation cannot proceed.\n\nPlease upgrade manually:\n\nsudo apt install sudo" 12 60
                fi

                exit 1
            else
                echo -e "\033[1;32m[PASS]\033[0m Sudo upgraded to secure version $installed_version"
            fi
        else
            echo -e "\033[1;32m[PASS]\033[0m Sudo version $installed_version is secure."
        fi
    else
        echo -e "\033[1;33m[WARNING]\033[0m dpkg not available. Cannot validate version securely."
    fi
}

update_system() {
    echo -e "\033[1;31m[+] Updating system...\033[0m"
    DEBIAN_FRONTEND=noninteractive apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
}

install_man_page() {
    echo -e "\033[1;31m[+] Installing man page...\033[0m"
    install -d -m 755 /usr/share/man/man1
    install -m 644 man/hardn-xdr.1 /usr/share/man/man1/
    gzip -f /usr/share/man/man1/hardn-xdr.1
    mandb
    echo -e "\033[1;32m[+] Man page installed successfully.\033[0m"
}

install_source_files() {
    echo -e "\033[1;31m[+] Installing source files...\033[0m"
    install -d -m 755 "$PREFIX"
    cp -r src "$PREFIX/"
    echo -e "\033[1;32m[+] Source files installed successfully.\033[0m"
}

install_wrapper() {
    echo -e "\033[1;31m[+] Installing command wrapper...\033[0m"
    cat > "$WRAPPER" <<EOF
#!/usr/bin/env bash
# hardn-xdr command wrapper

if [[ \$# -eq 0 ]]; then
  exec "$MAIN_SCRIPT"
else
  exec "$MAIN_SCRIPT" "\$@"
fi
EOF
    chmod +x "$WRAPPER"
    echo -e "\033[1;32m[+] Command wrapper installed successfully.\033[0m"
}

verify_dependencies() {
    echo -e "\033[1;31m[+] Verifying dependencies...\033[0m"

    local deps=("bash" "apt" "dpkg" "sed" "awk" "grep")
    local ret_code=0

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "Error: Required dependency '$dep' is not installed." >&2
            ret_code=1
        fi
    done

    [ $ret_code -eq 0 ] || { echo "Error: Missing required dependencies. Aborting installation." >&2; exit 1; }

    echo -e "\033[1;32m[+] All dependencies are satisfied.\033[0m"
    return 0
}

install_files() {
    echo -e "\033[1;31m[+] Installing HARDN-XDR files...\033[0m"
    install -d -m 755 "$PREFIX"
    cp -r src "$PREFIX/"
    chmod -R 755 "$PREFIX/src"
    echo -e "\033[1;32m[+] HARDN-XDR files installed successfully.\033[0m"
}

main() {
    check_root
    check_sudo_cve_vulnerability
    verify_dependencies
    update_system
    install_files
    install_wrapper
    install_man_page

    echo "hardn-xdr installer is ready. Run 'sudo hardn-xdr' to begin."
}

main "$@"