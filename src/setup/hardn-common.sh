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
export -f HARDN_STATUS
export -f is_installed
export -f hardn_msgbox
export -f hardn_infobox
export -f hardn_menu
export -f hardn_yesno

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
