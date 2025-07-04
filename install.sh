#!/usr/bin/env bash

set -euo pipefail

PREFIX=/usr/lib/hardn-xdr
MAIN_SCRIPT="$PREFIX/src/setup/hardn-main.sh"
WRAPPER=/usr/bin/hardn-xdr

check_root() {
        [ $EUID -eq 0 ] || { echo "Please run as root." >&2; exit 1; }
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

main() {
        check_root
        verify_dependencies
        update_system
        install_files
        install_wrapper
        install_man_page
        
        echo "hardn-xdr installer is ready. Run 'sudo hardn-xdr' to begin."
}

main "$@"

