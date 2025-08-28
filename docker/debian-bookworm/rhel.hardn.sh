#!/bin/bash
# HARDN-XDR (RHEL 9 / UBI9) minimal hardening pass (container-safe)
# - Sets userland crypto policy to FIPS (host FIPS recommended)
# - Installs/ensures AIDE + libpwquality present
# - Configures AIDE with SHA-512 and summary logging
# - Writes login banners (/etc/issue, /etc/issue.net)
# - Drops a conservative sysctl file; applies best-effort
# - Skips Debian/apt, AppArmor, UFW, and systemd-only actions
###################################################################

set -Eeuo pipefail
IFS=$'\n\t'


if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root inside the container." >&2
  exit 1
fi


if ! grep -qiE 'rhel|red hat|ubi' /etc/os-release; then
  echo "This script targets RHEL 9 / UBI9." >&2
  exit 1
fi


chmod 700 "${BASH_SOURCE[0]}"

echo "---------------------------------------------"
echo " HARDN-XDR (RHEL9/UBI9) hardening start"
echo "---------------------------------------------"


if command -v update-crypto-policies >/dev/null 2>&1; then
  update-crypto-policies --set FIPS || echo "WARN: Unable to set FIPS crypto policy (userland)"
fi


python3 -m pip --version >/dev/null 2>&1 || true
python3 -m pip install --no-cache-dir --upgrade pip setuptools requests pexpect || true


echo "[+] Configuring AIDE..."
install -d -m 0755 /etc/aide
cat > /etc/aide/aide.conf <<'EOF'
# AIDE configuration (RHEL9/UBI9)
database_in=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new
gzip_dbout=yes
log_level=error
report_level=summary

# Rules (force sha512)
NORMAL = p+i+n+u+g+acl+selinux+xattrs+sha512
LOG = p+i+n+u+g+sha512

# Ignore ephemeral mounts
!/proc
!/sys
!/dev
!/run

# Monitor core paths
/bin         NORMAL
/sbin        NORMAL
/usr/bin     NORMAL
/usr/sbin    NORMAL
/etc         NORMAL
/lib         NORMAL
/lib64       NORMAL
/opt         NORMAL
/home        NORMAL

/var/log     LOG

!/var/cache
EOF

install -d -m 0700 /var/lib/aide
touch /var/lib/aide/aide.db.new /var/lib/aide/aide.db
aide --update --config /etc/aide/aide.conf || true
aide -i        --config /etc/aide/aide.conf || true


echo "[+] Writing legal banners..."
echo "Unauthorized access is prohibited. All activity is monitored." > /etc/issue
echo "Unauthorized access is prohibited. All activity is monitored." > /etc/issue.net
chmod 0644 /etc/issue /etc/issue.net


echo "[+] Dropping sysctl hardening (best-effort inside containers)..."
cat > /etc/sysctl.d/99-hardening.conf <<'EOF'
# Hardened defaults (container-safe best-effort)
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.all.send_redirects = 0

fs.protected_fifos = 2
fs.protected_hardlinks = 1
fs.protected_regular = 2
fs.protected_symlinks = 1
fs.suid_dumpable = 0

kernel.kptr_restrict = 2
kernel.randomize_va_space = 2
kernel.yama.ptrace_scope = 1

net.core.bpf_jit_harden = 2

net.ipv4.tcp_fin_timeout = 15
EOF


sysctl --system || echo "WARN: Some sysctl settings could not be applied in this container."

echo "---------------------------------------------"
echo " [+] HARDN-XDR (RHEL9/UBI9) hardening complete"
echo "---------------------------------------------"