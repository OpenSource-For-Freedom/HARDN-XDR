#!/bin/bash
# Module: yara_light.sh — desktop/VM safe, non-blocking

# Common + fallbacks
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
  safe_package_install(){ return 1; } # fallback no-op
}

# ---- Config knobs (env overridable) ----
# HARDN_YARA_MODE: off | light | full   (default: light)
YARA_MODE="${HARDN_YARA_MODE:-light}"
# HARDN_YARA_RULES: none | basic | github (default: basic in light mode)
YARA_RULES="${HARDN_YARA_RULES:-}"
[[ -z "$YARA_RULES" && "$YARA_MODE" = "light" ]] && YARA_RULES="basic"
[[ -z "$YARA_RULES" && "$YARA_MODE" = "full"  ]] && YARA_RULES="github"
# Timeouts to avoid hanging builds
CURL_TIMEOUT="${HARDN_CURL_TIMEOUT:-20}"
GIT_LOW_SPEED="${HARDN_GIT_LOW_SPEED:-50}"       # bytes/s
GIT_LOW_TIME="${HARDN_GIT_LOW_TIME:-15}"         # seconds

# ---- Early exits ----
if [[ "$YARA_MODE" == "off" ]]; then
  HARDN_STATUS "info" "YARA module disabled via HARDN_YARA_MODE=off"
  return 0 2>/dev/null || hardn_module_exit 0
fi

if is_container_environment; then
  HARDN_STATUS "info" "Container detected — skipping YARA (usually unnecessary in images/CI)."
  return 0 2>/dev/null || hardn_module_exit 0
fi

# ---- Install YARA (soft-fail, never break build) ----
install_yara() {
  HARDN_STATUS "info" "Installing YARA (soft-fail)…"
  if command -v yara >/dev/null 2>&1; then
    HARDN_STATUS "info" "YARA already present."
    return 0
  fi
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y yara >/dev/null 2>&1 || true
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y install yara >/dev/null 2>&1 || true
  elif command -v yum >/dev/null 2>&1; then
    yum -y install yara >/dev/null 2>&1 || true
  else
    # Try the project’s safe installer if available
    safe_package_install yara || true
  fi
  if command -v yara >/dev/null 2>&1; then
    HARDN_STATUS "pass" "YARA installed."
    return 0
  else
    HARDN_STATUS "warning" "YARA not available after install attempts; continuing without it."
    return 1
  fi
}

# ---- Minimal rules setup (no heavy downloads by default) ----
prepare_rules_dir() {
  install -d -m 0755 /etc/yara/rules
  if [[ ! -f /etc/yara/rules/README.hardn ]]; then
    cat >/etc/yara/rules/README.hardn <<'EOF'
HARDN-XDR YARA rules
--------------------
Place additional .yar files here. This image/module runs in "light" mode by default:
- No scheduled scans
- No Suricata/rkhunter integration by default
- Optional small ruleset if enabled via HARDN_YARA_RULES

To enable more rules or scanning, set:
  HARDN_YARA_MODE=full and/or HARDN_YARA_RULES=github
EOF
    chmod 0644 /etc/yara/rules/README.hardn
  fi
}

download_basic_rules() {
  command -v curl >/dev/null 2>&1 || { HARDN_STATUS "info" "curl missing; skipping basic rules"; return 1; }
  HARDN_STATUS "info" "Fetching a small basic ruleset (bounded timeout)…"
  # Small, representative set; safe for desktops
  curl -fsSL --max-time "$CURL_TIMEOUT" https://raw.githubusercontent.com/Yara-Rules/rules/master/malware/MALW_Eicar.yar \
    -o /etc/yara/rules/MALW_Eicar.yar >/dev/null 2>&1 || true
  curl -fsSL --max-time "$CURL_TIMEOUT" https://raw.githubusercontent.com/Neo23x0/signature-base/master/yara/gen_crypto_signatures.yar \
    -o /etc/yara/rules/gen_crypto_signatures.yar >/dev/null 2>&1 || true
  ls -1 /etc/yara/rules/*.yar >/dev/null 2>&1 && HARDN_STATUS "pass" "Basic rules in place." || HARDN_STATUS "info" "No basic rules fetched (network/timeout)."
  return 0
}

download_github_rules() {
  command -v git >/dev/null 2>&1 || { HARDN_STATUS "info" "git missing; skipping github rules"; return 1; }
  local tmp; tmp="$(mktemp -d -t yara-rules-XXXXXX)"
  HARDN_STATUS "info" "Cloning YARA-Rules (shallow, bounded)…"
  GIT_CONFIG_PARAMETERS="http.lowSpeedLimit=$GIT_LOW_SPEED http.lowSpeedTime=$GIT_LOW_TIME" \
  git -c http.lowSpeedLimit="$GIT_LOW_SPEED" -c http.lowSpeedTime="$GIT_LOW_TIME" \
      clone --depth 1 https://github.com/Yara-Rules/rules "$tmp" >/dev/null 2>&1 || {
        HARDN_STATUS "warning" "Clone failed/slow; skipping github rules."
        rm -rf "$tmp"
        return 1
      }
  find "$tmp" -type f -name '*.yar' -maxdepth 3 -print0 | xargs -0 -I{} cp "{}" /etc/yara/rules/ 2>/dev/null || true
  rm -rf "$tmp"
  HARDN_STATUS "pass" "Copied available .yar files from github (if any)."
  return 0
}

# ---- Do nothing that integrates/scan by default (light!) ----
# (Suricata edits, rkhunter chaining, or scheduled scans can be opt-in later)

yara_module() {
  HARDN_STATUS "info" "YARA module (mode: ${YARA_MODE}, rules: ${YARA_RULES:-none}) starting…"

  install_yara || true
  prepare_rules_dir

  case "$YARA_RULES" in
    none|"")  HARDN_STATUS "info" "Skipping rules download (HARDN_YARA_RULES=none).";;
    basic)    download_basic_rules || true ;;
    github)   download_github_rules || true ;;
    *)        HARDN_STATUS "warning" "Unknown HARDN_YARA_RULES='$YARA_RULES' — skipping downloads." ;;
  esac

  HARDN_STATUS "pass" "YARA light setup complete (no scans scheduled, no integrations)."
  return 0
}

# Execute when sourced/run
yara_module

# ---- Continue section (always) ----
return 0 2>/dev/null || hardn_module_exit 0
# (No `set -e` — we never want to halt the chain)