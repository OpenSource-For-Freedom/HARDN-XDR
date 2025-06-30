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
  for cmd in whiptail; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Dependency missing: $cmd. Please install it." >&2
      exit 1
    fi
  done
}

main() {
  check_root
  verify_dependencies
  update_system

    echo "Error: main script not found at $MAIN_SCRIPT" >&2
    exit 1
  fi
  chmod +x "$MAIN_SCRIPT"

  install_wrapper

  echo "hardn-xdr installer is ready. Run 'hardn-xdr' to begin."
}

main "$@"
