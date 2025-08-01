#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -euo pipefail

suricata_module() {
    HARDN_STATUS "info" "Installing Suricata (basic mode)..."
    apt-get update || true
    if ! apt-get install -y suricata python3-suricata-update; then
        HARDN_STATUS "error" "Failed to install Suricata packages"
        return 100
    fi

    # Auto-detect interface
    local iface
    iface=$(ip route | grep default | awk '{print $5}' | head -n 1)
    iface=${iface:-eth0}
    HARDN_STATUS "info" "Using detected interface: $iface"

    # Check if suricata.yaml exists before modifying
    if [[ ! -f /etc/suricata/suricata.yaml ]]; then
        HARDN_STATUS "error" "Suricata configuration file not found"
        return 100
    fi

    sed -i "s/interface: .*/interface: $iface/" /etc/suricata/suricata.yaml

    if ! timeout 60 suricata -T -c /etc/suricata/suricata.yaml > /dev/null 2>&1; then
        HARDN_STATUS "error" "Suricata configuration test failed."
        return 100
    fi
    HARDN_STATUS "pass" "Suricata configuration is valid."

    # Update rules (ET Open)
    if timeout 120 suricata-update; then
        HARDN_STATUS "pass" "Suricata rules updated."
    else
        HARDN_STATUS "warning" "suricata-update timed out or failed."
    fi

    systemctl enable suricata.service || true
    systemctl restart suricata.service

    if systemctl is-active --quiet suricata.service; then
        HARDN_STATUS "pass" "Suricata service is running."
    else
        HARDN_STATUS "error" "Suricata service failed to start."
        return 100
    fi

    # daily rule update
    cat > /etc/cron.daily/update-suricata-rules << 'EOF'
#!/bin/bash
LOG="/var/log/suricata/rule-updates.log"
mkdir -p "$(dirname "$LOG")"
echo "$(date): Updating Suricata rules..." >> "$LOG"
if command -v suricata-update &>/dev/null; then
    suricata-update >> "$LOG" 2>&1 && systemctl restart suricata.service
else
    echo "suricata-update not found." >> "$LOG"
fi
EOF
    chmod +x /etc/cron.daily/update-suricata-rules
    HARDN_STATUS "pass" "Daily Suricata rule updater installed."

    return 0
}


suricata_module