#!/usr/bin/env bash
# HARDN-XDR main<
set -euo pipefail

HARDN_VERSION="1.1.63"
export APT_LISTBUGS_FRONTEND=none

# ------------------------------------------------------------
# Logging & env defaults 
# ------------------------------------------------------------
HARDN_LOG_FILE="${HARDN_LOG_FILE:-/var/log/hardn-xdr.log}"

: "${CI:=}"
: "${GITHUB_ACTIONS:=}"
: "${GITLAB_CI:=}"
: "${DEBIAN_FRONTEND:=noninteractive}"
: "${SKIP_WHIPTAIL:=}"
: "${HARDN_CONTAINER_MODE:=}"
: "${HARDN_CONTAINER_VM_MODE:=}"      # used by VM/container detection
: "${PAKOS_DETECTED:=0}"
: "${ID:=Unknown}"
: "${AUTO_MODE:=}"
: "${CI_MODE:=}"                      # set by --ci
: "${HARDN_DOCKER_MODE:=}"            # set inside container
: "${HARDN_DOCKER_FIREWALL:=}"        # used by docker runs
: "${HARDN_MODULE_DIR:=/usr/lib/hardn-xdr/src/setup/modules}"

# Discovered Safe terminal width (works in CI/cron)
get_terminal_width() {
  local cols="${COLUMNS:-80}"
  if command -v tput >/dev/null 2>&1; then
    if local tcols; tcols=$(tput cols 2>/dev/null); then
      cols="$tcols"
    fi
  fi
  echo "$cols"
}

HARDN_LOG() {
  local message
  message="$(date '+%Y-%m-%d %H:%M:%S') - $*"
  if [[ -w "$(dirname "$HARDN_LOG_FILE")" ]] 2>/dev/null; then
    echo "$message" >> "$HARDN_LOG_FILE"
  else
    echo "$message"
  fi
}

# Auto-detect non-interactive/CI
if [[ -n "$CI" || -n "$GITHUB_ACTIONS" || -n "$GITLAB_CI" || ! -t 0 ]]; then
  export SKIP_WHIPTAIL=1
  echo "[INFO] CI environment detected, running in non-interactive mode"
  HARDN_LOG "CI environment detected, running in non-interactive mode"
fi

# ------------------------------------------------------------
# Common 
# ------------------------------------------------------------
if [[ -f /usr/lib/hardn-xdr/src/setup/hardn-common.sh ]]; then
  # shellcheck disable=SC1091
  source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
elif [[ -f "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/hardn-common.sh" ]]; then
  # Development/CI fallback path
  # shellcheck disable=SC1091
  source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/hardn-common.sh"
else
  # Minimal fallbacks so script still works
  HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
  check_root() { [[ $EUID -eq 0 ]]; }
  is_installed() {
    command -v "$1" >/dev/null 2>&1 || dpkg -s "$1" >/dev/null 2>&1
  }
  hardn_yesno() { [[ "$SKIP_WHIPTAIL" == "1" ]] && return 0; return 0; }
  hardn_msgbox() { echo "Info: $1" >&2; }
  is_container_environment() {
    [[ -n "$CI" ]] || [[ -n "$GITHUB_ACTIONS" ]] || [[ -f /.dockerenv ]] || \
    [[ -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null
  }
  is_systemd_available() { [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1; }
fi

# Ensure helpers exist even if common defined some but not others
type -t is_container_environment >/dev/null 2>&1 || \
is_container_environment() { [[ -f /.dockerenv || -f /run/.containerenv ]]; }

type -t is_systemd_available >/dev/null 2>&1 || \
is_systemd_available() { [[ -d /run/systemd/system ]]; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_DEBIAN_VERSION_ID=""
CURRENT_DEBIAN_CODENAME=""

check_root() {
  [[ $EUID -eq 0 ]] || { HARDN_STATUS "error" "Please run as root."; exit 1; }
}

show_system_info() {
  HARDN_STATUS "info" "HARDN-XDR v${HARDN_VERSION} - System Information"
  HARDN_STATUS "info" "================================================"
  HARDN_STATUS "info" "Script Version: ${HARDN_VERSION}"
  HARDN_STATUS "info" "Target OS: Debian-based systems (Debian 12+, Ubuntu 24.04+, PakOS)"
  if [[ -n "${CURRENT_DEBIAN_VERSION_ID}" && -n "${CURRENT_DEBIAN_CODENAME}" ]]; then
    HARDN_STATUS "info" "Detected OS: ${ID:-Unknown} ${CURRENT_DEBIAN_VERSION_ID} (${CURRENT_DEBIAN_CODENAME})"
    [[ "${PAKOS_DETECTED:-0}" == "1" ]] && HARDN_STATUS "info" "PakOS Support: Enabled (Debian-derivative compatibility mode)"
  fi
  HARDN_STATUS "info" "Features: STIG Compliance, Malware Detection, System Hardening"
}

# ------------------------------------------------------------
# ASCII banner 
# ------------------------------------------------------------
print_ascii_banner() {
  local terminal_width banner banner_width padding
  terminal_width="$(get_terminal_width)"
  banner=$(cat << "EOF"

   ▄█    █▄            ▄████████         ▄████████      ████████▄       ███▄▄▄▄
  ███    ███          ███    ███        ███    ███      ███   ▀███      ███▀▀▀██▄
  ███    ███          ███    ███        ███    ███      ███    ███      ███   ███
 ▄███▄▄▄▄███▄▄        ███    ███       ▄███▄▄▄▄██▀      ███    ███      ███   ███
▀▀███▀▀▀▀███▀       ▀███████████      ▀▀███▀▀▀▀▀        ███    ███      ███   ███
  ███    ███          ███    ███      ▀███████████      ███    ███      ███   ███
  ███    ███          ███    ███        ███    ███      ███   ▄███      ███   ███
  ███    █▀           ███    █▀         ███    ███      ████████▀        ▀█   █▀
                                        ███    ███

                            Extended Detection and Response
                            by Security International Group

EOF
)
  banner_width=$(echo "$banner" | awk '{print length}' | sort -n | tail -1)
  padding=$(( (terminal_width - banner_width) / 2 ))
  printf "\033[1;32m"
  while IFS= read -r line; do
    printf "%*s%s\n" "$padding" "" "$line"
  done <<< "$banner"
  printf "\033[0m"
  sleep 2
}

welcomemsg() {
  HARDN_STATUS "info" ""
  HARDN_STATUS "info" "HARDN-XDR v${HARDN_VERSION} - Linux Security Hardening Sentinel"
  HARDN_STATUS "info" "================================================================"
  hardn_msgbox "Welcome to HARDN-XDR v${HARDN_VERSION} - A Debian Security tool for System Hardening\n\nThis will apply STIG compliance, security tools, and comprehensive system hardening." 12 70
  HARDN_STATUS "info" ""
  HARDN_STATUS "info" "This installer will update your system first..."
  if hardn_yesno "Do you want to continue with the installation?" 10 60; then
    return 0
  else
    HARDN_STATUS "error" "Installation cancelled by user."
    exit 1
  fi
}

update_system_packages() {
  HARDN_STATUS "info" "Updating system packages..."
  if DEBIAN_FRONTEND=noninteractive timeout 60s apt-get -o Acquire::ForceIPv4=true update -y; then
    HARDN_STATUS "pass" "System package list updated successfully."
  else
    HARDN_STATUS "warning" "apt-get update failed or timed out after 60s. Continuing..."
  fi
}

install_package_dependencies() {
  HARDN_STATUS "info" "Installing required package dependencies..."
  local packages=(
    whiptail apt-transport-https ca-certificates curl gnupg lsb-release
    git build-essential debsums
  )
  if apt-get install -y "${packages[@]}"; then
    HARDN_STATUS "pass" "Package dependencies installed successfully."
  else
    HARDN_STATUS "error" "Failed to install package dependencies. Please check your system configuration."
    exit 1
  fi
}

# ------------------------------------------------------------
# Module discovery & runner (single definitions)
# ------------------------------------------------------------
list_available_modules() {
  local DEFAULT_DIR="/usr/lib/hardn-xdr/src/setup/modules"
  local CONFIG_DIR="${HARDN_MODULE_DIR:-$DEFAULT_DIR}"
  local FALLBACK_DIR="${SCRIPT_DIR}/modules"

  if [[ -d "$CONFIG_DIR" ]]; then
    find "$CONFIG_DIR" -type f -name "*.sh" -exec basename {} \; | sort
    return
  fi
  if [[ -d "$FALLBACK_DIR" ]]; then
    HARDN_STATUS "info" "Using fallback module directory: $FALLBACK_DIR"
    find "$FALLBACK_DIR" -type f -name "*.sh" -exec basename {} \; | sort
    return
  fi
  HARDN_STATUS "warning" "No module directory found. Using static fallback list."
  HARDN_LOG "Module directory not found: $CONFIG_DIR or $FALLBACK_DIR. Using fallback list."
  echo -e "auditd.sh\nkernel_sec.sh\nsshd.sh\naide.sh\nufw.sh\nfail2ban.sh"
}

run_module() {
  local module_file="$1"
  local module_dir="${HARDN_MODULE_DIR:-/usr/lib/hardn-xdr/src/setup/modules}"
  local module_paths=(
    "$module_dir/$module_file"
    "${SCRIPT_DIR}/modules/$module_file"
  )

  for module_path in "${module_paths[@]}"; do
    if [[ -f "$module_path" ]]; then
      local real_path
      real_path="$(realpath "$module_path" 2>/dev/null)" || continue
      if [[ "$real_path" == "$module_dir"/* ]] || [[ "$real_path" == "${SCRIPT_DIR}/modules"/* ]]; then
        HARDN_STATUS "info" "Executing module: ${module_file} from ${module_path}"
        HARDN_LOG "Executing module: ${module_file} from ${module_path}"
        # shellcheck disable=SC1090
        source "$module_path"
        local rc=$?
        if [[ $rc -eq 0 ]]; then
          HARDN_LOG "Module completed successfully: $module_file"
          return 0
        else
          HARDN_STATUS "error" "Module execution failed: $module_path"
          HARDN_LOG "Module execution failed: $module_path (exit code: $rc)"
          return 1
        fi
      else
        HARDN_STATUS "warning" "Module path validation failed: $module_path"
        HARDN_LOG "Module path validation failed: $module_path"
      fi
    fi
  done

  HARDN_STATUS "error" "Module not found in any expected location: $module_file"
  for path in "${module_paths[@]}"; do HARDN_STATUS "error" "  - $path"; done
  return 1
}

# ------------------------------------------------------------
# Environment-aware module sets for image/os type
# ------------------------------------------------------------
get_container_vm_essential_modules() {
  echo "auditd.sh kernel_sec.sh sshd.sh credential_protection.sh"
  echo "auto_updates.sh file_perms.sh shared_mem.sh coredumps.sh"
  echo "network_protocols.sh process_accounting.sh debsums.sh purge_old_pkgs.sh"
  echo "banner.sh central_logging.sh audit_system.sh ntp.sh dns_config.sh"
  echo "binfmt.sh service_disable.sh stig_pwquality.sh pakos_config.sh memory_optimization.sh"
}

get_container_vm_conditional_modules() {
  echo "ufw.sh fail2ban.sh selinux.sh apparmor.sh suricata.sh yara.sh"
  echo "rkhunter.sh chkrootkit.sh unhide.sh secure_net.sh lynis_audit.sh"
}

get_desktop_focused_modules() {
  echo "usb.sh firewire.sh firejail.sh compilers.sh pentest.sh"
  echo "behavioral_analysis.sh persistence_detection.sh process_protection.sh"
  echo "deleted_files.sh unnecessary_services.sh"
}

get_docker_cve_modules() {
  echo "sshd.sh network_protocols.sh kernel_sec.sh auto_updates.sh"
  echo "purge_old_pkgs.sh debsums.sh file_perms.sh credential_protection.sh"
  echo "coredumps.sh shared_mem.sh dns_config.sh banner.sh"
  echo "audit_system.sh ntp.sh binfmt.sh process_accounting.sh"
  echo "ufw.sh fail2ban.sh"
}

get_docker_security_modules() {
  echo "auditd.sh central_logging.sh stig_pwquality.sh"
  echo "secure_net.sh service_disable.sh memory_optimization.sh"
  echo "pakos_config.sh lynis_audit.sh suricata.sh"
  echo "rkhunter.sh chkrootkit.sh unhide.sh yara.sh"
}

get_docker_detection_modules() {
  echo "behavioral_analysis.sh persistence_detection.sh"
  echo "process_protection.sh deleted_files.sh"
  echo "compliance_validation.sh backup_security.sh"
}

get_docker_advanced_modules() {
  echo "bootloader_security.sh disk_encryption.sh"
  echo "unnecesary_services.sh"
}

get_all_docker_modules() {
  echo "$(get_docker_cve_modules) $(get_docker_security_modules)"
  echo "$(get_docker_detection_modules) $(get_docker_advanced_modules)"
}

get_debian_cve_mitigation_modules() {
  echo "kernel_sec.sh file_perms.sh credential_protection.sh sshd.sh"
  echo "auto_updates.sh purge_old_pkgs.sh debsums.sh audit_system.sh"
  echo "central_logging.sh secure_net.sh ufw.sh fail2ban.sh service_disable.sh"
}

# ------------------------------------------------------------
# Detection of container/VM
# ------------------------------------------------------------
is_container_vm_environment() {
  if is_container_environment; then return 0; fi
  if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt --quiet 2>/dev/null; then
    return 0
  fi
  if [[ -d /proc/vz ]] || [[ -f /proc/user_beancounters ]] || \
     grep -qi hypervisor /proc/cpuinfo 2>/dev/null || \
     [[ -n "$HARDN_CONTAINER_VM_MODE" ]]; then
    return 0
  fi
  return 1
}

# ------------------------------------------------------------
# Docker deploy (single implementation, supports modes)
# ------------------------------------------------------------
install_docker_if_needed() {
  HARDN_STATUS "info" "Installing Docker..."
  apt-get update -y || return 1
  apt-get install -y ca-certificates curl gnupg lsb-release || return 1
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || return 1
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list || return 1
  apt-get update -y || return 1
  apt-get install -y docker-ce docker-ce-cli containerd.io || return 1
  systemctl start docker || return 1
  systemctl enable docker || return 1
  HARDN_STATUS "pass" "Docker installed successfully"
  return 0
}

run_docker_detection_modules() {
  local modules module_count=0 success_count=0
  modules=$(get_docker_detection_modules)
  HARDN_STATUS "info" "Running Docker Detection & Analysis Modules"
  HARDN_STATUS "info" "============================================"
  for module in $modules; do
    ((module_count++))
    HARDN_STATUS "info" "[$module_count] Running detection module: $module"
    if run_module "$module"; then
      ((success_count++)); HARDN_STATUS "pass" "[$module_count] Detection module $module completed successfully"
    else
      HARDN_STATUS "warning" "[$module_count] Detection module $module completed with warnings"
    fi
    sleep 1
  done
  HARDN_STATUS "info" "Docker Detection Summary: $success_count/$module_count modules completed"
  return 0
}

run_all_docker_modules() {
  HARDN_STATUS "info" "Running Complete Docker Sentinal"
  HARDN_STATUS "info" "===================================="
  run_docker_cve_modules; echo ""
  run_docker_security_modules; echo ""
  run_docker_detection_modules
  HARDN_STATUS "pass" "Complete Docker module suite finished!"
}

run_debian_cve_mitigation() {
  local modules module_count=0 success_count=0
  modules=$(get_debian_cve_mitigation_modules)
  HARDN_STATUS "info" "Debian CVE Sentinal"
  HARDN_STATUS "info" "=============================="
  HARDN_STATUS "info" "Targeting CVEs in debian:latest (glibc/systemd/coreutils/shadow/apt)"
  echo ""
  for module in $modules; do
    ((module_count++))
    HARDN_STATUS "info" "[$module_count] Applying CVE mitigation: $module"
    if run_module "$module"; then
      ((success_count++)); HARDN_STATUS "pass" "[$module_count] CVE mitigation $module completed"
    else
      HARDN_STATUS "warning" "[$module_count]  CVE mitigation $module completed with warnings"
    fi
    sleep 1
  done
  echo ""
  HARDN_STATUS "info" "Debian CVE Mitigation Summary: $success_count/$module_count modules"
  [[ $success_count -eq $module_count ]] && return 0 || return 1
}

run_docker_cve_modules() {
  local modules module_count=0 success_count=0
  modules=$(get_docker_cve_modules)
  HARDN_STATUS "info" "Running Docker CVE Mitigation Modules"
  HARDN_STATUS "info" "======================================"
  for module in $modules; do
    ((module_count++))
    HARDN_STATUS "info" "[$module_count] Running CVE mitigation module: $module"
    if run_module "$module"; then
      ((success_count++)); HARDN_STATUS "pass" "[$module_count] CVE module $module completed successfully"
    else
      HARDN_STATUS "warning" "[$module_count] CVE module $module completed with warnings"
    fi
    sleep 1
  done
  HARDN_STATUS "info" "Docker CVE Mitigation Summary: $success_count/$module_count modules completed"
  [[ $success_count -eq $module_count ]]
}

run_docker_security_modules() {
  local modules module_count=0 success_count=0
  modules=$(get_docker_security_modules)
  HARDN_STATUS "info" "Running Docker Security Hardening Modules"
  HARDN_STATUS "info" "=========================================="
  for module in $modules; do
    ((module_count++))
    HARDN_STATUS "info" "[$module_count] Running security module: $module"
    if run_module "$module"; then
      ((success_count++)); HARDN_STATUS "pass" "[$module_count] Security module $module completed successfully"
    else
      HARDN_STATUS "warning" "[$module_count] Security module $module completed with warnings"
    fi
    sleep 1
  done
  HARDN_STATUS "info" "Docker Security Hardening Summary: $success_count/$module_count modules completed"
  return 0
}

deploy_docker_hardn() {
  local mode="${1:-cve}"; shift || true
  HARDN_STATUS "info" "Deploying HARDN-XDR in Docker container (mode: $mode)..."

  if ! command -v docker >/dev/null 2>&1; then
    HARDN_STATUS "error" "Docker is not installed. Installing Docker..."
    install_docker_if_needed || return 1
  fi
  if ! docker info >/dev/null 2>&1; then
    HARDN_STATUS "error" "Docker daemon is not running. Please start Docker service."
    return 1
  fi

  local script_root docker_image results_dir container_command
  script_root="$(cd "${SCRIPT_DIR}/../.." && pwd)"
  docker_image="hardn-xdr:debian-bookworm"

  if ! docker image inspect "$docker_image" >/dev/null 2>&1; then
    HARDN_STATUS "info" "Building HARDN-XDR Docker image..."
    if [[ -f "$script_root/docker/debian-bookworm/Dockerfile" ]]; then
      docker build -f "$script_root/docker/debian-bookworm/Dockerfile" -t "$docker_image" "$script_root" || {
        HARDN_STATUS "error" "Failed to build Docker image"; return 1; }
    else
      HARDN_STATUS "error" "Docker build files not found in $script_root/docker/"
      return 1
    fi
  fi

  results_dir="/tmp/hardn-xdr-docker-results-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$results_dir"

  case "$mode" in
    cve)         container_command="run_docker_cve_modules" ;;
    security)    container_command="run_docker_security_modules" ;;
    detection)   container_command="run_docker_detection_modules" ;;
    full)        container_command="run_docker_cve_modules && echo '' && run_docker_security_modules" ;;
    all)         container_command="run_all_docker_modules" ;;
    debian-cve)  container_command="run_debian_cve_mitigation" ;;
    *)           container_command="run_docker_cve_modules" ;;
  esac

  docker run --rm \
    --name "hardn-xdr-$(date +%H%M%S)" \
    --privileged --pid=host --network=host \
    --cap-add=NET_ADMIN --cap-add=SYS_ADMIN \
    -v /etc:/host-etc -v /var:/host-var -v /usr:/host-usr:ro \
    -v /sys:/host-sys:ro -v /proc:/host-proc:ro -v /run:/host-run \
    -v "$results_dir:/results" \
    -e HARDN_DOCKER_MODE=1 -e SKIP_WHIPTAIL=1 -e CI=1 -e HARDN_DOCKER_FIREWALL=1 \
    "$docker_image" \
    bash -c "
      set -e
      cd /opt/hardn-xdr
      echo 'HARDN-XDR Docker: $mode'
      echo '============================================='
      echo 'Container Image: $docker_image'
      echo 'Results Directory: $results_dir'
      echo ''
      source /opt/hardn-xdr/src/setup/hardn-main.sh
      $container_command
      cp -r /var/log/hardn-xdr* /results/ 2>/dev/null || true
      echo ''
      echo 'HARDN-XDR Docker hardening completed!'
      echo 'Results saved to: $results_dir'
    "

  local rc=$?
  if [[ $rc -eq 0 ]]; then
    HARDN_STATUS "pass" "Docker-based HARDN-XDR hardening completed successfully!"
    HARDN_STATUS "info" "Results available in: $results_dir"
  else
    HARDN_STATUS "error" "Docker-based HARDN-XDR hardening failed (exit code: $rc)"
    return 1
  fi
}

# ------------------------------------------------------------
# Environment selection & orchestration
# ------------------------------------------------------------
setup_security_modules() {
  local environment_type modules failed_modules=0

  if is_container_vm_environment; then
    environment_type="Container/VM"
    HARDN_STATUS "info" "Container/VM environment detected - optimizing for DISA/FEDHIVE compliance"
    readarray -t modules < <(get_container_vm_essential_modules | tr ' ' '\n')

    if [[ "$SKIP_WHIPTAIL" != "1" ]]; then
      if hardn_yesno "Include additional security modules (may impact performance)?" 10 60; then
        readarray -t conditional < <(get_container_vm_conditional_modules | tr ' ' '\n')
        modules+=("${conditional[@]}")
      fi
    else
      readarray -t conditional < <(get_container_vm_conditional_modules | tr ' ' '\n')
      modules+=("${conditional[@]}")
    fi
    HARDN_STATUS "info" "Skipping desktop-focused modules for optimal container/VM performance"
  else
    environment_type="Desktop/Physical"
    readarray -t modules < <(get_full_module_list | tr ' ' '\n')
  fi

  HARDN_STATUS "info" "Applying ${#modules[@]} security modules for $environment_type environment..."
  for module in "${modules[@]}"; do
    [[ -z "$module" ]] && continue
    if run_module "$module"; then
      HARDN_STATUS "pass" "Module completed: $module"
    else
      HARDN_STATUS "warning" "Module failed: $module"; ((failed_modules++))
    fi
  done

  if [[ $failed_modules -eq 0 ]]; then
    HARDN_STATUS "pass" "All $environment_type security modules have been applied successfully."
  else
    HARDN_STATUS "warning" "$failed_modules modules failed. Check logs for details."
  fi
}

cleanup() {
  HARDN_STATUS "info" "Performing final system cleanup..."
  apt-get autoremove -y &>/dev/null || true
  apt-get clean &>/dev/null || true
  apt-get autoclean -y &>/dev/null || true
  HARDN_STATUS "pass" "System cleanup completed. Unused packages and cache cleared."
  if [[ "$SKIP_WHIPTAIL" != "1" ]]; then
    whiptail --infobox "HARDN-XDR v${HARDN_VERSION} setup complete! Please reboot your system." 8 75
    sleep 3
  else
    HARDN_STATUS "info" "HARDN-XDR v${HARDN_VERSION} setup complete! Please reboot your system."
  fi
}

# ------------------------------------------------------------
# Menus & CLI
# ------------------------------------------------------------
main_menu() {
  local environment_type modules checklist_args=()

  if is_container_vm_environment; then
    environment_type="Container/VM (DISA/FEDHIVE optimized)"
    readarray -t essential   < <(get_container_vm_essential_modules   | tr ' ' '\n')
    readarray -t conditional < <(get_container_vm_conditional_modules | tr ' ' '\n')
    readarray -t desktop     < <(get_desktop_focused_modules          | tr ' ' '\n')
    modules=("${essential[@]}" "${conditional[@]}" "${desktop[@]}")
    for m in "${essential[@]}";   do [[ -n "$m" ]] && checklist_args+=("$m" "[ESSENTIAL] Install $m (DISA/FEDHIVE compliance)" "ON"); done
    for m in "${conditional[@]}"; do [[ -n "$m" ]] && checklist_args+=("$m" "[OPTIONAL] Install $m (performance trade-off)" "OFF"); done
    for m in "${desktop[@]}";     do [[ -n "$m" ]] && checklist_args+=("$m" "[DESKTOP] Install $m (not recommended)" "OFF"); done
    checklist_args+=("ALL" "Install recommended modules for this environment" "OFF")
  else
    environment_type="Desktop/Physical"
    readarray -t modules < <(get_full_module_list | tr ' ' '\n')
    for m in "${modules[@]}"; do [[ -n "$m" ]] && checklist_args+=("$m" "Install $m" "OFF"); done
    checklist_args+=("ALL" "Install all modules" "OFF")
  fi

  HARDN_STATUS "info" "Environment detected: $environment_type"

  local title="HARDN-XDR Module Selection"
  [[ $environment_type == Container* ]] && title="$title - $environment_type"

  local selected
  if ! selected=$(whiptail --title "$title" --checklist "Select modules to install (SPACE to select, TAB to move):" 25 80 15 "${checklist_args[@]}" 3>&1 1>&2 2>&3); then
    HARDN_STATUS "info" "No modules selected. Exiting."; exit 1
  fi

  update_system_packages
  install_package_dependencies

  if [[ "$selected" == *"ALL"* ]]; then
    setup_security_modules
  else
    selected=$(echo "$selected" | tr -d '"')
    local failed=0
    for module in $selected; do
      if run_module "$module"; then
        HARDN_STATUS "pass" "Module completed: $module"
      else
        HARDN_STATUS "warning" "Module failed: $module"; ((failed++))
      fi
    done
    [[ $failed -eq 0 ]] && HARDN_STATUS "pass" "Selected modules applied successfully." \
                       || HARDN_STATUS "warning" "$failed modules failed. Check logs."
  fi
  cleanup
}

show_usage() {
cat << 'EOF'
HARDN-XDR - Linux Security Hardening Sentinel
Usage: hardn-xdr [OPTIONS]

OPTIONS:
  --docker              Deploy CVE mitigation in Docker (includes UFW firewall)
  --docker-cve          Deploy CVE mitigation modules in Docker (explicit)
  --docker-debian-cve   Deploy Debian-specific CVE mitigations
  --docker-security     Deploy comprehensive security modules in Docker
  --docker-detection    Deploy threat detection & analysis modules
  --docker-full         Deploy CVE + Security modules
  --docker-all          Deploy ALL Docker-compatible modules
  --container-mode      Run in container-optimized mode (non-interactive)
  --module MODULE       Run specific security module
  --list-modules        List all available security modules
  --audit               Run security audit only
  --version             Show version information
  --help                Show this help message
EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --docker)              deploy_docker_hardn "cve"            ; exit $? ;;
      --docker-cve)          deploy_docker_hardn "cve"            ; exit $? ;;
      --docker-security)     deploy_docker_hardn "security"       ; exit $? ;;
      --docker-full)         deploy_docker_hardn "full"           ; exit $? ;;
      --docker-detection)    deploy_docker_hardn "detection"      ; exit $? ;;
      --docker-all)          deploy_docker_hardn "all"            ; exit $? ;;
      --docker-debian-cve)   deploy_docker_hardn "debian-cve"     ; exit $? ;;
      --container-mode)      export HARDN_CONTAINER_MODE=1; export SKIP_WHIPTAIL=1; shift ;;
      --module)
        if [[ -n "${2:-}" ]]; then run_specific_module "$2"; exit $?; else
          HARDN_STATUS "error" "Module name required for --module"; exit 1; fi ;;
      --list-modules)        HARDN_STATUS "info" "Available modules:"; list_available_modules; exit 0 ;;
      --audit)               HARDN_STATUS "info" "Running security audit..."; run_audit_only; exit $? ;;
      --version)             echo "HARDN-XDR v${HARDN_VERSION}"; exit 0 ;;
      --help|-h)             show_usage; exit 0 ;;
      *)                     HARDN_STATUS "error" "Unknown option: $1"; show_usage; exit 1 ;;
    esac
    shift
  done
}

# Simple audit-only flow (placeholder list runner)
run_audit_only() {
  local audit_modules=("audit_system.sh" "lynis_audit.sh" "debsums.sh" "rkhunter.sh" "chkrootkit.sh")
  local i=0 ok=0
  for m in "${audit_modules[@]}"; do
    ((i++)); HARDN_STATUS "info" "[$i] Running audit module: $m"
    if run_module "$m"; then ((ok++)); HARDN_STATUS "pass" "[$i] Audit module $m OK"
    else HARDN_STATUS "warning" "[$i] Audit module $m had warnings"; fi
  done
  HARDN_STATUS "info" "Audit summary: $ok/${#audit_modules[@]} modules OK"
  return 0
}

run_specific_module() {
  local name="$1"
  [[ "$name" != *.sh ]] && name="${name}.sh"
  HARDN_STATUS "info" "Running specific module: $name"
  if run_module "$name"; then
    HARDN_STATUS "pass" "Module $name completed successfully"
  else
    HARDN_STATUS "error" "Module $name failed"; exit 1
  fi
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
main_flow() {
  HARDN_LOG "HARDN-XDR v${HARDN_VERSION} started"
  print_ascii_banner
  show_system_info
  check_root

  if [[ "$SKIP_WHIPTAIL" == "1" || "$AUTO_MODE" == "true" ]]; then
    HARDN_STATUS "info" "Running in non-interactive mode"; HARDN_LOG "Non-interactive mode"
    update_system_packages
    install_package_dependencies
    setup_security_modules
    cleanup
    HARDN_LOG "HARDN-XDR non-interactive execution completed"
    return 0
  fi

  HARDN_LOG "Interactive mode"
  welcomemsg
  main_menu
  HARDN_LOG "HARDN-XDR interactive execution completed"
}

# CLI entry
if [[ $# -gt 0 ]]; then
  case "$1" in
    --version|-v) echo "HARDN-XDR version $HARDN_VERSION"; exit 0 ;;
    --help|-h)    show_usage; exit 0 ;;
    --auto)       export AUTO_MODE=true ;;
    --ci)         export CI_MODE=true; export SKIP_WHIPTAIL=1; export AUTO_MODE=true ;;
  esac
fi

parse_arguments "$@"
main_flow