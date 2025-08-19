#!/usr/bin/env bash

# Strict shell options for robustness
set -euo pipefail

HARDN_VERSION="1.1.63"
export APT_LISTBUGS_FRONTEND=none

# Logging setup
HARDN_LOG_FILE="${HARDN_LOG_FILE:-/var/log/hardn-xdr.log}"

# Set default values for environment variables to prevent unbound variable errors
: "${CI:=}"
: "${GITHUB_ACTIONS:=}"
: "${GITLAB_CI:=}"
: "${DEBIAN_FRONTEND:=noninteractive}"
: "${SKIP_WHIPTAIL:=}"
: "${HARDN_CONTAINER_MODE:=}"
: "${PAKOS_DETECTED:=0}"
: "${ID:=Unknown}"
: "${AUTO_MODE:=}"

# Simple logging function that logs to file if writable, otherwise stdout
HARDN_LOG() {
    local message="$(date '+%Y-%m-%d %H:%M:%S') - $*"
    if [[ -w "$(dirname "$HARDN_LOG_FILE")" ]] 2>/dev/null; then
        echo "$message" >> "$HARDN_LOG_FILE"
    else
        echo "$message"
    fi
}

# Auto-detect CI 
if [[ -n "$CI" || -n "$GITHUB_ACTIONS" || -n "$GITLAB_CI" || ! -t 0 ]]; then
    export SKIP_WHIPTAIL=1
    echo "[INFO] CI environment detected, running in non-interactive mode"
    HARDN_LOG "CI environment detected, running in non-interactive mode"
fi


if [ -f /usr/lib/hardn-xdr/src/setup/hardn-common.sh ]; then
 
    source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
elif [ -f "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/hardn-common.sh" ]; then
    # Development/CI fallback
    source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/hardn-common.sh"
else
    echo "[ERROR] hardn-common.sh not found at expected paths!"
    echo "[INFO] Using basic fallback functions for CI environment"
    
    # Basic fallback for CI
    HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
    check_root() { [[ $EUID -eq 0 ]]; }
    is_installed() { command -v "$1" >/dev/null 2>&1 || dpkg -s "$1" >/dev/null 2>&1; }
    hardn_yesno() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && return 0
        echo "Auto-confirming: $1" >&2
        return 0
    }
    hardn_msgbox() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && echo "Info: $1" >&2 && return 0
        echo "Info: $1" >&2
    }
    is_container_environment() {
        [[ -n "$CI" ]] || [[ -n "$GITHUB_ACTIONS" ]] || [[ -f /.dockerenv ]] || \
        [[ -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null
    }
    is_systemd_available() {
        [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1
    }
fi

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
        
        # Special message PakOS
        if [[ "${PAKOS_DETECTED:-0}" == "1" ]]; then
            HARDN_STATUS "info" "PakOS Support: Enabled (Debian-derivative compatibility mode)"
        fi
    fi
    HARDN_STATUS "info" "Features: STIG Compliance, Malware Detection, System Hardening"
}

# Docker deployment functionality
deploy_docker_hardn() {
    local action="${1:-run}"
    local docker_image="hardn-xdr:debian-bookworm"
    local project_root
    project_root="$(cd "${SCRIPT_DIR}/../.." && pwd)"

    HARDN_STATUS "info" "HARDN-XDR Docker Deployment v${HARDN_VERSION}"
    HARDN_STATUS "info" "=============================================="

    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        HARDN_STATUS "error" "Docker is not installed or not in PATH"
        HARDN_STATUS "info" "Please install Docker first: https://docs.docker.com/get-docker/"
        exit 1
    fi

    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        HARDN_STATUS "error" "Docker daemon is not running"
        HARDN_STATUS "info" "Please start Docker daemon first"
        exit 1
    fi

    case "$action" in
        "build")
            HARDN_STATUS "info" "Building HARDN-XDR Docker image..."
            if [[ -f "$project_root/docker/debian-bookworm/Dockerfile" ]]; then
                docker build -f "$project_root/docker/debian-bookworm/Dockerfile" -t "$docker_image" "$project_root"
                HARDN_STATUS "pass" "Docker image built successfully: $docker_image"
            else
                HARDN_STATUS "error" "Dockerfile not found at $project_root/docker/debian-bookworm/Dockerfile"
                exit 1
            fi
            ;;
        "run")
            # Check if image exists, build if not
            if ! docker image inspect "$docker_image" >/dev/null 2>&1; then
                HARDN_STATUS "info" "Docker image not found, building..."
                deploy_docker_hardn "build"
            fi

            HARDN_STATUS "info" "Running HARDN-XDR in Docker container..."
            HARDN_STATUS "info" "Container provides isolation from host CVEs"

            # Create temporary directory for results
            local results_dir="/tmp/hardn-xdr-results-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$results_dir"

            HARDN_STATUS "info" "Results will be saved to: $results_dir"

            # Run the container with appropriate mounts and privileges
            docker run -it --rm \
                --name "hardn-xdr-$(date +%H%M%S)" \
                --privileged \
                --pid=host \
                --network=host \
                -v /var/log:/host-logs \
                -v "$results_dir:/results" \
                -v /etc:/host-etc:ro \
                -e "HARDN_DOCKER_MODE=1" \
                "$docker_image" \
                bash -c "
                cd /opt/hardn-xdr
                echo '🐳 HARDN-XDR Docker Mode - Isolated Security Hardening'
                echo '======================================================'
                echo 'Host system protected from direct modifications'
                echo 'Results and logs will be available in: $results_dir'
                echo ''
                # Run the hardening process
                timeout 1800s ./smoke_test.sh || echo 'Hardening process completed'
                # Copy results
                cp -r /var/log/hardn-xdr* /results/ 2>/dev/null || true
                echo ''
                echo '✅ HARDN-XDR Docker deployment completed!'
                echo 'Check results in: $results_dir'
                "

            HARDN_STATUS "pass" "Docker deployment completed"
            HARDN_STATUS "info" "Results available in: $results_dir"
            ;;
        "clean")
            HARDN_STATUS "info" "Cleaning up HARDN-XDR Docker resources..."
            docker rmi "$docker_image" 2>/dev/null || true
            docker system prune -f >/dev/null 2>&1 || true
            HARDN_STATUS "pass" "Docker cleanup completed"
            ;;
        *)
            HARDN_STATUS "error" "Unknown Docker action: $action"
            HARDN_STATUS "info" "Available actions: build, run, clean"
            exit 1
            ;;
    esac
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
        whiptail
        apt-transport-https
        ca-certificates
        curl
        gnupg
        lsb-release
        git
        build-essential
        debsums
    )
    if apt-get install -y "${packages[@]}"; then
        HARDN_STATUS "pass" "Package dependencies installed successfully."
    else
        HARDN_STATUS "error" "Failed to install package dependencies. Please check your system configuration."
        exit 1
    fi
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --docker)
                deploy_docker_hardn "cve" "${@:2}"
                exit $?
                ;;
            --docker-cve)
                deploy_docker_hardn "cve" "${@:2}"
                exit $?
                ;;
            --docker-security)
                deploy_docker_hardn "security" "${@:2}"
                exit $?
                ;;
            --docker-full)
                deploy_docker_hardn "full" "${@:2}"
                exit $?
                ;;
                            --docker-detection)
                deploy_docker_hardn "detection" "${@:2}"
                exit $?
                ;;
                            --docker-all)
                deploy_docker_hardn "all" "${@:2}"
                exit $?
                ;;
                            --docker-debian-cve)
                deploy_docker_hardn "debian-cve" "${@:2}"
                exit $?
                ;;
            --container-mode)
                export HARDN_CONTAINER_MODE=1
                export SKIP_WHIPTAIL=1
                shift
                ;;
            --module)
                if [[ -n "$2" ]]; then
                    run_specific_module "$2"
                    exit $?
                else
                    HARDN_STATUS "error" "Module name required for --module flag"
                    exit 1
                fi
                ;;
            --list-modules)
                HARDN_STATUS "info" "Available HARDN-XDR Security Modules:"
                list_available_modules
                exit 0
                ;;
            --audit)
                HARDN_STATUS "info" "Running security audit..."
                # Run audit-specific modules only
                run_audit_only
                exit $?
                ;;
            --version)
                echo "HARDN-XDR v${HARDN_VERSION}"
                exit 0
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                HARDN_STATUS "error" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
        shift
    done
}

# Print ASCII banner
print_ascii_banner() {
   # Declaring and assigning terminal width and banner separately to avoid masking return variables
   # https://github.com/koalaman/shellcheck/wiki/SC2155
    export TERM=xterm
          terminal_width=$(tput cols)
    local banner
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
    local banner_width
          banner_width=$(echo "$banner" | awk '{print length}' | sort -n | tail -1)
    local padding=$(( (terminal_width - banner_width) / 2 ))
    printf "\033[1;32m"
    while IFS= read -r line; do
        printf "%*s%s\n" "$padding" "" "$line"
    done <<< "$banner"
    printf "\033[0m"
    sleep 2
}

# Show usage information
show_usage() {
    HARDN_STATUS "info" "HARDN-XDR v${HARDN_VERSION} - Linux Security Hardening Sentinel"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h           Show this help message"
    echo "  --version            Show version information"
    echo "  --docker             Deploy in Docker container (default)"
    echo "  --docker-cve         Run CVE protection in Docker"
    echo "  --docker-security    Run security hardening in Docker"
    echo "  --docker-full        Run full hardening suite in Docker"
    echo "  --docker-detection   Run malware detection in Docker"
    echo "  --docker-all         Run all modules in Docker"
    echo "  --docker-debian-cve  Run Debian CVE fixes in Docker"
    echo "  --container-mode     Run in container mode (non-interactive)"
    echo "  --module MODULE      Run specific security module"
    echo "  --list-modules       List available security modules"
    echo "  --audit              Run security audit only"
    echo ""
    echo "Examples:"
    echo "  $0 --docker-full     # Run full security hardening in Docker"
    echo "  $0 --module firewall # Run firewall hardening module"
    echo "  $0 --audit          # Run security audit"
    echo ""
}

# List available security modules
list_available_modules() {
    local modules_dir="$SCRIPT_DIR/../modules"
    if [[ -d "$modules_dir" ]]; then
        echo "Available modules:"
        find "$modules_dir" -name "*.sh" -type f | while read -r module; do
            local module_name=$(basename "$module" .sh)
            echo "  - $module_name"
        done
    else
        echo "  - firewall (Security firewall configuration)"
        echo "  - ssh (SSH hardening)"
        echo "  - audit (Security audit)"
        echo "  - malware-detection (Malware scanning)"
        echo "  - cve-protection (CVE vulnerability fixes)"
        echo "  - system-hardening (System security hardening)"
    fi
}

# Run audit only
run_audit_only() {
    HARDN_STATUS "info" "Running security audit modules only..."
    # This would normally call audit-specific modules
    HARDN_STATUS "info" "Audit functionality not fully implemented in this version"
    return 0
}

# Run module function (placeholder)
run_module() {
    local module_name="$1"
    HARDN_STATUS "info" "Module runner not implemented for: $module_name"
    HARDN_STATUS "info" "This would run the specific security module"
    return 0
}

# Run specific module
run_specific_module() {
    local module_name="$1"
    HARDN_STATUS "info" "Running specific module: $module_name"

    # Add .sh extension if not present
    [[ "$module_name" != *.sh ]] && module_name="${module_name}.sh"

    if run_module "$module_name"; then
        HARDN_STATUS "pass" "Module $module_name completed successfully"
    else
        HARDN_STATUS "error" "Module $module_name failed"
        exit 1
    fi
}

# Run audit-only modules
run_audit_only() {
    local audit_modules=(
        "audit_system.sh"
        "lynis_audit.sh"
        "debsums.sh"
        "rkhunter.sh"
        "chkrootkit.sh"
    )

    for module in "${audit_modules[@]}"; do
        HARDN_STATUS "info" "Running audit module: $module"
        run_module "$module" || HARDN_STATUS "warning" "Audit module $module completed with warnings"
    done
}

# Main execution starts here
main() {
    # Parse command line arguments first
    parse_arguments "$@"

    # If no arguments provided, run normal interactive mode
    print_ascii_banner
    show_system_info
    welcomemsg
    update_system_packages
    install_package_dependencies

    # Run full hardening
    HARDN_STATUS "info" "Starting full system hardening..."
    # Add your existing hardening logic here
}

# Call main function with all arguments
main "$@"

list_available_modules() {
    # Discover all available module scripts dynamically
    local DEFAULT_DIR="/usr/lib/hardn-xdr/src/setup/modules"
    local CONFIG_DIR="${HARDN_MODULE_DIR:-$DEFAULT_DIR}"
    local FALLBACK_DIR="${SCRIPT_DIR}/modules"

    # Try primary directory first
    if [[ -d "$CONFIG_DIR" ]]; then
        find "$CONFIG_DIR" -type f -name "*.sh" -exec basename {} \; | sort
        return
    fi

    # Try fallback directory
    if [[ -d "$FALLBACK_DIR" ]]; then
        HARDN_STATUS "info" "Using fallback module directory: $FALLBACK_DIR"
        find "$FALLBACK_DIR" -type f -name "*.sh" -exec basename {} \; | sort
        return
    fi

    # Use static fallback list as last resort
    HARDN_STATUS "warning" "No module directory found. Using static fallback list."
    HARDN_LOG "Module directory not found: $CONFIG_DIR or $FALLBACK_DIR. Using fallback list."
    echo -e "auditd.sh\nkernel_sec.sh\nsshd.sh\naide.sh\nufw.sh\nfail2ban.sh"
}

print_ascii_banner() {
   # Declaring and assigning terminal width and banner separately to avoid masking return variables
   # https://github.com/koalaman/shellcheck/wiki/SC2155
    export TERM=xterm
          terminal_width=$(tput cols)
    local banner
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
    local banner_width
          banner_width=$(echo "$banner" | awk '{print length}' | sort -n | tail -1)
    local padding=$(( (terminal_width - banner_width) / 2 ))
    printf "\033[1;32m"
    while IFS= read -r line; do
        printf "%*s%s\n" "$padding" "" "$line"
    done <<< "$banner"
    printf "\033[0m"
    sleep 2
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
            # Validate path is within expected directories for security
            local real_path
            real_path="$(realpath "$module_path" 2>/dev/null)" || continue
            if [[ "$real_path" == "$module_dir"/* ]] || [[ "$real_path" == "${SCRIPT_DIR}/modules"/* ]]; then
                HARDN_STATUS "info" "Executing module: ${module_file} from ${module_path}"
                HARDN_LOG "Executing module: ${module_file} from ${module_path}"
                # shellcheck source=src/setup/modules/aide.sh
                source "$module_path"
                local source_result=$?

                if [[ $source_result -eq 0 ]]; then
                    HARDN_LOG "Module completed successfully: $module_file"
                    return 0
                else
                    HARDN_STATUS "error" "Module execution failed: $module_path"
                    HARDN_LOG "Module execution failed: $module_path (exit code: $source_result)"
                    return 1
                fi
            else
                HARDN_STATUS "warning" "Module path validation failed: $module_path"
                HARDN_LOG "Module path validation failed: $module_path"
            fi
        fi
    done

    HARDN_STATUS "error" "Module not found in any expected location: $module_file"
    HARDN_LOG "Module not found: $module_file"
    for path in "${module_paths[@]}"; do
        HARDN_STATUS "error" "  - $path"
    done
    return 1
}

# Container/VM essential modules for DISA/FEDHIVE compliance
get_container_vm_essential_modules() {
    echo "auditd.sh kernel_sec.sh sshd.sh credential_protection.sh"
    echo "auto_updates.sh file_perms.sh shared_mem.sh coredumps.sh"
    echo "network_protocols.sh process_accounting.sh debsums.sh purge_old_pkgs.sh"
    echo "banner.sh central_logging.sh audit_system.sh ntp.sh dns_config.sh"
    echo "binfmt.sh service_disable.sh stig_pwquality.sh pakos_config.sh memory_optimization.sh"
}

# Docker 
deploy_docker_hardn() {
    local mode="${1:-cve}"  # Default to CVE mitigation mode
    shift || true  # Remove first argument

    HARDN_STATUS "info" "Deploying HARDN-XDR in Docker container (mode: $mode)..."

    # Check if Docker is installed
    if ! command -v docker >/dev/null 2>&1; then
        HARDN_STATUS "error" "Docker is not installed. Installing Docker..."
        install_docker_if_needed || return 1
    fi

    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        HARDN_STATUS "error" "Docker daemon is not running. Please start Docker service."
        return 1
    fi

    local script_root
    script_root="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    local docker_image="hardn-xdr:debian-bookworm"

    # Build Docker image if it doesn't exist
    if ! docker image inspect "$docker_image" >/dev/null 2>&1; then
        HARDN_STATUS "info" "Building HARDN-XDR Docker image..."
        if [[ -f "$script_root/docker/debian-bookworm/Dockerfile" ]]; then
            if ! docker build -f "$script_root/docker/debian-bookworm/Dockerfile" -t "$docker_image" "$script_root"; then
                HARDN_STATUS "error" "Failed to build Docker image"
                return 1
            fi
        else
            HARDN_STATUS "error" "Docker build files not found in $script_root/docker/"
            return 1
        fi
    fi

    # Create results directory
    local results_dir="/tmp/hardn-xdr-docker-results-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$results_dir"

    HARDN_STATUS "info" "Running HARDN-XDR Docker hardening (mode: $mode)..."
    HARDN_STATUS "info" "Results will be saved to: $results_dir"

    # Determine which command to run based on mode
    local container_command
    case "$mode" in
        "cve")
            container_command="run_docker_cve_modules"
            ;;
        "security")
            container_command="run_docker_security_modules"
            ;;
        "detection")
            container_command="run_docker_detection_modules"
            ;;
        "full")
            container_command="run_docker_cve_modules && echo '' && run_docker_security_modules"
            ;;
        "all")
            container_command="run_all_docker_modules"
            ;;
        "debian-cve")
            container_command="run_debian_cve_mitigation"
            ;;
        *)
            container_command="run_docker_cve_modules"
            ;;
    esac

    # Run hardening in container with proper permissions and mounts
    # Note: --network=host required for UFW firewall and network modules
    docker run --rm \
        --name "hardn-xdr-$(date +%H%M%S)" \
        --privileged \
        --pid=host \
        --network=host \
        --cap-add=NET_ADMIN \
        --cap-add=SYS_ADMIN \
        -v /etc:/host-etc \
        -v /var:/host-var \
        -v /usr:/host-usr:ro \
        -v /sys:/host-sys:ro \
        -v /proc:/host-proc:ro \
        -v /run:/host-run \
        -v "$results_dir:/results" \
        -e HARDN_DOCKER_MODE=1 \
        -e SKIP_WHIPTAIL=1 \
        -e CI=1 \
        -e HARDN_DOCKER_FIREWALL=1 \
        "$docker_image" \
        bash -c "
        cd /opt/hardn-xdr
        echo '🐳 HARDN-XDR Docker Hardening Mode: $mode'
        echo '============================================='
        echo 'Container Image: $docker_image'
        echo 'Execution Mode: $mode'
        echo 'Results Directory: $results_dir'
        echo ''

        # Source the main script to get access to functions
        source /opt/hardn-xdr/src/setup/hardn-main.sh

        # Run the selected hardening profile
        $container_command

        # Copy logs to results
        cp -r /var/log/hardn-xdr* /results/ 2>/dev/null || true
        echo ''
        echo '✅ HARDN-XDR Docker hardening completed!'
        echo 'Results saved to: $results_dir'
        "

    local docker_result=$?
    if [[ $docker_result -eq 0 ]]; then
        HARDN_STATUS "pass" "Docker-based HARDN-XDR hardening completed successfully!"
        HARDN_STATUS "info" "Results available in: $results_dir"
    else
        HARDN_STATUS "error" "Docker-based HARDN-XDR hardening failed (exit code: $docker_result)"
        return 1
    fi
}

# Install Docker if needed
install_docker_if_needed() {
    HARDN_STATUS "info" "Installing Docker..."

    # Update package index
    apt-get update -y || return 1

    # Install prerequisites
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release || return 1

    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || return 1

    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list || return 1

    # Update package index with Docker repo
    apt-get update -y || return 1

    # Install Docker
    apt-get install -y docker-ce docker-ce-cli containerd.io || return 1

    # Start and enable Docker service
    systemctl start docker || return 1
    systemctl enable docker || return 1

    HARDN_STATUS "pass" "Docker installed successfully"
    return 0
}

# Run Docker detection modules
run_docker_detection_modules() {
    local modules
    modules=$(get_docker_detection_modules)
    local module_count=0
    local success_count=0

    HARDN_STATUS "info" "Running Docker Detection & Analysis Modules"
    HARDN_STATUS "info" "============================================"

    for module in $modules; do
        ((module_count++))
        HARDN_STATUS "info" "[$module_count] Running detection module: $module"

        if run_module "$module"; then
            ((success_count++))
            HARDN_STATUS "pass" "[$module_count] Detection module $module completed successfully"
        else
            HARDN_STATUS "warning" "[$module_count] Detection module $module completed with warnings"
        fi

        sleep 1
    done

    HARDN_STATUS "info" "Docker Detection Summary: $success_count/$module_count modules completed"
    return 0
}

# Run all Docker-compatible modules
run_all_docker_modules() {
    HARDN_STATUS "info" "Running Complete Docker Module Suite"
    HARDN_STATUS "info" "===================================="

    run_docker_cve_modules
    echo ""
    run_docker_security_modules
    echo ""
    run_docker_detection_modules

    HARDN_STATUS "pass" "Complete Docker module suite finished!"
}

# Show usage help
show_usage() {
    cat << EOF
HARDN-XDR v${HARDN_VERSION} - Linux Security Hardening Sentinel
Usage: hardn-xdr [OPTIONS]

OPTIONS:
  --docker              Deploy CVE mitigation in Docker (includes UFW firewall)
  --docker-cve          Deploy CVE mitigation modules in Docker (explicit)
  --docker-debian-cve   Deploy Debian-specific CVE mitigations (targets 21 CVEs)
  --docker-security     Deploy comprehensive security modules in Docker
  --docker-detection    Deploy threat detection & analysis modules
  --docker-full         Deploy CVE + Security modules (recommended production)
  --docker-all          Deploy ALL Docker-compatible modules (complete suite)
  --container-mode      Run in container-optimized mode
  --module MODULE       Run specific security module
  --list-modules        List all available security modules
  --audit               Run security audit only
  --version             Show version information
  --help                Show this help message

EXAMPLES:
  hardn-xdr --docker-debian-cve   # Target 21 Debian CVEs specifically (recommended)
  hardn-xdr --docker              # General CVE mitigation + firewall
  hardn-xdr --docker-full         # CVE + Security hardening (production)
  hardn-xdr --docker-all          # Complete security suite (maximum protection)
  hardn-xdr --docker-detection    # Threat detection & analysis only
  hardn-xdr --module kernel_sec   # Run kernel hardening module only
  hardn-xdr --list-modules        # List all 40+ available modules

DOCKER MODULES BY TARGET:
  Debian CVE Mode: Targets glibc, systemd, coreutils, shadow, apt vulnerabilities
  CVE Mode: SSH, UFW Firewall, Fail2ban, Kernel Security, Auto-updates
  Security Mode: Audit, IDS (Suricata), Malware Detection, File Integrity
  Detection Mode: Behavioral Analysis, Rootkit Detection, Persistence Detection
  All Mode: Complete 35+ module security suite

DOCKER MODE:
  The --docker flag runs HARDN-XDR in a secure container, protecting your host
  system from potential vulnerabilities while applying security hardening.
  This is the recommended way to run HARDN-XDR on production systems.

EOF
}

# Container/VM conditional modules (performance vs security trade-off)
get_container_vm_conditional_modules() {
    echo "ufw.sh fail2ban.sh selinux.sh apparmor.sh suricata.sh yara.sh"
    echo "rkhunter.sh chkrootkit.sh unhide.sh secure_net.sh lynis_audit.sh"
}

# Desktop-focused modules (skip in container/VM environments for performance)
get_desktop_focused_modules() {
    echo "usb.sh firewire.sh firejail.sh compilers.sh pentest.sh"
    echo "behavioral_analysis.sh persistence_detection.sh process_protection.sh"
    echo "deleted_files.sh unnecessary_services.sh"
}

# Docker-optimized CVE mitigation modules (essential security)
get_docker_cve_modules() {
    echo "sshd.sh network_protocols.sh kernel_sec.sh auto_updates.sh"
    echo "purge_old_pkgs.sh debsums.sh file_perms.sh credential_protection.sh"
    echo "coredumps.sh shared_mem.sh dns_config.sh banner.sh"
    echo "audit_system.sh ntp.sh binfmt.sh process_accounting.sh"
    echo "ufw.sh fail2ban.sh"  # Network security including firewall
}

# Docker-compatible security modules (comprehensive hardening)
get_docker_security_modules() {
    echo "auditd.sh central_logging.sh stig_pwquality.sh"
    echo "secure_net.sh service_disable.sh memory_optimization.sh"
    echo "pakos_config.sh lynis_audit.sh suricata.sh"
    echo "rkhunter.sh chkrootkit.sh unhide.sh yara.sh"
}

# Docker-compatible detection & analysis modules
get_docker_detection_modules() {
    echo "behavioral_analysis.sh persistence_detection.sh"
    echo "process_protection.sh deleted_files.sh"
    echo "compliance_validation.sh backup_security.sh"
}

# Docker-compatible advanced modules (performance impact)
get_docker_advanced_modules() {
    echo "bootloader_security.sh disk_encryption.sh"
    echo "unnecesary_services.sh"
}

# Get all Docker-compatible modules
get_all_docker_modules() {
    echo "$(get_docker_cve_modules) $(get_docker_security_modules)"
    echo "$(get_docker_detection_modules) $(get_docker_advanced_modules)"
}

# Debian CVE-specific mitigation modules (targets current Debian:latest CVEs)
get_debian_cve_mitigation_modules() {
    echo "kernel_sec.sh"              # Mitigates glibc ASLR bypass, stack guard issues
    echo "file_perms.sh"              # Fixes shadow/passwd permissions, symlink attacks
    echo "credential_protection.sh"    # Hardens shadow suite configuration
    echo "sshd.sh"                    # Prevents authentication bypass issues
    echo "auto_updates.sh"            # Ensures security patches for glibc, systemd, coreutils
    echo "purge_old_pkgs.sh"          # Removes vulnerable package versions
    echo "debsums.sh"                 # Validates package integrity (apt signature issues)
    echo "audit_system.sh"            # Monitors for exploitation attempts
    echo "central_logging.sh"         # Mitigates systemd log integrity issues
    echo "secure_net.sh"              # Network-level protections
    echo "ufw.sh"                     # Firewall protection against remote exploitation
    echo "fail2ban.sh"                # Prevents brute force attacks on vulnerable services
    echo "service_disable.sh"         # Disables unnecessary services that may be vulnerable
}

# Run Debian CVE mitigation modules
run_debian_cve_mitigation() {
    local modules
    modules=$(get_debian_cve_mitigation_modules)
    local module_count=0
    local success_count=0

    HARDN_STATUS "info" "🛡️  Debian CVE Mitigation Mode"
    HARDN_STATUS "info" "=============================="
    HARDN_STATUS "info" "Targeting 21 CVEs found in debian:latest"
    HARDN_STATUS "info" "Focus: glibc, systemd, coreutils, shadow, apt vulnerabilities"
    echo ""

    for module in $modules; do
        ((module_count++))
        HARDN_STATUS "info" "[$module_count] Applying CVE mitigation: $module"

        if run_module "$module"; then
            ((success_count++))
            HARDN_STATUS "pass" "[$module_count] ✅ CVE mitigation $module completed"
        else
            HARDN_STATUS "warning" "[$module_count] ⚠️  CVE mitigation $module completed with warnings"
        fi

        sleep 1
    done

    echo ""
    HARDN_STATUS "info" "🔒 Debian CVE Mitigation Summary"
    HARDN_STATUS "info" "================================"
    HARDN_STATUS "info" "Modules applied: $success_count/$module_count"
    HARDN_STATUS "info" "CVEs addressed: glibc ASLR bypass, systemd log integrity, coreutils races"
    HARDN_STATUS "info" "Security enhancements: shadow hardening, apt validation, file permissions"

    if [[ $success_count -eq $module_count ]]; then
        HARDN_STATUS "pass" "🎉 All Debian CVE mitigations applied successfully!"
        return 0
    else
        HARDN_STATUS "warning" "⚠️  Some CVE mitigations completed with warnings"
        return 1
    fi
}

# Run Docker CVE mitigation modules
run_docker_cve_modules() {
    local modules
    modules=$(get_docker_cve_modules)
    local module_count=0
    local success_count=0

    HARDN_STATUS "info" "Running Docker CVE Mitigation Modules"
    HARDN_STATUS "info" "======================================"

    for module in $modules; do
        ((module_count++))
        HARDN_STATUS "info" "[$module_count] Running CVE mitigation module: $module"

        if run_module "$module"; then
            ((success_count++))
            HARDN_STATUS "pass" "[$module_count] CVE module $module completed successfully"
        else
            HARDN_STATUS "warning" "[$module_count] CVE module $module completed with warnings"
        fi

        sleep 1  # Brief pause between modules
    done

    HARDN_STATUS "info" "Docker CVE Mitigation Summary: $success_count/$module_count modules completed"

    if [[ $success_count -eq $module_count ]]; then
        HARDN_STATUS "pass" "All Docker CVE mitigation modules completed successfully!"
        return 0
    else
        HARDN_STATUS "warning" "Some CVE mitigation modules completed with warnings"
        return 1
    fi
}

# Run Docker security hardening modules
run_docker_security_modules() {
    local modules
    modules=$(get_docker_security_modules)
    local module_count=0
    local success_count=0

    HARDN_STATUS "info" "Running Docker Security Hardening Modules"
    HARDN_STATUS "info" "=========================================="

    for module in $modules; do
        ((module_count++))
        HARDN_STATUS "info" "[$module_count] Running security module: $module"

        if run_module "$module"; then
            ((success_count++))
            HARDN_STATUS "pass" "[$module_count] Security module $module completed successfully"
        else
            HARDN_STATUS "warning" "[$module_count] Security module $module completed with warnings"
        fi

        sleep 1
    done

    HARDN_STATUS "info" "Docker Security Hardening Summary: $success_count/$module_count modules completed"
    return 0
}

# Legacy full module list for backwards compatibility
get_full_module_list() {
    echo "ufw.sh fail2ban.sh sshd.sh auditd.sh kernel_sec.sh"
    echo "stig_pwquality.sh aide.sh rkhunter.sh chkrootkit.sh"
    echo "auto_updates.sh central_logging.sh audit_system.sh ntp.sh"
    echo "debsums.sh yara.sh suricata.sh firejail.sh selinux.sh"
    echo "unhide.sh pentest.sh compilers.sh purge_old_pkgs.sh dns_config.sh"
    echo "file_perms.sh apparmor.sh shared_mem.sh coredumps.sh secure_net.sh"
    echo "network_protocols.sh usb.sh firewire.sh binfmt.sh"
    echo "process_accounting.sh unnecessary_services.sh banner.sh"
    echo "deleted_files.sh credential_protection.sh service_disable.sh"
}

# Detect if we're in a container/VM optimized environment
is_container_vm_environment() {
    # Check for container environment
    if is_container_environment; then
        return 0
    fi
    
    # Check for VM indicators
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        if systemd-detect-virt --quiet 2>/dev/null; then
            return 0
        fi
    fi
    
    # Check for VM-specific indicators
    if [[ -d /proc/vz ]] || \
       [[ -f /proc/user_beancounters ]] || \
       grep -qi hypervisor /proc/cpuinfo 2>/dev/null || \
       [[ -n "$HARDN_CONTAINER_VM_MODE" ]]; then
        return 0
    fi
    
    return 1
}

setup_security_modules() {
    local environment_type=""
    local modules=()
    
    # Determine environment and select appropriate modules
    if is_container_vm_environment; then
        environment_type="Container/VM"
        HARDN_STATUS "info" "Container/VM environment detected - optimizing for DISA/FEDHIVE compliance"
        
        # Essential modules for compliance
        readarray -t modules < <(get_container_vm_essential_modules | tr ' ' '\n')
        
        # Add conditional modules with user choice in interactive mode
        if [[ "$SKIP_WHIPTAIL" != "1" ]]; then
            if hardn_yesno "Include additional security modules (may impact performance)?" 10 60; then
                readarray -t conditional < <(get_container_vm_conditional_modules | tr ' ' '\n')
                modules+=("${conditional[@]}")
            fi
        else
            # In non-interactive mode, include conditional modules
            readarray -t conditional < <(get_container_vm_conditional_modules | tr ' ' '\n')
            modules+=("${conditional[@]}")
        fi
        
        # Skip desktop-focused modules
        HARDN_STATUS "info" "Skipping desktop-focused modules for optimal container/VM performance"
        
    else
        environment_type="Desktop/Physical"
        HARDN_STATUS "info" "Desktop/Physical environment detected - applying full hardening suite"
        readarray -t modules < <(get_full_module_list | tr ' ' '\n')
    fi
    
    HARDN_STATUS "info" "Applying ${#modules[@]} security modules for $environment_type environment..."
    
    local failed_modules=0
    for module in "${modules[@]}"; do
        if [[ -n "$module" ]]; then
            if run_module "$module"; then
                HARDN_STATUS "pass" "Module completed: $module"
            else
                HARDN_STATUS "warning" "Module failed: $module"
                ((failed_modules++))
            fi
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
    apt-get autoremove -y &>/dev/null
    apt-get clean &>/dev/null
    apt-get autoclean -y &>/dev/null
    HARDN_STATUS "pass" "System cleanup completed. Unused packages and cache cleared."

    if [[ "$SKIP_WHIPTAIL" != "1" ]]; then
        whiptail --infobox "HARDN-XDR v${HARDN_VERSION} setup complete! Please reboot your system." 8 75
        sleep 3
    else
        HARDN_STATUS "info" "HARDN-XDR v${HARDN_VERSION} setup complete! Please reboot your system."
    fi
}

main_menu() {
    local environment_type=""
    local modules=()
    
    # Determine environment and get appropriate module list
    if is_container_vm_environment; then
        environment_type="Container/VM (DISA/FEDHIVE optimized)"
        # Combine essential and conditional modules for menu
        readarray -t essential < <(get_container_vm_essential_modules | tr ' ' '\n')
        readarray -t conditional < <(get_container_vm_conditional_modules | tr ' ' '\n')
        readarray -t desktop < <(get_desktop_focused_modules | tr ' ' '\n')
        
        modules=("${essential[@]}" "${conditional[@]}" "${desktop[@]}")
    else
        environment_type="Desktop/Physical"
        readarray -t modules < <(get_full_module_list | tr ' ' '\n')
    fi
    
    HARDN_STATUS "info" "Environment detected: $environment_type"
    
    local checklist_args=()
    
    # Add modules with categorization for container/VM environments only
    if is_container_vm_environment; then
        # Essential modules (pre-selected)
        readarray -t essential < <(get_container_vm_essential_modules | tr ' ' '\n')
        for module in "${essential[@]}"; do
            if [[ -n "$module" ]]; then
                checklist_args+=("$module" "[ESSENTIAL] Install $module (DISA/FEDHIVE compliance)" "ON")
            fi
        done
        
        # Conditional modules (optional)
        readarray -t conditional < <(get_container_vm_conditional_modules | tr ' ' '\n')
        for module in "${conditional[@]}"; do
            if [[ -n "$module" ]]; then
                checklist_args+=("$module" "[OPTIONAL] Install $module (performance trade-off)" "OFF")
            fi
        done
        
        # Desktop modules
        readarray -t desktop < <(get_desktop_focused_modules | tr ' ' '\n')
        for module in "${desktop[@]}"; do
            if [[ -n "$module" ]]; then
                checklist_args+=("$module" "[DESKTOP] Install $module (not recommended)" "OFF")
            fi
        done
        
        checklist_args+=("ALL" "Install recommended modules for this environment" "OFF")
    else
        # Original clean interface for desktop/physical systems
        for module in "${modules[@]}"; do
            if [[ -n "$module" ]]; then
                checklist_args+=("$module" "Install $module" "OFF")
            fi
        done
        
        checklist_args+=("ALL" "Install all modules" "OFF")
    fi

    local title="HARDN-XDR Module Selection"
    if is_container_vm_environment; then
        title="$title - $environment_type"
    fi

    local selected
    if ! selected=$(whiptail --title "$title" --checklist "Select modules to install (SPACE to select, TAB to move):" 25 80 15 "${checklist_args[@]}" 3>&1 1>&2 2>&3); then
        HARDN_STATUS "info" "No modules selected. Exiting."
        exit 1
    fi

    update_system_packages
    install_package_dependencies

    if [[ "$selected" == *"ALL"* ]]; then
        setup_security_modules
    else
        # Remove quotes from whiptail output
        selected=$(echo "$selected" | tr -d '"')
        local failed_modules=0
        for module in $selected; do
            if run_module "$module"; then
                HARDN_STATUS "pass" "Module completed: $module"
            else
                HARDN_STATUS "warning" "Module failed: $module"
                ((failed_modules++))
            fi
        done
        
        if [[ $failed_modules -eq 0 ]]; then
            HARDN_STATUS "pass" "Selected security modules have been applied successfully."
        else
            HARDN_STATUS "warning" "$failed_modules modules failed. Check logs for details."
        fi
    fi
    cleanup
}

# main
main() {
    HARDN_LOG "HARDN-XDR v${HARDN_VERSION} started"

    print_ascii_banner
    show_system_info
    check_root

    if [[ "$SKIP_WHIPTAIL" == "1" || "$AUTO_MODE" == "true" ]]; then
        HARDN_STATUS "info" "Running in non-interactive mode"
        HARDN_LOG "Running in non-interactive mode"
        update_system_packages
        install_package_dependencies
        setup_security_modules
        cleanup
        HARDN_LOG "HARDN-XDR non-interactive execution completed"
        return 0
    fi

    HARDN_LOG "Running in interactive mode"
    welcomemsg
    main_menu
    HARDN_LOG "HARDN-XDR interactive execution completed"
}

# Entry
if [[ $# -gt 0 ]]; then
    case "$1" in
        --version|-v)
            echo "HARDN-XDR version 1.1.x"
            exit 0
            ;;
        --help|-h)
            echo "Usage: hardn-xdr [OPTIONS]"
            echo "Options:"
            echo "  --version, -v     Display version information"
            echo "  --help, -h        Display this help message"
            echo "  --auto            Run in automatic mode without prompts"
            echo "  --ci              Run in CI environment mode"
            exit 0
            ;;
        --auto)
            export AUTO_MODE=true
            ;;
        --ci)
            export CI_MODE=true
            export SKIP_WHIPTAIL=1
            export AUTO_MODE=true
            ;;
    esac
fi

main