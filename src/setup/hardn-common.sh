#!/bin/bash

if [[ -n "$CI" || -n "$GITHUB_ACTIONS" || -n "$GITLAB_CI" || -n "$JENKINS_URL" || -n "$BUILDKITE" || ! -t 0 ]]; then
    export SKIP_WHIPTAIL=1
fi

HARDN_STATUS() {
    local status="$1"
    local message="$2"
    case "$status" in
        "pass")    echo -e "\033[1;32m[PASS]\033[0m $message" ;;
        "warning") echo -e "\033[1;33m[WARNING]\033[0m $message" ;;
        "error")   echo -e "\033[1;31m[ERROR]\033[0m $message" ;;
        "info")    echo -e "\033[1;34m[INFO]\033[0m $message" ;;
        *)         echo -e "\033[1;37m[UNKNOWN]\033[0m $message" ;;
    esac
}

is_installed() {
    local pkg="$1"
    if command -v dpkg >/dev/null 2>&1; then
        dpkg -s "$pkg" >/dev/null 2>&1
    elif command -v rpm >/dev/null 2>&1; then
        rpm -q "$pkg" >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        dnf list installed "$pkg" >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum list installed "$pkg" >/dev/null 2>&1
    else
        return 1
    fi
}

# Default whiptail UI dimensions
HARDN_WHIPTAIL_TITLE="HARDN-XDR v${HARDN_VERSION:-1.1.50}"
HARDN_WHIPTAIL_WIDTH=70
HARDN_WHIPTAIL_HEIGHT=15
HARDN_WHIPTAIL_MENU_HEIGHT=8

# Whiptail message box or fallback
hardn_msgbox() {
    local message="$1"
    local height="${2:-$HARDN_WHIPTAIL_HEIGHT}"
    local width="${3:-$HARDN_WHIPTAIL_WIDTH}"

    if [[ "$SKIP_WHIPTAIL" == "1" ]]; then
        HARDN_STATUS "info" "[fallback] $message"
        return 0
    fi

    if ! command -v whiptail >/dev/null 2>&1; then
        HARDN_STATUS "warning" "[fallback] whiptail not available: $message"
        return 0
    fi

    whiptail --title "$HARDN_WHIPTAIL_TITLE" --msgbox "$message" "$height" "$width"
}

# Whiptail info box or fallback
hardn_infobox() {
    local message="$1"
    local height="${2:-$HARDN_WHIPTAIL_HEIGHT}"
    local width="${3:-$HARDN_WHIPTAIL_WIDTH}"

    if [[ "$SKIP_WHIPTAIL" == "1" ]]; then
        HARDN_STATUS "info" "[fallback] $message"
        return 0
    fi

    if ! command -v whiptail >/dev/null 2>&1; then
        HARDN_STATUS "warning" "[fallback] whiptail not available: $message"
        return 0
    fi

    whiptail --title "$HARDN_WHIPTAIL_TITLE" --infobox "$message" "$height" "$width"
}

# Whiptail menu or fallback to first option
hardn_menu() {
    local message="$1"
    local height="${2:-$HARDN_WHIPTAIL_HEIGHT}"
    local width="${3:-$HARDN_WHIPTAIL_WIDTH}"
    local menu_height="${4:-$HARDN_WHIPTAIL_MENU_HEIGHT}"
    shift 4
    local options=("$@")

    if [[ "${#options[@]}" -lt 2 ]]; then
        HARDN_STATUS "error" "No menu options provided to hardn_menu"
        return 1
    fi

    if [[ "$SKIP_WHIPTAIL" == "1" ]]; then
        HARDN_STATUS "info" "[fallback] Auto-selecting first option for: $message"
        echo "${options[0]}"  # Return first option value
        return 0
    fi

    if ! command -v whiptail >/dev/null 2>&1; then
        HARDN_STATUS "warning" "[fallback] whiptail not available, auto-selecting first option for: $message"
        echo "${options[0]}"
        return 0
    fi

    whiptail --title "$HARDN_WHIPTAIL_TITLE" --menu "$message" "$height" "$width" "$menu_height" "${options[@]}"
}

# Whiptail yes/no dialog or fallback to "yes"
hardn_yesno() {
    local message="$1"
    local height="${2:-$HARDN_WHIPTAIL_HEIGHT}"
    local width="${3:-$HARDN_WHIPTAIL_WIDTH}"

    if [[ "$SKIP_WHIPTAIL" == "1" ]]; then
        HARDN_STATUS "info" "[fallback] Auto-confirming: $message"
        return 0
    fi

    if ! command -v whiptail >/dev/null 2>&1; then
        HARDN_STATUS "warning" "[fallback] whiptail not available, auto-confirming: $message"
        return 0
    fi

    whiptail --title "$HARDN_WHIPTAIL_TITLE" --yesno "$message" "$height" "$width"
}

# Export functions so they’re available in sourced module scripts
# Enhanced container and CI environment detection
is_container_environment() {
    # Check multiple container indicators
    if [[ -n "$CI" || -n "$GITHUB_ACTIONS" || -n "$GITLAB_CI" || -n "$JENKINS_URL" ]]; then
        return 0
    fi
    
    # Check for container environment files/processes
    if [[ -f /.dockerenv ]] || \
       [[ -f /run/.containerenv ]] || \
       grep -qa container /proc/1/environ 2>/dev/null || \
       [[ "$(cat /proc/1/comm 2>/dev/null)" =~ ^(systemd|bash|sh)$ ]] && [[ "$(readlink /proc/1/exe 2>/dev/null)" =~ docker|containerd ]]; then
        return 0
    fi
    
    # Check systemd container detection
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        if systemd-detect-virt --quiet --container 2>/dev/null; then
            return 0
        fi
    fi
    
    # Check for Docker/Podman/LXC specific indicators
    if [[ -n "$container" ]] || \
       [[ -f /proc/self/cgroup ]] && grep -q "/docker\|/lxc\|/podman" /proc/self/cgroup 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Check if systemd is available and functional
is_systemd_available() {
    # In containers, systemd may not be functional even if present
    if is_container_environment; then
        # In containers, be more strict about systemd availability
        if [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1; then
            return 0
        fi
        return 1
    fi
    
    # On regular systems, check if systemd is the init system
    if [[ -d /run/systemd/system ]] && [[ "$(readlink -f /sbin/init)" == *"systemd"* ]] || [[ -f /lib/systemd/systemd ]]; then
        if systemctl --version >/dev/null 2>&1 && systemctl status --no-pager >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Safe systemctl wrapper that handles container environments
safe_systemctl() {
    local operation="$1"
    local service="$2"
    local additional_args="${3:-}"
    
    if ! is_systemd_available; then
        HARDN_STATUS "warning" "systemd not available or functional, skipping: systemctl $operation $service"
        return 0
    fi
    
    case "$operation" in
        "enable"|"disable")
            if systemctl "$operation" "$service" $additional_args >/dev/null 2>&1; then
                HARDN_STATUS "pass" "Successfully executed: systemctl $operation $service"
                return 0
            else
                HARDN_STATUS "warning" "Failed to execute: systemctl $operation $service (continuing anyway)"
                return 0
            fi
            ;;
        "start"|"stop"|"restart"|"reload")
            if is_container_environment; then
                HARDN_STATUS "info" "Container environment detected, skipping: systemctl $operation $service"
                return 0
            fi
            
            if systemctl "$operation" "$service" $additional_args >/dev/null 2>&1; then
                HARDN_STATUS "pass" "Successfully executed: systemctl $operation $service"
                return 0
            else
                HARDN_STATUS "warning" "Failed to execute: systemctl $operation $service (continuing anyway)"
                return 0
            fi
            ;;
        "status")
            if systemctl "$operation" "$service" $additional_args >/dev/null 2>&1; then
                return 0
            else
                return 1
            fi
            ;;
        *)
            # For other operations, try normally but don't fail
            if systemctl "$operation" "$service" $additional_args >/dev/null 2>&1; then
                return 0
            else
                HARDN_STATUS "warning" "systemctl $operation $service failed (continuing anyway)"
                return 0
            fi
            ;;
    esac
}

export -f HARDN_STATUS
export -f is_installed
export -f hardn_msgbox
export -f hardn_infobox
export -f hardn_menu
export -f hardn_yesno
export -f is_container_environment
export -f is_systemd_available
# Safe package installation wrapper for container environments
safe_package_install() {
    local packages=("$@")
    local package_manager=""
    local install_cmd=""
    
    # Detect package manager
    if command -v apt >/dev/null 2>&1; then
        package_manager="apt"
        install_cmd="apt install -y"
    elif command -v dnf >/dev/null 2>&1; then
        package_manager="dnf"
        install_cmd="dnf install -y"
    elif command -v yum >/dev/null 2>&1; then
        package_manager="yum"
        install_cmd="yum install -y"
    elif command -v pacman >/dev/null 2>&1; then
        package_manager="pacman"
        install_cmd="pacman -S --noconfirm"
    else
        HARDN_STATUS "error" "No supported package manager found"
        return 1
    fi
    
    # Update package cache first (skip errors in containers)
    case "$package_manager" in
        "apt")
            if ! apt update >/dev/null 2>&1; then
                HARDN_STATUS "warning" "apt update failed (may be normal in containers)"
            fi
            ;;
        "dnf"|"yum")
            # DNF/YUM updates are usually fine in containers
            ;;
    esac
    
    # Install packages
    local failed_packages=()
    for package in "${packages[@]}"; do
        HARDN_STATUS "info" "Installing package: $package"
        if $install_cmd "$package" >/dev/null 2>&1; then
            HARDN_STATUS "pass" "Successfully installed: $package"
        else
            HARDN_STATUS "warning" "Failed to install: $package (may not be available in container)"
            failed_packages+=("$package")
        fi
    done
    
    # Report results
    if [[ ${#failed_packages[@]} -eq 0 ]]; then
        return 0
    elif [[ ${#failed_packages[@]} -eq ${#packages[@]} ]]; then
        HARDN_STATUS "error" "All package installations failed: ${failed_packages[*]}"
        return 1
    else
        HARDN_STATUS "warning" "Some package installations failed: ${failed_packages[*]}"
        return 0  # Partial success is OK
    fi
}

# Check for common container limitations and missing dependencies
check_container_limitations() {
    local warnings=()
    
    if is_container_environment; then
        # Check for systemd functionality
        if ! is_systemd_available; then
            warnings+=("systemd not functional - service management limited")
        fi
        
        # Check for common missing tools
        local missing_tools=()
        for tool in systemctl iptables mount modprobe; do
            if ! command -v "$tool" >/dev/null 2>&1; then
                missing_tools+=("$tool")
            fi
        done
        
        if [[ ${#missing_tools[@]} -gt 0 ]]; then
            warnings+=("missing tools: ${missing_tools[*]}")
        fi
        
        # Check for filesystem limitations
        if [[ ! -w /proc/sys ]]; then
            warnings+=("read-only /proc/sys - kernel parameter changes limited")
        fi
        
        # Check for network limitations
        if [[ ! -c /dev/net/tun ]]; then
            warnings+=("no /dev/net/tun - VPN/tunnel functionality limited")
        fi
        
        # Report warnings
        if [[ ${#warnings[@]} -gt 0 ]]; then
            HARDN_STATUS "info" "Container limitations detected:"
            for warning in "${warnings[@]}"; do
                HARDN_STATUS "warning" "  - $warning"
            done
        fi
        
        return ${#warnings[@]}
    fi
    
    return 0
}

# Safe kernel parameter modification for container environments
safe_sysctl_set() {
    local param="$1"
    local value="$2"
    local config_file="${3:-/etc/sysctl.conf}"
    
    # Check if we can modify kernel parameters
    if [[ ! -w /proc/sys ]]; then
        HARDN_STATUS "warning" "Cannot modify kernel parameter $param (read-only /proc/sys)"
        return 0
    fi
    
    # Try to set the parameter immediately
    if echo "$value" > "/proc/sys/${param//./\/}" 2>/dev/null; then
        HARDN_STATUS "pass" "Set kernel parameter: $param = $value"
    else
        HARDN_STATUS "warning" "Failed to set kernel parameter: $param = $value (may not be supported)"
        return 0
    fi
    
    # Add to persistent configuration if not in container
    if ! is_container_environment; then
        if [[ -w "$config_file" ]] || [[ ! -f "$config_file" ]]; then
            if ! grep -q "^$param.*=" "$config_file" 2>/dev/null; then
                echo "$param = $value" >> "$config_file"
                HARDN_STATUS "info" "Added persistent setting: $param = $value"
            else
                sed -i "s/^$param.*=.*/$param = $value/" "$config_file"
                HARDN_STATUS "info" "Updated persistent setting: $param = $value"
            fi
        fi
    else
        HARDN_STATUS "info" "Container environment - skipping persistent configuration for $param"
    fi
    
    return 0
}

export -f safe_sysctl_set
export -f check_container_limitations
export -f safe_package_install

# Detect OS information for scripts that need it
if [[ -f /etc/os-release ]]; then
    # Source os-release to get ID and VERSION_CODENAME
    . /etc/os-release
    export ID
    export VERSION_CODENAME
    # For compatibility, also export as CURRENT_DEBIAN_CODENAME
    export CURRENT_DEBIAN_CODENAME="${VERSION_CODENAME:-unknown}"
else
    # Fallback values
    export ID="unknown"
    export VERSION_CODENAME="unknown"
    export CURRENT_DEBIAN_CODENAME="unknown"
fi

# Module exit function - used by modules when they need to exit
# (when run standalone rather than sourced)
hardn_module_exit() {
    local exit_code="${1:-0}"
    exit "$exit_code"
}
