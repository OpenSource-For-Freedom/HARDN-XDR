#!/bin/bash
# Module: process_protection_light.sh — desktop/VM safe, non-blocking

# Resolve repo install or source tree layout
COMMON_CANDIDATES=(
  "/usr/lib/hardn-xdr/src/setup/hardn-common.sh"
  "$(dirname "$(readlink -f "$0")")/../hardn-common.sh"
)
for c in "${COMMON_CANDIDATES[@]}"; do
  [[ -r "$c" ]] && . "$c" && break
done
type -t HARDN_STATUS >/dev/null 2>&1 || { echo "[WARN] hardn-common.sh not found"; HARDN_STATUS(){ echo "$(date '+%F %T') - [$1] $2"; }; }
type -t hardn_module_exit >/dev/null 2>&1 || hardn_module_exit(){ exit "${1:-0}"; }

MODULE_NAME="Process Protection"
CONFIG_DIR="/etc/hardn-xdr/process-protection"
LOG_FILE="/var/log/security/process-protection.log"

# Env toggles (defaults safe for desktops/VMs)
# HARDN_PP_AUDIT: off|on (default: off)
# HARDN_PROFILE: if set to 'desktop' or 'vm', audit stays off unless explicitly on
PP_AUDIT="${HARDN_PP_AUDIT:-off}"

# Desktop/VM detection (soft)
is_desktop_vm=false
if command -v systemctl >/dev/null 2>&1 && \
   (systemctl is-active --quiet gdm3 || systemctl is-active --quiet gdm || \
    systemctl is-active --quiet lightdm || systemctl is-active --quiet sddm); then
  is_desktop_vm=true
elif [[ -n "$DISPLAY" || -n "$XDG_SESSION_TYPE" || "${HARDN_PROFILE,,}" =~ ^(desktop|vm)$ ]]; then
  is_desktop_vm=true
fi

process_protection_setup() {
  HARDN_STATUS "info" "Setting up ${MODULE_NAME} (audit=${PP_AUDIT}${is_desktop_vm:+, desktop/vm detected})"

  # Skip if not root (gracefully handle non-root in CI)
  if type -t require_root_or_skip >/dev/null 2>&1; then
    require_root_or_skip || { HARDN_STATUS "info" "Not root; skipping"; return 0; }
  elif [[ $EUID -ne 0 ]]; then
    HARDN_STATUS "info" "Not root; skipping"
    return 0
  fi

  # Create dirs
  mkdir -p "$CONFIG_DIR" "$(dirname "$LOG_FILE")"

  # Write simple config (idempotent)
  cat > "$CONFIG_DIR/injection-rules.conf" <<'EOF'
# Process injection detection rules
MONITOR_PTRACE=true
MONITOR_PROC_MEM=true
MONITOR_DYNAMIC_LIBRARIES=true
EOF

  # Optional runtime audit rules (off by default; off on desktops unless forced)
  if [[ "$PP_AUDIT" == "on" && "$is_desktop_vm" != true ]]; then
    if command -v auditctl >/dev/null 2>&1 && auditctl -l >/dev/null 2>&1; then
      # ptrace (both arches); soft-fail and do NOT harden persistently here
      auditctl -a always,exit -F arch=b64 -S ptrace -k process_injection 2>/dev/null || true
      auditctl -a always,exit -F arch=b32 -S ptrace -k process_injection 2>/dev/null || true
      HARDN_STATUS "info" "Runtime audit rules added (ptrace)."
    else
      HARDN_STATUS "info" "auditd not active/available; skipping audit rules."
    fi
  else
    [[ "$PP_AUDIT" == "on" && "$is_desktop_vm" == true ]] && \
      HARDN_STATUS "info" "Desktop/VM detected — not adding ptrace audit rules (too noisy)."
  fi

  HARDN_STATUS "pass" "${MODULE_NAME} setup completed (light mode)"
  return 0
}

# Run if executed directly or sourced
process_protection_setup

# Continue chain regardless
return 0 2>/dev/null || hardn_module_exit 0