#!/bin/bash
# Module: lynis_pwquality_only.sh — install only what Lynis needs

# --- Common includes with graceful fallback ---
source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
  HARDN_STATUS(){ echo "$(date '+%F %T') - [$1] $2"; }
  check_root(){ [[ $EUID -eq 0 ]]; }
  is_container_environment(){ [[ -f /.dockerenv || -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null; }
  hardn_module_exit(){ exit "${1:-0}"; }
}

# --- Safety: root + non-container (but never fail the chain) ---
check_root || { HARDN_STATUS "info" "Not root; skipping pwquality install."; return 0 2>/dev/null || hardn_module_exit 0; }
is_container_environment && { HARDN_STATUS "info" "Container detected; skipping pwquality install."; return 0 2>/dev/null || hardn_module_exit 0; }

# If Lynis isn't present, do nothing (install only when useful)
if ! command -v lynis >/dev/null 2>&1; then
  HARDN_STATUS "info" "Lynis not found; skipping pwquality dependency install."
  return 0 2>/dev/null || hardn_module_exit 0
fi

HARDN_STATUS "info" "Installing only what Lynis needs: pwquality (no PAM changes)."
if command -v pwscore >/dev/null 2>&1; then
  HARDN_STATUS "pass" "pwquality tools already present."
  return 0 2>/dev/null || hardn_module_exit 0
fi


if command -v apt-get >/dev/null 2>&1; then
  apt-get update -y >/dev/null 2>&1 || true
  apt-get install -y libpam-pwquality >/dev/null 2>&1 || true
elif command -v dnf >/dev/null 2>&1; then
  dnf -y install pam_pwquality >/dev/null 2>&1 || true
elif command -v yum >/dev/null 2>&1; then
  yum -y install pam_pwquality >/dev/null 2>&1 || true
elif command -v zypper >/dev/null 2>&1; then
  zypper -n install pam-config cracklib-dict-full pam >/dev/null 2>&1 || true
else

  type -t safe_package_install >/dev/null 2>&1 && safe_package_install libpam-pwquality || true
fi
if command -v pwscore >/dev/null 2>&1; then
  HARDN_STATUS "pass" "pwquality installed (meets Lynis dependency). No configuration changes applied."
else
  HARDN_STATUS "warning" "Could not confirm pwquality tools; Lynis may flag AUTH policy tests. (Non-fatal)"
fi

return 0 2>/dev/null || hardn_module_exit 0