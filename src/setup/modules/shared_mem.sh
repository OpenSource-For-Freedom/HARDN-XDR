#!/bin/bash
# Module: shm_hardening_light.sh — safe for desktops/VMs

source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
  HARDN_STATUS(){ echo "$(date '+%F %T') - [$1] $2"; }
  is_systemd_available(){ [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1; }
  hardn_module_exit(){ exit "${1:-0}"; }
}

HARDN_STATUS "info" "Securing shared memory (light mode)…"

# Detect desktop/VM (keep exec by default)
DESKTOP_VM=false
if is_systemd_available && (systemctl is-active --quiet gdm3 || systemctl is-active --quiet gdm || \
    systemctl is-active --quiet lightdm || systemctl is-active --quiet sddm); then
  DESKTOP_VM=true
elif [[ -n "$DISPLAY" || -n "$XDG_SESSION_TYPE" || "${HARDN_PROFILE,,}" =~ ^(desktop|vm)$ ]]; then
  DESKTOP_VM=true
fi

mountpoint="/dev/shm"
current_opts="$(findmnt -no OPTIONS "$mountpoint" 2>/dev/null || true)"

# Decide options
base_opts="mode=1777,strictatime,nosuid,nodev"
if [[ "${HARDN_SHM_STRICT:-false}" == "true" && "$DESKTOP_VM" != "true" ]]; then
  desired_opts="$base_opts,noexec"
else
  desired_opts="$base_opts"  # keep exec on desktop/VM by default
fi

# If already compliant enough, do nothing
needs_change=true
if [[ -n "$current_opts" ]]; then
  # Check we at least have nosuid,nodev; noexec is optional unless STRICT=true
  if [[ "$current_opts" == *"nosuid"* && "$current_opts" == *"nodev"* ]]; then
    if [[ "$desired_opts" == *"noexec"* && "$current_opts" != *"noexec"* ]]; then
      needs_change=true
    else
      needs_change=false
    fi
  fi
fi

if ! is_systemd_available; then
  # Non-systemd: do not touch /etc/fstab automatically to avoid boot issues
  if [[ "$needs_change" == true ]]; then
    HARDN_STATUS "warning" "Non-systemd system: not editing /etc/fstab automatically."
    HARDN_STATUS "info"    "Recommend adding an /etc/fstab line for /dev/shm with: $desired_opts"
  else
    HARDN_STATUS "pass" "Shared memory already has nosuid,nodev; no changes needed."
  fi
  HARDN_STATUS "pass" "Shared memory hardening (light) complete."
  return 0 2>/dev/null || hardn_module_exit 0
fi

# Systemd: write a drop-in (no immediate remount/restart)
install -d -m 0755 /etc/systemd/system/dev-shm.mount.d
cat > /etc/systemd/system/dev-shm.mount.d/override.conf <<EOF
[Mount]
Options=$desired_opts
EOF
chmod 0644 /etc/systemd/system/dev-shm.mount.d/override.conf

HARDN_STATUS "pass" "Configured /dev/shm via systemd drop-in (override.conf)."
HARDN_STATUS "info" "No remount now (desktop-safe). It will apply on next boot."
HARDN_STATUS "info" "To apply immediately (optional): systemctl daemon-reload && systemctl restart dev-shm.mount"

HARDN_STATUS "pass" "Shared memory hardening completed (light mode)."
return 0 2>/dev/null || hardn_module_exit 0
# (No set -e here — we always continue)