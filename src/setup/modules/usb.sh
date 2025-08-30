#!/bin/bash
# Module: usb_storage_block_light.sh — block USB mass storage safely (desktop/VM friendly)

# --- Common includes (graceful fallback) ---
COMMON_CANDIDATES=(
  "/usr/lib/hardn-xdr/src/setup/hardn-common.sh"
  "$(dirname "$(readlink -f "$0")")/../hardn-common.sh"
)
for c in "${COMMON_CANDIDATES[@]}"; do
  [[ -r "$c" ]] && . "$c" && break
done
type -t HARDN_STATUS >/dev/null 2>&1 || { echo "[WARN] hardn-common.sh not found; continuing"; HARDN_STATUS(){ echo "$(date '+%F %T') - [$1] $2"; }; }
type -t hardn_module_exit >/dev/null 2>&1 || hardn_module_exit(){ exit "${1:-0}"; }
type -t is_container >/dev/null 2>&1 || is_container(){ [[ -f /.dockerenv || -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null; }

# --- Require root; skip in containers (never fail the chain) ---
type -t require_root_or_skip >/dev/null 2>&1 && require_root_or_skip || { HARDN_STATUS "info" "Not root; skipping"; return 0 2>/dev/null || hardn_module_exit 0; }
if is_container; then
  HARDN_STATUS "info" "Container detected — skipping USB storage policy"
  return 0 2>/dev/null || hardn_module_exit 0
fi

# --- Helpers ---
is_root_on_usb() {
  local src dev parent tran
  src="$(findmnt -no SOURCE / 2>/dev/null)" || return 1
  src="$(readlink -f "$src")"
  # Walk to the parent disk that has TRAN info
  dev="$src"
  parent="$(lsblk -no PKNAME "$dev" 2>/dev/null)"
  [[ -n "$parent" ]] && dev="/dev/$parent"
  tran="$(lsblk -no TRAN "$dev" 2>/dev/null)"
  # If TRAN empty (LVM/crypto), try the top-most physical parent
  if [[ -z "$tran" ]]; then
    dev="$(lsblk -pno NAME,TYPE "$src" | awk '$2=="disk"{print $1; exit}')"
    [[ -n "$dev" ]] && tran="$(lsblk -no TRAN "$dev" 2>/dev/null)"
  fi
  [[ "$tran" == "usb" ]]
}

# --- Config knobs (env overridable) ---
# HARDN_USB_MODE: off|light|strict (default: light)
USB_MODE="${HARDN_USB_MODE:-light}"
# HARDN_USB_ENFORCE_NOW=true → try to unload usb_storage/uas immediately (safe no-op if busy)
ENFORCE_NOW="${HARDN_USB_ENFORCE_NOW:-false}"

# --- Early outs / safety checks ---
if [[ "$USB_MODE" == "off" ]]; then
  HARDN_STATUS "info" "USB storage policy disabled (HARDN_USB_MODE=off)"
  return 0 2>/dev/null || hardn_module_exit 0
fi

if is_root_on_usb; then
  HARDN_STATUS "warning" "Root filesystem is on USB — skipping USB storage blacklist to avoid lockout."
  return 0 2>/dev/null || hardn_module_exit 0
fi

# --- Write modprobe blacklist (takes effect on next boot) ---
install -d -m 0755 /etc/modprobe.d
cat > /etc/modprobe.d/99-usb-storage.conf <<'EOF'
# HARDN-XDR: block USB mass storage drivers (light/strict modes)
blacklist usb-storage
blacklist uas
EOF
chmod 0644 /etc/modprobe.d/99-usb-storage.conf
HARDN_STATUS "pass" "Prepared /etc/modprobe.d/99-usb-storage.conf (applies on next boot)."

# (Remove empty udev file; we don't need it)
[[ -f /etc/udev/rules.d/99-usb-storage.rules ]] && rm -f /etc/udev/rules.d/99-usb-storage.rules

# --- Keep HID working (ensure usbhid present) ---
if ! lsmod | grep -q '^usbhid'; then
  modprobe usbhid >/dev/null 2>&1 && HARDN_STATUS "pass" "usbhid module loaded." || HARDN_STATUS "info" "usbhid not loaded (may be built-in); continuing."
else
  HARDN_STATUS "info" "usbhid already active."
fi

# --- Optional immediate enforcement (non-fatal) ---
if [[ "$ENFORCE_NOW" == "true" ]]; then
  HARDN_STATUS "info" "Attempting immediate unload of usb mass storage drivers…"
  # Try uas first (can hold the device), then usb_storage
  rmmod uas       >/dev/null 2>&1 || true
  rmmod usb_storage >/dev/null 2>&1 || true
  udevadm control --reload-rules >/dev/null 2>&1 || true
  udevadm trigger                >/dev/null 2>&1 || true
  HARDN_STATUS "info" "Immediate enforcement attempted (devices in use may remain until reboot)."
else
  HARDN_STATUS "info" "No immediate unload (desktop/VM safe). Policy will apply after reboot."
fi

# --- Summary & continue ---
HARDN_STATUS "pass" "USB policy set: mass storage blocked on next boot; HID preserved."
return 0 2>/dev/null || hardn_module_exit 0