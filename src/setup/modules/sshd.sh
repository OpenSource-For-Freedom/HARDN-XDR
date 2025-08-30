m#!/bin/bash
# Module: openssh_install_light.sh (desktop/VM-friendly, non-blocking)

source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
  echo "Warning: Could not source hardn-common.sh, using basic functions"
  HARDN_STATUS(){ echo "$(date '+%F %T') - [$1] $2"; }
  log_message(){ echo "$(date '+%F %T') - $1"; }
  check_root(){ [[ $EUID -eq 0 ]]; }
  is_installed(){ command -v "$1" >/dev/null 2>&1 || dpkg -s "$1" >/dev/null 2>&1; }
  is_systemd_available(){ [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1; }
  is_container_environment(){ [[ -n "$CI" || -n "$GITHUB_ACTIONS" || -f /.dockerenv || -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null; }
  hardn_module_exit(){ exit "${1:-0}"; }
  safe_systemctl(){ timeout 20 systemctl "$@" >/dev/null 2>&1; }
}

HARDN_STATUS "info" "Installing OpenSSH server (light mode)…"
HARDN_STATUS "warning" "SSH hardening is NOT enforced here to avoid lockouts; enable later after key access is confirmed."

# --- Skip install in containers (non-blocking) ---
if is_container_environment; then
  HARDN_STATUS "info" "Container detected — skipping SSH install/service management."
  return 0 2>/dev/null || hardn_module_exit 0
fi

# --- Install function (soft-fail) ---
install_openssh() {
  if command -v sshd >/dev/null 2>&1; then
    HARDN_STATUS "info" "sshd already present; skipping package install."
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y >/dev/null 2>&1 || HARDN_STATUS "warning" "apt-get update failed; continuing"
    apt-get install -y openssh-server >/dev/null 2>&1 || HARDN_STATUS "warning" "openssh-server install failed; continuing"
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y install openssh-server >/dev/null 2>&1 || HARDN_STATUS "warning" "dnf install failed; continuing"
  elif command -v yum >/dev/null 2>&1; then
    yum -y install openssh-server >/dev/null 2>&1 || HARDN_STATUS "warning" "yum install failed; continuing"
  elif command -v pacman >/dev/null 2>&1; then
    pacman -S --noconfirm openssh >/dev/null 2>&1 || HARDN_STATUS "warning" "pacman install failed; continuing"
  elif command -v zypper >/dev/null 2>&1; then
    zypper -n install openssh >/dev/null 2>&1 || HARDN_STATUS "warning" "zypper install failed; continuing"
  else
    HARDN_STATUS "warning" "Unsupported package manager; please install OpenSSH manually."
  fi
}

install_openssh

# --- Figure out the service name (don’t hard-fail) ---
SERVICE_NAME=""
if is_systemd_available; then
  if systemctl list-unit-files | grep -q '^ssh\.service'; then
    SERVICE_NAME="ssh.service"
  elif systemctl list-unit-files | grep -q '^sshd\.service'; then
    SERVICE_NAME="sshd.service"
  else
    # Try to infer from binary presence
    command -v sshd >/dev/null 2>&1 && SERVICE_NAME="ssh.service"
  fi
else
  # SysV fallback (don’t fail if missing)
  [[ -f /etc/init.d/ssh  ]] && SERVICE_NAME="ssh"
  [[ -z "$SERVICE_NAME" && -f /etc/init.d/sshd ]] && SERVICE_NAME="sshd"
fi

if [[ -z "$SERVICE_NAME" ]]; then
  HARDN_STATUS "warning" "Could not determine SSH service name; skipping service enable/start."
else
  HARDN_STATUS "info" "Enabling/starting SSH service: $SERVICE_NAME"
  safe_systemctl enable "$SERVICE_NAME" || true
  safe_systemctl start  "$SERVICE_NAME" || true

  if pgrep -x sshd >/dev/null 2>&1 || safe_systemctl is-active "$SERVICE_NAME" --quiet; then
    HARDN_STATUS "pass" "SSH daemon appears to be running."
  else
    HARDN_STATUS "warning" "SSH daemon not detected running; this is non-fatal."
  fi
fi

# --- No hardening changes (on purpose) ---
SSHD_CONFIG="/etc/ssh/sshd_config"
if [[ -f "$SSHD_CONFIG" ]]; then
  HARDN_STATUS "info" "Leaving PasswordAuthentication/PermitRootLogin unchanged (desktop/VM safe)."
else
  HARDN_STATUS "info" "No sshd_config found yet (package may not have installed); skipping."
fi

# --- Gentle restart if we actually have a service name ---
[[ -n "$SERVICE_NAME" ]] && safe_systemctl restart "$SERVICE_NAME" || true

HARDN_STATUS "pass" "OpenSSH module finished (light, non-blocking)."
# -------- Continue section --------
return 0 2>/dev/null || hardn_module_exit 0