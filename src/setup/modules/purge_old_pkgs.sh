#!/bin/bash

# Module for purging old package configurations and cleaning apt cache
# This script is designed to be sourced by hardn-main.sh

hardn_is_package_installed() {
    local pkg="$1"
    local _=1
    local cmd=""

    # Check for package managers without subshell
    command -v apt >/dev/null 2>&1 && cmd="apt"
    [ -z "$cmd" ] && command -v dnf >/dev/null 2>&1 && cmd="dnf"
    [ -z "$cmd" ] && command -v yum >/dev/null 2>&1 && cmd="yum"
    [ -z "$cmd" ] && command -v rpm >/dev/null 2>&1 && cmd="rpm"

    case "$cmd" in
        apt) dpkg -s "$pkg" >/dev/null 2>&1 ;;
        dnf) dnf list installed "$pkg" >/dev/null 2>&1 ;;
        yum) yum list installed "$pkg" >/dev/null 2>&1 ;;
        rpm) rpm -q "$pkg" >/dev/null 2>&1 ;;
        *) : ;;
    esac

    _=$?
    return $_
}

hardn_ensure_whiptail() {
    if ! hardn_is_package_installed whiptail; then
        apt-get install -y whiptail >/dev/null 2>&1
    fi
}

# Purge a single package and handle failures
hardn_purge_package() {
    local pkg="$1"
    local status=0
    local method=""

    HARDN_STATUS "error" "Purging $pkg..."

    # Try apt-get purge first
    apt-get purge -y "$pkg" >/dev/null 2>&1
    status=$?

    case $status in
        0)
            method="apt-get"
            : # Success with apt-get
            ;;
        *)
            # Try dpkg as fallback
            HARDN_STATUS "error" "Failed to purge $pkg with apt-get. Trying dpkg --purge..."
            dpkg --purge "$pkg" >/dev/null 2>&1
            status=$?
            method="dpkg"
            ;;
    esac

    # Report final status
    case $status in
        0)
            HARDN_STATUS "pass" "Successfully purged $pkg with $method."
            ;;
        *)
            HARDN_STATUS "error" "Failed to purge $pkg with both apt-get and dpkg."
            ;;
    esac

    return $status
}

# Optimizations:
# Using only Bash built-in features, eliminating external processes: awk & grep
# reduces the number of forks and external processes
hardn_get_packages_to_purge() {
    local line pkg_list=""

    # Read dpkg output directly and process with bash
    while read -r line; do
        # Check if line starts with 'rc' (removed but config files remain)
        if [[ "${line:0:2}" == "rc" ]]; then
            # Extract the second field (package name)
            read -r _ pkg _ <<< "$line"
            pkg_list+="$pkg"$'\n'
        fi
    done < <(dpkg -l)

    # Remove trailing newline and return result
    echo "${pkg_list%$'\n'}"
}

# Main function to purge old package configurations
hardn_purge_old_packages() {
    HARDN_STATUS "error" "Purging configuration files of old/removed packages..."

    # Check if system is Debian-based
    if ! command -v dpkg >/dev/null 2>&1; then
        HARDN_STATUS "warning" "This script is intended for Debian-based systems. Skipping."
        return 1
    fi

    # Ensure whiptail is available
    hardn_ensure_whiptail

    # Get packages to purge
    local packages_to_purge
    packages_to_purge=$(hardn_get_packages_to_purge)

    if [[ -n "$packages_to_purge" ]]; then
        HARDN_STATUS "info" "Found the following packages with leftover configuration files to purge:"
        printf "%s\n" "$packages_to_purge"

        if command -v whiptail >/dev/null; then
            whiptail --title "Packages to Purge" --msgbox "The following packages have leftover configuration files that will be purged:\n\n$packages_to_purge" 15 70
        fi

        # Use xargs for parallel processing if many packages
        if [[ $(echo "$packages_to_purge" | wc -l) -gt 5 ]]; then
            echo "$packages_to_purge" | xargs -P "$(nproc)" -I{} bash -c 'hardn_purge_package "{}"'
        else
            # For fewer packages, process sequentially for better error handling
            for pkg in $packages_to_purge; do
                hardn_purge_package "$pkg"
            done
        fi

        whiptail --infobox "Purged configuration files for removed packages." 7 70
    else
        HARDN_STATUS "pass" "No old/removed packages with leftover configuration files found to purge."
        whiptail --infobox "No leftover package configurations to purge." 7 70
    fi

    return 0
}

hardn_clean_apt_cache() {
        HARDN_STATUS "error" "Running apt-get autoremove and clean to free up space..."
        apt-get autoremove -y
        apt-get clean
        whiptail --infobox "Apt cache cleaned." 7 70
}

hardn_purge_module_main() {
        hardn_purge_old_packages
        hardn_clean_apt_cache
}
