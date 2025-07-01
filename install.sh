#!/usr/bin/env bash
set -euo pipefail

PREFIX=/usr/lib/hardn-xdr
MAIN_SCRIPT="$PREFIX/src/setup/hardn-main.sh"
WRAPPER=/usr/bin/hardn-xdr

check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Please run as root." >&2
    exit 1
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

install_wrapper() {
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
}
verify_dependencies() {
  echo -e "\033[1;31m[+] Verifying dependencies...\033[0m"
  local deps=("bash" "apt" "dpkg" "sed" "awk" "grep")
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      echo "Error: Required dependency '$dep' is not installed." >&2
      exit 1
    fi
  done
  echo -e "\033[1;32m[+] All dependencies are satisfied.\033[0m"
}

main() {
  check_root
  verify_dependencies
  update_system
  install_wrapper
  install_man_page

  echo "hardn-xdr installer is ready. Run 'sudo hardn-xdr' to begin."
}

main "$@"
