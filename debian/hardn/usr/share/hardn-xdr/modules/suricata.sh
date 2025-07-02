#!/bin/bash
HARDN_STATUS "info" "Checking and configuring Suricata..."

if ! dpkg -s suricata >/dev/null 2>&1; then
	HARDN_STATUS "info" "Suricata package not found. Attempting to install via apt..."
	if ! apt install -y suricata; then
		HARDN_STATUS "error" "Error: Failed to install Suricata."
		return 1
	fi
else
	HARDN_STATUS "info" "Suricata is already installed."
fi

HARDN_STATUS "info" "Updating Suricata rules..."
if ! suricata-update; then
	HARDN_STATUS "error" "Error: Failed to update Suricata rules."
fi

# Detect active network interface and IP address
INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')
IPADDR=$(ip -o -4 addr show "$INTERFACE" | awk '{print $4}')

HARDN_STATUS "info" "Detected interface: $INTERFACE with IP: $IPADDR"
HARDN_STATUS "info" "Edit /etc/suricata/suricata.yaml:"
HARDN_STATUS "info" "  - Set 'interface: $INTERFACE' under 'af-packet:'"
HARDN_STATUS "info" "  - Set 'HOME_NET: \"$IPADDR\"' under 'vars:'"

HARDN_STATUS "info" "Restarting Suricata to apply changes..."
systemctl restart suricata

HARDN_STATUS "info" "Suricata setup complete. Check logs with: journalctl -u suricata"

# Additional operational tips
echo
echo "To verify Suricata is running, check the log:"
echo "  sudo tail /var/log/suricata/suricata.log"
echo
echo "To see live statistics:"
echo "  sudo tail -f /var/log/suricata/stats.log"
echo
echo "To test alerting, open another terminal and run:"
echo "  sudo tail -f /var/log/suricata/fast.log"
echo "Then, in a different terminal, run:"
echo "  curl http://testmynids.org/uid/index.html"
echo
echo "To view EVE JSON alerts (requires jq):"
echo "  sudo tail -f /var/log/suricata/eve.json | jq 'select(.event_type==\"alert\")'"
echo
echo "To view EVE JSON stats:"
echo "  sudo tail -f /var/log/suricata/eve.json | jq 'select(.event_type==\"stats\")|.stats.capture.kernel_packets'"
echo "  sudo tail -f /var/log/suricata/eve.json | jq 'select(.event_type==\"stats\")'"
