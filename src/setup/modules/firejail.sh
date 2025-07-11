#!/bin/bash

# Firejail configuration module for HARDN-XDR
# This script is meant to be sourced by hardn-main.sh

hardn_firejail_is_installed() {
        local pkg="$1"

        # First check which package manager is available
        local pkg_manager=""
        if command -v dpkg >/dev/null 2>&1; then
            pkg_manager="dpkg"
        elif command -v rpm >/dev/null 2>&1; then
            pkg_manager="rpm"
        elif command -v dnf >/dev/null 2>&1; then
            pkg_manager="dnf"
        elif command -v yum >/dev/null 2>&1; then
            pkg_manager="yum"
        fi

        # Then use the appropriate command to check if package is installed
        local is_installed=1
        case "$pkg_manager" in
            dpkg)   dpkg -s "$pkg" >/dev/null 2>&1; is_installed=$? ;;
            rpm)    rpm -q "$pkg" >/dev/null 2>&1; is_installed=$? ;;
            dnf)    dnf list installed "$pkg" >/dev/null 2>&1; is_installed=$? ;;
            yum)    yum list installed "$pkg" >/dev/null 2>&1; is_installed=$? ;;
            *)      is_installed=1 ;;
        esac

        return $is_installed
}

hardn_firejail_install() {
        # Skip if already installed
        hardn_firejail_is_installed firejail && return 0

        HARDN_STATUS "info" "Firejail not found. Installing..."
        if apt-get install -y firejail >/dev/null 2>&1; then
            HARDN_STATUS "pass" "Firejail installed successfully."
            return 0
        else
            HARDN_STATUS "error" "Failed to install Firejail."
            return 1
        fi
}

hardn_firejail_create_profile() {
        local app="$1"
        local profile_dir="/etc/firejail"
        local profile_name

        # Remove possible path and extension for profile name
        profile_name=$(basename "$app" | cut -d. -f1)

        # Skip if profile already exists
        [[ -f "${profile_dir}/${profile_name}.profile" ]] && {
            HARDN_STATUS "debug" "Firejail profile for ${profile_name} already exists."
            return 0
        }

        HARDN_STATUS "info" "Creating Firejail profile for ${profile_name}..."

        # Create profile with secure defaults
        if cat > "${profile_dir}/${profile_name}.profile" << EOF
# Firejail profile for ${profile_name}
include /etc/firejail/firejail.config
private
net none
caps.drop all
seccomp
private-etc
private-dev
nosound
nodbus
noexec
nohome
nonewprivs
noroot
nooverlay
nodns
no3d
EOF
        then
            HARDN_STATUS "pass" "Created Firejail profile for ${profile_name}"
            return 0
        else
            HARDN_STATUS "error" "Failed to create Firejail profile for ${profile_name}"
            return 1
        fi
}

hardn_firejail_find_browsers() {
        local browsers="$1"
        local found=()
        local browser

        for browser in $browsers; do
            if command -v "$browser" >/dev/null 2>&1; then
                found+=("$browser")
            fi
        done

        # Return found browsers as space-separated string
        echo "${found[*]}"
}

hardn_firejail_create_browser_profile() {
        local browser="$1"

        HARDN_STATUS "info" "Creating Firejail profile for $browser..."
        if hardn_firejail_create_profile "$browser"; then
            HARDN_STATUS "pass" "Firejail profile for $browser created successfully"
            return 0
        else
            HARDN_STATUS "warn" "Failed to create Firejail profile for $browser"
            return 1
        fi
}

# Process multiple browser profiles in parallel
hardn_firejail_process_parallel() {
        local browsers=("$@")
        local count=${#browsers[@]}
        local pipe_name
        local collector_pid
        local status_file

        HARDN_STATUS "info" "Creating $count Firejail profiles in parallel..."

        # Create temporary files for communication
        pipe_name=$(mktemp -u)
        status_file=$(mktemp)
        echo "0" > "$status_file"  # Initialize status file

        if ! mkfifo "$pipe_name"; then
            HARDN_STATUS "error" "Failed to create communication pipe"
            rm -f "$status_file"
            return 1
        fi

        # Start error collector in background
        {
            while read -r failed_browser; do
                if [ -n "$failed_browser" ]; then
                    echo "1" > "$status_file"  # Write to shared status file
                    HARDN_STATUS "debug" "Failed to create profile for: $failed_browser"
                fi
            done < "$pipe_name"
            rm -f "$pipe_name"
        } &
        collector_pid=$!

        # Process browsers with limited concurrency
        # Create a wrapper script for xargs to use
        temp_script=$(mktemp)
        cat > "$temp_script" << 'EOF'
#!/bin/bash
browser="$1"
pipe="$2"
if ! "$PROFILE_FUNC" "$browser"; then
    echo "$browser" > "$pipe"
fi
EOF
        chmod +x "$temp_script"

        # Execute with environment variable
        export PROFILE_FUNC="hardn_firejail_create_profile"
        printf "%s\0" "${browsers[@]}" | xargs -0 -P 4 -I{} "$temp_script" {} "$pipe_name"

        # Clean up
        rm -f "$temp_script"

        # Wait for collector to finish
        wait "$collector_pid"

        # Read the status from file
        local failed
        failed=$(cat "$status_file")
        rm -f "$status_file"

        return "$failed"
}

# Setup Firejail profiles for common browsers
hardn_firejail_setup_browser_profiles() {
        local browser_list="firefox chromium chromium-browser google-chrome brave-browser opera vivaldi midori epiphany"
        local found_browsers

        if ! mkdir -p /etc/firejail; then
            HARDN_STATUS "error" "Failed to create /etc/firejail directory"
            return 1
        fi

        found_browsers=("$(hardn_firejail_find_browsers "$browser_list")")

        # Exit early if no browsers found
        if [ ${#found_browsers[@]} -eq 0 ]; then
            HARDN_STATUS "info" "No supported browsers found for Firejail profiles"
            return 0
        fi

        if [ ${#found_browsers[@]} -eq 1 ]; then
            # Single browser - process directly
            hardn_firejail_create_browser_profile "${found_browsers[0]}"
            return $?
        else
            # Multiple browsers - process in PARALLEL
            hardn_firejail_process_parallel "${found_browsers[@]}"
            local status=$?

            if [ $status -eq 0 ]; then
                HARDN_STATUS "pass" "All Firejail browser profiles created successfully"
            else
                HARDN_STATUS "warn" "Some Firejail browser profiles could not be created"
            fi

            return $status
        fi
}


# SOURCE THIS SCRIPT ONLY!
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    printf "Error: This script should be sourced by hardn-main.sh, not executed directly.\n" >&2
    exit 1
fi
