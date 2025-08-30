#!/bin/bash
# Module: pakos_light.sh — safe, opt-in PakOS tweaks

# Common includes (graceful fallback)
source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
  HARDN_STATUS(){ echo "$(date '+%F %T') - [$1] $2"; }
  is_container_environment(){ [[ -f /.dockerenv || -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null; }
  is_systemd_available(){ [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1; }
  hardn_module_exit(){ exit "${1:-0}"; }
}

# Env toggles (all opt-in)
# PAKOS_DETECTED=1         → enable this module
# PAKOS_SET_TZ=true        → set timezone to Asia/Karachi
# PAKOS_APT_UPDATE=true    → run apt update (if apt exists)

pakos_main() {
  HARDN_STATUS "info" "PakOS helper starting…"

  # Gate: only act when explicitly enabled
  if [[ "${PAKOS_DETECTED:-0}" != "1" ]]; then
    HARDN_STATUS "info" "PAKOS_DETECTED!=1 — skipping PakOS-specific configuration."
    return 0
  fi

  # Skip in containers
  if is_container_environment; then
    HARDN_STATUS "info" "Container detected — skipping PakOS configuration."
    return 0
  fi

  # Read PRETTY_NAME (best-effort)
  . /etc/os-release 2>/dev/null
  local pretty="${PRETTY_NAME:-Unknown}"
  HARDN_STATUS "pass" "PakOS detected: ${pretty}"

  configure_pakos_repositories
  configure_pakos_localization
  configure_pakos_security

  HARDN_STATUS "pass" "PakOS configuration complete (light mode)."
  return 0
}

configure_pakos_repositories() {
  HARDN_STATUS "info" "Checking PakOS package repositories…"
  if command -v apt >/dev/null 2>&1; then
    if [[ "${PAKOS_APT_UPDATE:-false}" == "true" ]]; then
      HARDN_STATUS "info" "Running apt update (opt-in)…"
      apt update -y >/dev/null 2>&1 && \
        HARDN_STATUS "pass" "Package cache updated." || \
        HARDN_STATUS "warning" "apt update failed (non-fatal)."
    else
      HARDN_STATUS "info" "PAKOS_APT_UPDATE not set — skipping apt update."
    fi
  fi
}

configure_pakos_localization() {
  HARDN_STATUS "info" "Configuring PakOS localization (light)…"

  # Timezone (opt-in only)
  if [[ "${PAKOS_SET_TZ:-false}" == "true" ]]; then
    if is_systemd_available && command -v timedatectl >/dev/null 2>&1; then
      if [[ "$(timedatectl show -p Timezone --value 2>/dev/null)" != "Asia/Karachi" ]]; then
        HARDN_STATUS "info" "Setting timezone to Asia/Karachi (opt-in)…"
        timedatectl set-timezone Asia/Karachi >/dev/null 2>&1 && \
          HARDN_STATUS "pass" "Timezone set to Asia/Karachi." || \
          HARDN_STATUS "warning" "Failed to set timezone (non-fatal)."
      else
        HARDN_STATUS "info" "Timezone already Asia/Karachi."
      fi
    else
      HARDN_STATUS "info" "timedatectl/systemd not available — skipping TZ change."
    fi
  else
    HARDN_STATUS "info" "PAKOS_SET_TZ not set — keeping existing timezone."
  fi

  # Urdu locale presence (informational only)
  if command -v locale >/dev/null 2>&1; then
    if locale -a 2>/dev/null | grep -q '^ur_PK'; then
      HARDN_STATUS "info" "Urdu locale (ur_PK) available."
    else
      HARDN_STATUS "info" "Urdu locale not installed (informational only)."
    fi
  fi
}

configure_pakos_security() {
  HARDN_STATUS "info" "Verifying PakOS security auto-updates (informational)…"
  if [[ -f /etc/apt/apt.conf.d/50unattended-upgrades ]]; then
    HARDN_STATUS "info" "unattended-upgrades present."
  else
    HARDN_STATUS "info" "unattended-upgrades not found (no change made)."
  fi
}

# Export functions for other modules (optional)
export -f configure_pakos_repositories
export -f configure_pakos_localization
export -f configure_pakos_security

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  pakos_main "$@"
fi

# Continue chain regardless
return 0 2>/dev/null || hardn_module_exit 0