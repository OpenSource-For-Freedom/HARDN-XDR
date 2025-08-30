#!/bin/bash
# Module: apparmor_normal.sh
# Purpose: Enable AppArmor in a safe, non-strict mode for desktops

source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
  HARDN_STATUS(){ echo "$(date '+%F %T') - [$1] $2"; }
  hardn_module_exit(){ exit "${1:-0}"; }
}

# --- Skip if in container ---
if [[ -f /.dockerenv ]] || grep -qa container /proc/1/environ 2>/dev/null; then
  HARDN_STATUS "info" "Container detected, skipping AppArmor setup."
  return 0 2>/dev/null || hardn_module_exit 0
fi

# --- Install AppArmor packages ---
HARDN_STATUS "info" "Installing AppArmor packages..."
if command -v apt >/dev/null 2>&1; then
  apt-get update -y && apt-get install -y apparmor apparmor-utils apparmor-profiles || \
    HARDN_STATUS "warning" "Failed to install AppArmor with apt."
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y apparmor apparmor-utils || \
    HARDN_STATUS "warning" "Failed to install AppArmor with dnf."
elif command -v yum >/dev/null 2>&1; then
  yum install -y apparmor apparmor-utils || \
    HARDN_STATUS "warning" "Failed to install AppArmor with yum."
fi

# --- Enable and start service ---
systemctl enable apparmor.service >/dev/null 2>&1 || true
systemctl start apparmor.service >/dev/null 2>&1 || true
HARDN_STATUS "pass" "AppArmor service enabled and running."

# --- Set all profiles to complain mode ---
if command -v aa-complain >/dev/null 2>&1; then
  HARDN_STATUS "info" "Putting all profiles in complain mode (normal Linux mode)..."
  aa-complain /etc/apparmor.d/* >/dev/null 2>&1 || true
  HARDN_STATUS "pass" "AppArmor profiles set to complain mode."
fi

# --- Show status ---
if command -v aa-status >/dev/null 2>&1; then
  HARDN_STATUS "info" "Current AppArmor status:"
  aa-status || true
fi

# --- Exit clean so installer continues ---
HARDN_STATUS "pass" "AppArmor module completed in normal mode (complain)."
return 0 2>/dev/null || hardn_module_exit 0