#!/usr/bin/env bash

set -euo pipefail

PREFIX=/usr/lib/hardn-xdr
MAIN_SCRIPT="$PREFIX/src/setup/hardn-main.sh"
WRAPPER=/usr/bin/hardn-xdr

check_root() {
        [ $EUID -eq 0 ] || { echo "Please run as root." >&2; exit 1; }
}

check_sudo_cve_vulnerability() {
    echo -e "\033[1;31m[+] Checking for sudo CVE-2025-32463 / CVE-2025-23381...\033[0m"

    # Minimum secure version known to be patched
    local required_version="1.9.17p1"
    local installed_version

    # Extract version number
    if command -v sudo >/dev/null 2>&1; then
        installed_version=$(sudo -V | head -n1 | awk '{print $NF}')
    else
        echo -e "\033[1;33m[WARNING]\033[0m sudo not found on system. Cannot verify vulnerability."
        return
    fi

    # Compare using dpkg if available
    if command -v dpkg >/dev/null 2>&1; then
        if dpkg --compare-versions "$installed_version" lt "$required_version"; then
            echo -e "\033[1;31m[CRITICAL]\033[0m Your sudo version ($installed_version) is vulnerable to CVE-2025-23381."
            echo -e "\033[1;33m[WARNING]\033[0m Please run: \033[1;34msudo apt install sudo\033[0m to upgrade before using HARDN-XDR."
        else
            echo -e "\033[1;32m[OK]\033[0m Sudo version $installed_version is secure."
        fi
    else
        echo -e "\033[1;33m[WARNING]\033[0m dpkg not available; cannot compare versions reliably."
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

# if called with no args, run the full installer
if [[ \$# -eq 0 ]]; then
  exec "$MAIN_SCRIPT"
else
  # pass any subcommand through (e.g. --help, --version, start, etc)
  exec "$MAIN_SCRIPT" "\$@"
fi
EOF
  chmod +x "$WRAPPER"
  echo -e "\033[1;32m[+] Command wrapper installed successfully.\033[0m"
}

verify_dependencies() {
        echo -e "\033[1;31m[+] Verifying dependencies...\033[0m"

        # Define required dependencies array
        local deps[0]="bash"
        local deps[1]="apt"
        local deps[2]="dpkg"
        local deps[3]="sed"
        local deps[4]="awk"
        local deps[5]="grep"

        local ret_code=0

        # Loop through each dependency
        for (( i=0; i<${#deps[@]}; i++ )); do
                if ! command -v "${deps[$i]}" >/dev/null 2>&1; then
                        echo "Error: Required dependency '${deps[$i]}' is not installed." >&2
                        ret_code=1
                fi
        done

        [ $ret_code -eq 0 ] || { echo "Error: Missing required dependencies. Aborting installation." >&2; exit 1; }

        echo -e "\033[1;32m[+] All dependencies are satisfied.\033[0m"
        return 0
}

install_files() {
        # Create destination directory
        # Copy all project files to the destination
        # Set appropriate permissions
        echo -e "\033[1;31m[+] Installing HARDN-XDR files...\033[0m"
        install -d -m 755 "$PREFIX" && cp -r src "$PREFIX/" && chmod -R 755 "$PREFIX/src"
        echo -e "\033[1;32m[+] HARDN-XDR files installed successfully.\033[0m"
}
# CVE‑2025‑32463/CVE‑2025‑23381
check_sudo_version() {
  echo "[+] Checking sudo version…"
  local req="1.9.17p1"
  local inst=$(sudo -V | head -n1 | awk '{print $NF}')
  if dpkg --compare-versions "$inst" lt "$req"; then
    echo "Installed sudo $inst is vulnerable to CVE-2025-32463/23381. Upgrade to ≥ $req."
  else
    echo "sudo $inst is patched."
  fi
}

main() {
        check_root
        check_sudo_version
        check_sudo_cve_vulnerability
        verify_dependencies
        update_system
        install_files
        install_wrapper
        install_man_page
        
        echo "hardn-xdr installer is ready. Run 'sudo hardn-xdr' to begin."
}

main "$@"

