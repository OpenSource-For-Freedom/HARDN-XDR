#!/bin/bash
set -e



echo "Starting HARDN-XDR container..."
echo "HARDN-XDR Home: ${HARDN_XDR_HOME}"


if [ ! -x "/usr/local/bin/hardn-xdr" ]; then
    #  wrapper
    cat > /usr/local/bin/hardn-xdr << 'EOF'
#!/bin/bash
# HARDN-XDR wrapper script for Docker container
HARDN_XDR_HOME="${HARDN_XDR_HOME:-/opt/hardn-xdr}"
if [ -x "${HARDN_XDR_HOME}/hardn-xdr" ]; then
    exec "${HARDN_XDR_HOME}/hardn-xdr" "$@"
elif [ -x "/opt/hardn-xdr/hardn-xdr" ]; then
    exec "/opt/hardn-xdr/hardn-xdr" "$@"
else
    echo "Error: hardn-xdr not found in expected locations" >&2
    echo "Checked: ${HARDN_XDR_HOME}/hardn-xdr and /opt/hardn-xdr/hardn-xdr" >&2
    exit 1
fi
EOF
    chmod +x /usr/local/bin/hardn-xdr
fi


echo ""
echo "Available commands:"
echo "  hardn-xdr --help                    - Show HARDN-XDR help"
echo "  hardn-xdr --docker-debian-cve       - Test Debian CVE mitigations"
echo "  hardn-xdr --docker --module kernel_sec  - Test kernel security (glibc ASLR/stack guard)"
echo "  sudo ${HARDN_XDR_HOME}/smoke_test.sh        - Run smoke test (requires sudo)"
echo "  sudo ${HARDN_XDR_HOME}/hardn_audit.sh       - Run security audit (requires sudo)"
echo ""
echo "Examples:"
echo "  hardn-xdr --docker-debian-cve"
echo "  hardn-xdr --list-modules"
echo ""


if [ $# -eq 0 ]; then
    echo "No command provided. Running hardn-xdr --help:"
    hardn-xdr --help
else
    # Execute the command passed to docker run
    exec "$@"
fi
