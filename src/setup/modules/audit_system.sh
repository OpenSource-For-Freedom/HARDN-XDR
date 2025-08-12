#!/bin/bash

# shellcheck disable=SC1091
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh

# Check for container environment
if is_container_environment; then
    HARDN_STATUS "info" "Container environment detected - system audit capabilities may be limited"
    HARDN_STATUS "info" "Some audit features may not be available in containerized environments"
fi

HARDN_STATUS "info" "Auditing System for STIG Compliance.."

install_package_if_missing() {
    if ! dpkg -s "$1" &>/dev/null; then
        HARDN_STATUS "info" "Package '$1' not found. Installing..."
        safe_package_install "$1"
    else
        HARDN_STATUS "info" "Package '$1' is already installed."
    fi
}

install_package_if_missing "libpam-tmpdir"
install_package_if_missing "apt-listbugs"
install_package_if_missing "needrestart"

# Remove compilers and uneeded binaries
if is_container_environment; then
    HARDN_STATUS "info" "Container environment detected - skipping compiler removal"
    HARDN_STATUS "info" "Container images may require build tools for runtime operations"
else
    HARDN_STATUS "info" "Removing compilers and unnecessary binaries..."

    COMPILERS=(gcc g++ make cpp clang clang++ nasm perl python2 python2.7)

    for bin in "${COMPILERS[@]}"; do
        if command -v "$bin" &>/dev/null; then
            HARDN_STATUS "info" "Removing $bin..."
            apt-get remove --purge -y "$bin" >/dev/null 2>&1 || true
        fi
    done

    apt-get remove --purge -y build-essential gcc-* g++-* clang-* >/dev/null 2>&1 || true
    apt-get autoremove -y >/dev/null 2>&1 || true
    apt-get autoclean -y >/dev/null 2>&1 || true
fi

# Crypto/entropy audit
HARDN_STATUS "info" "Checking cryptography and entropy sources..."

find /etc/ssl /etc/letsencrypt -type f \( -name "*.crt" -o -name "*.pem" \) 2>/dev/null | while read -r cert; do
	if openssl x509 -checkend 0 -noout -in "$cert" 2>/dev/null | grep -q "expired"; then
		HARDN_STATUS "warn" "Expired SSL certificate: $cert"
	fi
done

ENTROPY=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo 0)
if [ "$ENTROPY" -ge 256 ]; then
	HARDN_STATUS "pass" "Kernel entropy is sufficient ($ENTROPY)"
else
	HARDN_STATUS "warn" "Kernel entropy is low ($ENTROPY)"
fi

if command -v rngd &>/dev/null && (ls /dev/hwrng &>/dev/null || ls /dev/random &>/dev/null); then
	if pgrep rngd &>/dev/null; then
		HARDN_STATUS "pass" "Hardware RNG and rngd are active"
	else
		HARDN_STATUS "warn" "Hardware RNG present but rngd is not running"
	fi
else
	HARDN_STATUS "warn" "No hardware RNG or rngd not installed"
fi

if systemctl is-active --quiet haveged 2>/dev/null || systemctl is-active --quiet jitterentropy-rngd 2>/dev/null; then
	HARDN_STATUS "pass" "Software PRNG (haveged or jitterentropy-rngd) is active"
else
	HARDN_STATUS "warn" "No software PRNG (haveged or jitterentropy-rngd) is running"
fi

# Permissions hardening
chmod 1777 /tmp /var/tmp 2>/dev/null || true
find /var/log -type f -exec chmod 640 {} \; 2>/dev/null || true
find /var/log -type d -exec chmod 750 {} \; 2>/dev/null || true

# PAM & limits
HARDN_STATUS "info" "Enhancing PAM and security limits..."
pam_login="/etc/pam.d/login"
if [ -f "$pam_login" ] && ! grep -q "pam_limits.so" "$pam_login"; then
    echo "session required pam_limits.so" >> "$pam_login"
fi
if ! grep -q '^\* hard core 0' /etc/security/limits.conf 2>/dev/null; then
    echo '* hard core 0' >> /etc/security/limits.conf
fi

chmod 750 /etc/sudoers.d 2>/dev/null || true

# Cron/system account perms
HARDN_STATUS "info" "Hardening cron and system account file permissions..."
find /etc/cron.d -type f -exec chmod 644 {} \; 2>/dev/null || true
chmod -R 755 /etc/cron.daily /etc/cron.hourly /etc/cron.monthly /etc/cron.weekly 2>/dev/null || true

chmod 644 /etc/passwd 2>/dev/null || true
chmod 640 /etc/shadow 2>/dev/null || true
chmod 644 /etc/group 2>/dev/null || true
chmod 640 /etc/gshadow 2>/dev/null || true

HARDN_STATUS "info" "Removing world-writable permissions from system config files..."
find /etc -type f -name "*.conf" -perm -002 -exec chmod o-w {} \; 2>/dev/null || true

# Systemd hardening
HARDN_STATUS "info" "Hardening systemd service file permissions..."
find /etc/systemd/system -type f -exec chmod 644 {} \; 2>/dev/null || true
find /etc/systemd/system -type d -exec chmod 755 {} \; 2>/dev/null || true

HARDN_STATUS "info" "For further systemd hardening, review 'systemd-analyze security'..."

HARDENED_SERVICES=(
	"cron.service"
	"ssh.service"
	"rsyslog.service"
	"dbus.service"
	"cups.service"
	"avahi-daemon.service"
	"systemd-udevd.service"
	# "getty@.service"
	# "user@.service"
	"wpa_supplicant.service"
)

for svc in "${HARDENED_SERVICES[@]}"; do
	unit_dir="/etc/systemd/system/${svc}.d"
	mkdir -p "$unit_dir"
	tee "$unit_dir/10-hardening.conf" > /dev/null <<EOF
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

# Skip systemd operations in CI environment
if [[ -n "$CI" || -n "$GITHUB_ACTIONS" ]]; then
    HARDN_STATUS "info" "CI environment detected, skipping systemd daemon-reload"
else
    systemctl daemon-reload 2>/dev/null || HARDN_STATUS "warning" "systemctl daemon-reload failed, continuing..."
fi

# Set secure umask
if ! grep -q "umask 027" /etc/profile; then
	echo "umask 027" >> /etc/profile
fi

# Mail queue permissions
is_installed() {
	command -v "$1" &>/dev/null || return 1
}

if is_installed postfix; then
	chmod 700 /var/spool/postfix/maildrop 2>/dev/null || true
fi

HARDN_STATUS "pass" "General system hardening settings applied."


VERBOSE_MODE="YES"
DEBUG_MODE="YES"

echo "[+] Program Details"
echo "------------------------------------"
echo "  - Verbose mode                                              [ $VERBOSE_MODE ]"
echo "  - Debug mode                                                [ $DEBUG_MODE ]"
echo


return 0 2>/dev/null || hardn_module_exit 0
