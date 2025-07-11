#!/bin/bash

# Auto-detect CI environment and skip whiptail
if [[ -n "$CI" || -n "$GITHUB_ACTIONS" || -n "$GITLAB_CI" || -n "$JENKINS_URL" || ! -t 0 ]]; then
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

# Universal package
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

# Standardized whiptail helper functions
HARDN_WHIPTAIL_TITLE="HARDN-XDR v${HARDN_VERSION:-1.1.50}"


HARDN_WHIPTAIL_WIDTH=70
HARDN_WHIPTAIL_HEIGHT=15
HARDN_WHIPTAIL_MENU_HEIGHT=8

# Standardized whiptail msgbox with CI detection
hardn_msgbox() {
    local message="$1"
    local height="${2:-$HARDN_WHIPTAIL_HEIGHT}"
    local width="${3:-$HARDN_WHIPTAIL_WIDTH}"

    if [[ "$SKIP_WHIPTAIL" == "1" ]]; then
        HARDN_STATUS "info" "$message"
        return 0
    fi

    if ! command -v whiptail >/dev/null 2>&1; then
        HARDN_STATUS "warning" "whiptail not available: $message"
        return 0
    fi

    whiptail --title "$HARDN_WHIPTAIL_TITLE" --msgbox "$message" "$height" "$width"
}

# Standardized whiptail infobox with CI detection
hardn_infobox() {
    local message="$1"
    local height="${2:-$HARDN_WHIPTAIL_HEIGHT}"
    local width="${3:-$HARDN_WHIPTAIL_WIDTH}"

    if [[ "$SKIP_WHIPTAIL" == "1" ]]; then
        HARDN_STATUS "info" "$message"
        return 0
    fi

    if ! command -v whiptail >/dev/null 2>&1; then
        HARDN_STATUS "warning" "whiptail not available: $message"
        return 0
    fi

    whiptail --title "$HARDN_WHIPTAIL_TITLE" --infobox "$message" "$height" "$width"
}

# Standardized whiptail menu with CI detection
hardn_menu() {
    local message="$1"
    local height="${2:-$HARDN_WHIPTAIL_HEIGHT}"
    local width="${3:-$HARDN_WHIPTAIL_WIDTH}"
    local menu_height="${4:-$HARDN_WHIPTAIL_MENU_HEIGHT}"
    shift 4
    local options=("$@")

    if [[ "$SKIP_WHIPTAIL" == "1" ]]; then
        HARDN_STATUS "info" "Auto-selecting first option for: $message"
        echo "${options[1]}"  # Return first option value
        return 0
    fi

    if ! command -v whiptail >/dev/null 2>&1; then
        HARDN_STATUS "warning" "whiptail not available, auto-selecting first option for: $message"
        echo "${options[1]}"
        return 0
    fi

    whiptail --title "$HARDN_WHIPTAIL_TITLE" --menu "$message" "$height" "$width" "$menu_height" "${options[@]}"
}

# Standardized whiptail yesno with CI detection
hardn_yesno() {
    local message="$1"
    local height="${2:-$HARDN_WHIPTAIL_HEIGHT}"
    local width="${3:-$HARDN_WHIPTAIL_WIDTH}"

    if [[ "$SKIP_WHIPTAIL" == "1" ]]; then
        HARDN_STATUS "info" "Auto-confirming: $message"
        return 0  # Default to "yes" in CI
    fi

    if ! command -v whiptail >/dev/null 2>&1; then
        HARDN_STATUS "warning" "whiptail not available, auto-confirming: $message"
        return 0
    fi

    whiptail --title "$HARDN_WHIPTAIL_TITLE" --yesno "$message" "$height" "$width"
}

# Export variables for all files
export -f HARDN_STATUS
export -f is_installed
export -f hardn_msgbox
export -f hardn_infobox
export -f hardn_menu
export -f hardn_yesno
