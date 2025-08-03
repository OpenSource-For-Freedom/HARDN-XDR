#!/bin/bash

# shellcheck disable=SC1091
# Source common functions - try both installed path and relative path
if [[ -f "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" ]]; then
    source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
elif [[ -f "../hardn-common.sh" ]]; then
    source ../hardn-common.sh
elif [[ -f "src/setup/hardn-common.sh" ]]; then
    source src/setup/hardn-common.sh
else
    echo "Error: Cannot find hardn-common.sh"
    exit 1
fi
set -e

HARDN_STATUS "info" "Installing Suricata (basic mode)..."

# Handle CI environment
if [[ -n "$CI" || -n "$GITHUB_ACTIONS" ]]; then
    HARDN_STATUS "info" "CI environment detected, skipping Suricata installation"
    HARDN_STATUS "pass" "Suricata module completed (skipped in CI environment)"
    exit 0
fi

apt-get update || true
if ! apt-get install -y suricata suricata-update; then
    HARDN_STATUS "warning" "Failed to install Suricata packages, skipping configuration"
    exit 0
fi

# Auto-detect interface
iface=$(ip route | grep default | awk '{print $5}' | head -n 1)
iface=${iface:-eth0}
HARDN_STATUS "info" "Using detected interface: $iface"

# Check if suricata.yaml exists before modifying
if [[ ! -f /etc/suricata/suricata.yaml ]]; then
    HARDN_STATUS "warning" "Suricata configuration file not found, skipping configuration"
    exit 0
fi

# Configure AF_PACKET interface for packet capture
HARDN_STATUS "info" "Configuring Suricata for packet capture on interface: $iface"

# Update the interface in the af-packet configuration
sed -i "/^af-packet:/,/^[^[:space:]]/ {
    /interface: / s/interface: .*/interface: $iface/
}" /etc/suricata/suricata.yaml

# Clean up and fix Suricata rules configuration
HARDN_STATUS "info" "Cleaning up Suricata rules configuration..."

# Remove all existing rule-files configurations to start fresh
sed -i '/^rule-files:/,/^[a-zA-Z]/{ /^[a-zA-Z]:/!d; }' /etc/suricata/suricata.yaml
sed -i '/^rule-files:/d' /etc/suricata/suricata.yaml

# Add proper Suricata rules configuration
cat >> /etc/suricata/suricata.yaml << 'EOF'

# Suricata rule files configuration
rule-files:
  - /etc/suricata/rules/app-layer-events.rules
  - /etc/suricata/rules/decoder-events.rules
  - /etc/suricata/rules/dhcp-events.rules
  - /etc/suricata/rules/dns-events.rules
  - /etc/suricata/rules/files.rules
  - /etc/suricata/rules/http-events.rules
  - /etc/suricata/rules/ipsec-events.rules
  - /etc/suricata/rules/nfs-events.rules
  - /etc/suricata/rules/ntp-events.rules
  - /etc/suricata/rules/smb-events.rules
  - /etc/suricata/rules/smtp-events.rules
  - /etc/suricata/rules/ssh-events.rules
  - /etc/suricata/rules/stream-events.rules
  - /etc/suricata/rules/tls-events.rules
  # Disabled protocol rules (protocols not enabled):
  # - /etc/suricata/rules/dnp3-events.rules    # DNP3 protocol disabled
  # - /etc/suricata/rules/http2-events.rules   # HTTP2 protocol disabled
  # - /etc/suricata/rules/modbus-events.rules  # Modbus protocol disabled
  # - /etc/suricata/rules/mqtt-events.rules    # MQTT protocol disabled
EOF

HARDN_STATUS "pass" "Cleaned up and configured Suricata rules"

if ! timeout 60 suricata -T -c /etc/suricata/suricata.yaml > /dev/null 2>&1; then
    HARDN_STATUS "warning" "Suricata configuration test failed, skipping service setup."
    exit 0
fi
HARDN_STATUS "pass" "Suricata configuration is valid."

# Update rules (ET Open)
if timeout 120 suricata-update; then
    HARDN_STATUS "pass" "Suricata rules updated."
else
    HARDN_STATUS "warning" "suricata-update timed out or failed."
fi

# Create systemd override to specify the interface for packet capture
mkdir -p /etc/systemd/system/suricata.service.d/
cat > /etc/systemd/system/suricata.service.d/interface.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/bin/suricata -D --af-packet=$iface -c /etc/suricata/suricata.yaml --pidfile /run/suricata.pid
EOF

# Reload systemd and enable/restart service
systemctl daemon-reload
systemctl enable suricata.service 2>/dev/null || HARDN_STATUS "warning" "Failed to enable suricata service"
systemctl restart suricata.service 2>/dev/null || HARDN_STATUS "warning" "Failed to restart suricata service"

if systemctl is-active --quiet suricata.service; then
    HARDN_STATUS "pass" "Suricata service is running."
else
    HARDN_STATUS "warning" "Suricata service failed to start (may be normal in CI environment)."
    exit 0
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

HARDN_STATUS "pass" "Suricata module completed successfully"
exit 0
