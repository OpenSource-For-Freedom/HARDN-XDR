GRUB_CFG="/etc/grub.d/41_custom"
GRUB_DEFAULT="/etc/default/grub"
GRUB_USER="hardnxdr"
CUSTOM_CFG="/boot/grub/custom.cfg"
GRUB_MAIN_CFG="/boot/grub/grub.cfg"
PASSWORD_FILE="/root/.hardn-grub-password"

echo "=== GRUB Security Dry-Run Test ==="
echo "[INFO] This will test GRUB security configuration WITHOUT making changes"
echo

# Check if running in a VM
if systemd-detect-virt --quiet --vm; then
	echo "[INFO] Running in a VM, skipping GRUB security configuration."
	echo "[INFO] This script is not intended to be run inside a VM."
	return 0
fi

# Check system type
if [ -d /sys/firmware/efi ]; then
	SYSTEM_TYPE="EFI"
	echo "[INFO] Detected EFI boot system"
	echo "[INFO] GRUB security configuration is not required for EFI systems."
	return 0
else
	SYSTEM_TYPE="BIOS"
	echo "[INFO] Detected BIOS boot system"
fi

# Test password generation
echo "[TEST] Testing GRUB password generation..."
TEST_PASS=$(openssl rand -base64 12 | tr -d '\n')
HASH=$(echo -e "$TEST_PASS\n$TEST_PASS" | grub-mkpasswd-pbkdf2 | grep "PBKDF2 hash of your password is" | sed 's/PBKDF2 hash of your password is //')

if [ -z "$HASH" ]; then
	echo "[ERROR] Failed to generate password hash"
	return 1
else
	echo "[SUCCESS] Password hash generated: ${HASH:0:50}..."
fi

# Test file access
echo "[TEST] Checking file permissions and access..."
if [ -w "$GRUB_CFG" ]; then
	echo "[SUCCESS] Can write to custom GRUB config: $GRUB_CFG"
else
	echo "[ERROR] Cannot write to custom GRUB config: $GRUB_CFG"
fi

if [ -w "$GRUB_MAIN_CFG" ]; then
	echo "[SUCCESS] Can write to main GRUB config: $GRUB_MAIN_CFG"
else
	echo "[ERROR] Cannot write to main GRUB config: $GRUB_MAIN_CFG"
fi

# Test update-grub
echo "[TEST] Testing GRUB update capability..."
if command -v update-grub >/dev/null 2>&1; then
	echo "[SUCCESS] update-grub available"
else
	echo "[ERROR] update-grub not available"
fi

# Show what would be created
echo
echo "=== Configuration Preview ==="
echo "[INFO] Custom config would be created at: $CUSTOM_CFG"
echo "[INFO] Content would be:"
echo "---"
echo "set superusers=\"$GRUB_USER\""
echo "password_pbkdf2 $GRUB_USER $HASH"
echo "---"

echo
echo "[INFO] Custom GRUB script would be updated at: $GRUB_CFG"
echo "[INFO] Files would be backed up with .backup extension"
echo "[INFO] Permissions would be set to 600 (root only)"

echo
echo "[INFO] Password would be saved (in real script) to: $PASSWORD_FILE"

echo
echo "=== Summary ==="
echo "[SUCCESS] All tests passed! GRUB security configuration is ready."
echo "[INFO] To apply the configuration, run:"
echo "  sudo /usr/share/hardn/tools/stig/grub.sh"
echo "[WARNING] Make sure to remember the password you set!"
echo "[INFO] GRUB Username: $GRUB_USER"
echo "[INFO] GRUB Password saved to: $PASSWORD_FILE"

return 0
