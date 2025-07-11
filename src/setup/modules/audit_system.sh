#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../hardn-common.sh" 2>/dev/null || {
    # Fallback if common file not found
    HARDN_STATUS() {
        local status="$1"
        local message="$2"
        case "$status" in
            "pass")    echo -e "\033[1;32m[PASS]\033[0m $message" ;;
            "warning") echo -e "\033[1;33m[WARNING]\033[0m $message" ;;
            "error")   echo -e "\033[1;31m[ERROR]\033[0m $message" ;;
            "info")    echo -e "\033[1;34m[INFO]\033[0m $message" ;;
            *)         echo -e "\033[1;37m[UNKNOWN]\033[0m $message" ;;
        esac
    }
}

set -e
HARDN_STATUS "info" "Applying general system hardening settings..."


# add missing installs

# Install missing packages if not present
install_package_if_missing() {
	if ! dpkg -s "$1" &>/dev/null; then
		HARDN_STATUS "info" "Package '$1' not found. Installing..."
		sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$1"
	else
		HARDN_STATUS "info" "Package '$1' is already installed."
	fi
}

sudo apt-get update

install_package_if_missing "libpam-tmpdir"
install_package_if_missing "apt-listbugs"
install_package_if_missing "needrestart"

# remove compilers and uneeded binaries
HARDN_STATUS "info" "Removing compilers and unnecessary binaries..."

COMPILERS=(
	gcc
	g++
	make
	cpp
	clang
	clang++
	nasm
	perl
	python2
	python2.7
)

for bin in "${COMPILERS[@]}"; do
	if command -v "$bin" &>/dev/null; then
		HARDN_STATUS "info" "Removing $bin..."
		sudo apt-get remove --purge -y "$bin" || true
	fi
done

# Remove development meta-packages if present
sudo apt-get remove --purge -y build-essential gcc-* g++-* clang-* || true

# Remove leftover package configs and clean up
sudo apt-get autoremove -y
sudo apt-get autoclean -y

# crypto audit
# Check cryptography and entropy sources

HARDN_STATUS "info" "Checking cryptography and entropy sources..."

# Check for expired SSL certificates (basic check in /etc/ssl and /etc/letsencrypt)
find /etc/ssl /etc/letsencrypt -type f \( -name "*.crt" -o -name "*.pem" \) 2>/dev/null | while read -r cert; do
	if openssl x509 -checkend 0 -noout -in "$cert" 2>/dev/null | grep -q "expired"; then
		HARDN_STATUS "warn" "Expired SSL certificate: $cert"
	fi
done

# Check kernel entropy
ENTROPY=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo 0)
if [ "$ENTROPY" -ge 256 ]; then
	HARDN_STATUS "pass" "Kernel entropy is sufficient ($ENTROPY)"
else
	HARDN_STATUS "warn" "Kernel entropy is low ($ENTROPY)"
fi

# Check for hardware RNG and rngd
if command -v rngd &>/dev/null && (ls /dev/hwrng &>/dev/null || ls /dev/random &>/dev/null); then
	if pgrep rngd &>/dev/null; then
		HARDN_STATUS "pass" "Hardware RNG and rngd are active"
	else
		HARDN_STATUS "warn" "Hardware RNG present but rngd is not running"
	fi
else
	HARDN_STATUS "warn" "No hardware RNG or rngd not installed"
fi

# Check for software PRNG (haveged or jitterentropy)
if systemctl is-active --quiet haveged 2>/dev/null || systemctl is-active --quiet jitterentropy-rngd 2>/dev/null; then
	HARDN_STATUS "pass" "Software PRNG (haveged or jitterentropy-rngd) is active"
else
	HARDN_STATUS "warn" "No software PRNG (haveged or jitterentropy-rngd) is running"
fi


# Set secure permissions on /tmp and /var/tmp
chmod 1777 /tmp /var/tmp 2>/dev/null || true

# Secure log file permissions (safe default)
find /var/log -type f -exec chmod 640 {} \; 2>/dev/null || true
find /var/log -type d -exec chmod 750 {} \; 2>/dev/null || true

# PAM and Limits hardening
HARDN_STATUS "info" "Enhancing PAM and security limits..."
pam_login="/etc/pam.d/login"
if [ -f "$pam_login" ] && ! grep -q "pam_limits.so" "$pam_login"; then
    echo "session required pam_limits.so" >> "$pam_login"
fi

if ! grep -q '* hard core 0' /etc/security/limits.conf 2>/dev/null; then
    echo '* hard core 0' >> /etc/security/limits.conf
fi

# Set secure permissions for /etc/sudoers.d directory
chmod 750 /etc/sudoers.d 2>/dev/null || true



# File permission hardening
HARDN_STATUS "info" "Hardening cron and system account file permissions..."
find /etc/cron.d -type f -exec chmod 644 {} \; 2>/dev/null || true
chmod 755 /etc/cron.daily /etc/cron.hourly /etc/cron.monthly /etc/cron.weekly 2>/dev/null || true
chmod -R 755 /etc/cron.daily /etc/cron.hourly /etc/cron.monthly /etc/cron.weekly 2>/dev/null || true

chmod 644 /etc/passwd 2>/dev/null || true
chmod 640 /etc/shadow 2>/dev/null || true
chmod 644 /etc/group 2>/dev/null || true
chmod 640 /etc/gshadow 2>/dev/null || true

# Remove world-writable permissions from system config files
HARDN_STATUS "info" "Removing world-writable permissions from system config files..."
find /etc -type f -name "*.conf" -perm -002 -exec chmod o-w {} \; 2>/dev/null || true

# systemd
HARDN_STATUS "info" "Hardening systemd service file permissions..."
find /etc/systemd/system -type f -exec chmod 644 {} \; 2>/dev/null || true
find /etc/systemd/system -type d -exec chmod 755 {} \; 2>/dev/null || true
# Recommend running 'systemd-analyze security' for detailed service security analysis
HARDN_STATUS "info" "For further systemd hardening, review 'systemd-analyze security' output and consider adjusting service unit files to improve security (e.g., add ProtectSystem, PrivateTmp, NoNewPrivileges, etc.)."

# Example: Automatically add basic hardening options to selected systemd unit overrides
HARDENED_SERVICES=(
	"cron.service"
	"ssh.service"
	"rsyslog.service"
	"dbus.service"
	"cups.service"
	"avahi-daemon.service"
	"systemd-udevd.service"
	"getty@.service"
	"user@.service"
	"wpa_supplicant.service"
)

for svc in "${HARDENED_SERVICES[@]}"; do
	unit_dir="/etc/systemd/system/${svc}.d"
	sudo mkdir -p "$unit_dir"
	sudo tee "$unit_dir/10-hardening.conf" > /dev/null <<EOF
[Service]
ProtectSystem=full
ProtectHome=yes
PrivateTmp=yes
NoNewPrivileges=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
EOF
done

sudo systemctl daemon-reload

# Set umask
if ! grep -q "umask 027" /etc/profile; then
	echo "umask 027" >> /etc/profile
fi

# Mail queue permissions
is_installed() {
	command -v "$1" &>/dev/null
}

if is_installed postfix; then
	chmod 700 /var/spool/postfix/maildrop 2>/dev/null || true
fi

HARDN_STATUS "pass" "General system hardening settings applied."


# program details

VERBOSE_MODE="YES"
DEBUG_MODE="YES"

echo "[+] Program Details"
echo "------------------------------------"
echo "  - Verbose mode                                              [ $VERBOSE_MODE ]"
echo "  - Debug mode                                                [ $DEBUG_MODE ]"
echo



