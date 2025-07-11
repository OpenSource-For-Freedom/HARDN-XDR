#!/bin/bash

# Minimized external processes
# Optimized to reduce external commands like grep
# Using Bash built-ins instead


# Prevent execution of functions when sourced multiple times
if [ -z "${_HARDN_PROCESS_ACCOUNTING_SOURCED:-}" ]; then
    _HARDN_PROCESS_ACCOUNTING_SOURCED=1

    # Check if a package is installed across different package managers
hardn_process_accounting_is_installed() {
    local pkg="$1"
    local pkg_manager=""

    # Determine which package manager to use
    for cmd in dpkg rpm dnf yum; do
        if command -v "$cmd" >/dev/null 2>&1; then
            : "$cmd"
            pkg_manager="$_"
            break
        fi
    done

    # Check if package is installed using the detected package manager
    case "$pkg_manager" in
        dpkg)    dpkg -s "$pkg" >/dev/null 2>&1 ;;
        rpm)     rpm -q "$pkg" >/dev/null 2>&1 ;;
        dnf)     dnf list installed "$pkg" >/dev/null 2>&1 ;;
        yum)     yum list installed "$pkg" >/dev/null 2>&1 ;;
        *)       return 1 ;;
    esac
}

hardn_process_accounting_setup_acct() {
        local changed_acct=false
        local pkg_status=""
        local service_status=""

        HARDN_STATUS "info" "Checking and installing acct (process accounting)..."

        if ! hardn_process_accounting_is_installed acct && ! hardn_process_accounting_is_installed psacct; then
            : "not_installed"
        else
            : "installed"
        fi
        pkg_status="$_"

        case "$pkg_status" in
            not_installed)
                if apt-get install -y acct >/dev/null 2>&1; then
                    HARDN_STATUS "pass" "acct installed successfully."
                    changed_acct=true
                else
                    HARDN_STATUS "error" "Failed to install acct. Please check manually."
                fi
                ;;
            installed)
                HARDN_STATUS "info" "acct/psacct is already installed."
                ;;
        esac

        if hardn_process_accounting_is_installed acct || hardn_process_accounting_is_installed psacct; then
            if ! systemctl is-active --quiet acct && ! systemctl is-active --quiet psacct; then
                : "inactive"
            else
                : "active"
            fi
            service_status="$_"

            # Handle service activation based on status
            case "$service_status" in
                inactive)
                    HARDN_STATUS "info" "Enabling and starting acct/psacct service..."
                    if systemctl enable --now acct 2>/dev/null || systemctl enable --now psacct 2>/dev/null; then
                        HARDN_STATUS "pass" "acct/psacct service enabled and started."
                        changed_acct=true
                    fi
                    ;;
                active)
                    HARDN_STATUS "pass" "acct/psacct service is already active."
                    ;;
            esac
        fi

        echo "$changed_acct"
}

hardn_process_accounting_setup_sysstat() {
    local changed_sysstat=false
    local sysstat_conf="/etc/default/sysstat"
    #local pkg_status service_status config_status

    HARDN_STATUS "info" "Checking and installing sysstat..."

    # Determine package status
    if hardn_process_accounting_is_installed sysstat; then
        : "installed"
    else
        : "not_installed"
    fi
    pkg_status="$_"

    case "$pkg_status" in
        not_installed)
            if apt-get install -y sysstat >/dev/null 2>&1; then
                HARDN_STATUS "pass" "sysstat installed successfully."
                changed_sysstat=true
                pkg_status="installed"  # Update status after successful installation
            else
                HARDN_STATUS "error" "Failed to install sysstat. Please check manually."
                echo "$changed_sysstat"
                return 1
            fi
            ;;
        installed)
            HARDN_STATUS "info" "sysstat is already installed."
            ;;
    esac

    # Only proceed if sysstat is installed
    [[ "$pkg_status" != "installed" ]] && { echo "$changed_sysstat"; return 0; }

    # Check configuration file status
    if [[ -f "$sysstat_conf" ]]; then
            HARDN_STATUS "info" "Enabling sysstat data collection..."

            # Process the configuration file in a single pass
            local temp_conf
            temp_conf=$(mktemp)
            local has_enabled=false
            local modified=false

            # Process the file in a single pass using the Bash built-in read
            while IFS= read -r line || [[ -n "$line" ]]; do
                if [[ "$line" =~ ^[[:space:]]*ENABLED= ]]; then
                    has_enabled=true
                    if [[ ! "$line" =~ ^[[:space:]]*ENABLED="true" ]]; then
                        echo 'ENABLED="true"' >> "$temp_conf"
                        modified=true
                    else
                        echo "$line" >> "$temp_conf"
                    fi
                else
                    echo "$line" >> "$temp_conf"
                fi
            done < "$sysstat_conf"

            # Add ENABLED="true" if it doesn't exist
            if [[ "$has_enabled" = false ]]; then
                echo 'ENABLED="true"' >> "$temp_conf"
                modified=true
            fi

            # Replace the file only if changes were made
            if [[ "$modified" = true ]]; then
                mv "$temp_conf" "$sysstat_conf"
                changed_sysstat=true
                HARDN_STATUS "pass" "sysstat data collection enabled."
            else
                rm -f "$temp_conf"
                HARDN_STATUS "pass" "sysstat data collection is already enabled."
            fi
    else
        : "missing"
    fi
    #config_status="$_"

    # Check service status
    if systemctl is-active --quiet sysstat; then
        : "active"
    else
        : "inactive"
    fi
    service_status="$_"

    # Handle service activation based on status
    case "$service_status" in
        inactive)
            HARDN_STATUS "info" "Enabling and starting sysstat service..."
            if systemctl enable --now sysstat >/dev/null 2>&1; then
                HARDN_STATUS "pass" "sysstat service enabled and started."
                changed_sysstat=true
            else
                HARDN_STATUS "error" "Failed to enable/start sysstat service."
            fi
            ;;
        active)
            HARDN_STATUS "pass" "sysstat service is already active."
            ;;
    esac

    echo "$changed_sysstat"
}

hardn_process_accounting_setup() {
        HARDN_STATUS "info" "Enabling process accounting (acct) and system statistics (sysstat)..."

        local acct_tmp
        acct_tmp=$(mktemp)

        local sysstat_tmp
        sysstat_tmp=$(mktemp)

        hardn_process_accounting_setup_acct > "$acct_tmp" &
        local acct_pid=$!

        hardn_process_accounting_setup_sysstat > "$sysstat_tmp" &
        local sysstat_pid=$!

        # Wait for both processes to complete
        wait $acct_pid $sysstat_pid

        local changed_acct
        changed_acct=$(cat "$acct_tmp")

        local changed_sysstat
        changed_sysstat=$(cat "$sysstat_tmp")

        # Clean up temp files
        rm -f "$acct_tmp" "$sysstat_tmp"

        if [[ "$changed_acct" = true || "$changed_sysstat" = true ]]; then
            HARDN_STATUS "pass" "Process accounting and sysstat configured successfully."
        else
            HARDN_STATUS "pass" "Process accounting and sysstat already configured or no changes needed."
        fi
}

fi
