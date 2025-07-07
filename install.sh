#!/usr/bin/env bash

set -euo pipefail

PREFIX=/usr/lib/hardn-xdr
MAIN_SCRIPT="$PREFIX/src/setup/hardn-main.sh"
WRAPPER=/usr/bin/hardn-xdr

log() {
    echo -e "\033[1;34m[$(date '+%H:%M:%S')] $1\033[0m"
}

check_root() {
    [ $EUID -eq 0 ] || { echo "Please run as root." >&2; exit 1; }
}

update_system() {
    log "[+] Updating system..."
    DEBIAN_FRONTEND=noninteractive apt-get update -y
}

install_man_page() {
    log "[+] Installing man page..."
    install -d -m 755 /usr/share/man/man1
    install -m 644 man/hardn-xdr.1 /usr/share/man/man1/
    gzip -f /usr/share/man/man1/hardn-xdr.1
    mandb || true
    log "[✓] Man page installed successfully."
}

install_source_files() {
    log "[+] Installing source files..."
    install -d -m 755 "$PREFIX"
    cp -r src "$PREFIX/"
    log "[✓] Source files installed successfully."
}

install_wrapper() {
    log "[+] Installing command wrapper..."
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
    log "[✓] Command wrapper installed successfully."
}

verify_dependencies() {
    log "[+] Verifying dependencies..."

    local deps=(bash apt dpkg sed awk grep)
    local ret_code=0

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "Error: Required dependency '$dep' is not installed." >&2
            ret_code=1
        fi
    done

    [ $ret_code -eq 0 ] || {
        echo "Error: Missing required dependencies. Aborting installation." >&2
        exit 1
    }

    log "[✓] All dependencies are satisfied."
    return 0
}

install_files() {

    log "[+] Installing HARDN-XDR files..."
    install -d -m 755 "$PREFIX" && cp -r src "$PREFIX/" && chmod -R 755 "$PREFIX/src"
    log "[✓] HARDN-XDR files installed successfully."
}

main() {
    log "Starting HARDN-XDR install.sh"
    check_root
    verify_dependencies
    update_system
    install_files
    install_wrapper
    install_man_page

    if [[ -x "$MAIN_SCRIPT" ]]; then
        log "[✓] install.sh complete — run 'sudo hardn-xdr' to begin."
    else
        echo "[!] Warning: $MAIN_SCRIPT not found or not executable." >&2
    fi
}

main "$@"

