#!/bin/bash


# Detect and cache the package manager if not already set
hardn_detect_pkg_manager() {
        if [[ -n "${HARDN_PKG_MANAGER:-}" ]]; then
            return 0  # Already set externally
        fi

        if command -v apt >/dev/null 2>&1; then
            : "apt"
        elif command -v dnf >/dev/null 2>&1; then
            : "dnf"
        elif command -v yum >/dev/null 2>&1; then
            : "yum"
        elif command -v rpm >/dev/null 2>&1; then
            : "rpm"
        else
            : "unknown"
        fi

    HARDN_PKG_MANAGER="$_"
}

# Check if a package is installed using the appropriate package manager
hardn_ntp_is_installed() {
        local package="$1"
        hardn_detect_pkg_manager

        case "$HARDN_PKG_MANAGER" in
            *apt*) dpkg -s "$package" >/dev/null 2>&1 ;;
            *dnf*) dnf list installed "$package" >/dev/null 2>&1 ;;
            *yum*) yum list installed "$package" >/dev/null 2>&1 ;;
            *rpm*) rpm -q "$package" >/dev/null 2>&1 ;;
        esac
}


# Install a package using the appropriate package manager
hardn_ntp_install_package() {
        local package="$1"
        hardn_detect_pkg_manager

        # Use `:` and `$_` simple-case idiom Clean, fast, repeatable avoids `variable=` repetition
        case "$HARDN_PKG_MANAGER" in
            apt)
                apt-get update -qq && apt-get install -y "$package" >/dev/null 2>&1
            ;;
            dnf)
                dnf install -y "$package" >/dev/null 2>&1
            ;;
            yum)
                yum install -y "$package" >/dev/null 2>&1
            ;;
            rpm)
                rpm -ivh "$package" >/dev/null 2>&1
            ;;
            *)
                return 1

                ;;
         esac
}

# Check NTP stratum and warn if too high
hardn_ntp_check_stratum() {
        local stratum line

        # Avoid subshell: process ntpq output line-by-line in a loop
        while IFS= read -r line; do
            case "$line" in
                stratum=*)
                    stratum=${line#stratum=}
                    break
                ;;
            esac
            # uses process substitution to capture the line content
        done < <(ntpq -c rv 2>/dev/null)

        if [[ -n "$stratum" && "$stratum" -gt 2 ]]; then
            HARDN_STATUS "warning" "NTP is synchronized but using a high stratum peer (stratum $stratum). Consider using a lower stratum (closer to 1) for better accuracy."
        fi
}

# Configure systemd-timesyncd
hardn_ntp_configure_timesyncd() {
        local ntp_servers="$1"
        local timesyncd_conf="/etc/systemd/timesyncd.conf"
        local temp_timesyncd_conf
        local configured=false

        temp_timesyncd_conf=$(mktemp)

        # Create config file if it doesn't exist
        if [[ ! -f "$timesyncd_conf" ]]; then
            HARDN_STATUS "info" "Creating $timesyncd_conf as it does not exist."
            printf "[Time]\n" > "$timesyncd_conf"
            chmod 644 "$timesyncd_conf"
        fi

        cp "$timesyncd_conf" "$temp_timesyncd_conf"

        # Update NTP servers configuration
        if grep -qE "^\s*NTP=" "$temp_timesyncd_conf"; then
            sed -i -E "s/^\s*NTP=.*/NTP=$ntp_servers/" "$temp_timesyncd_conf"
        else
            if grep -q "\[Time\]" "$temp_timesyncd_conf"; then
                sed -i "/\[Time\]/a NTP=$ntp_servers" "$temp_timesyncd_conf"
            else
                printf "\n[Time]\nNTP=%s\n" "$ntp_servers" >> "$temp_timesyncd_conf"
            fi
        fi

        # Apply changes if needed
        if ! cmp -s "$temp_timesyncd_conf" "$timesyncd_conf"; then
            cp "$temp_timesyncd_conf" "$timesyncd_conf"
            HARDN_STATUS "pass" "Updated $timesyncd_conf. Restarting systemd-timesyncd..."
            if systemctl restart systemd-timesyncd; then
                HARDN_STATUS "pass" "systemd-timesyncd restarted successfully."
                configured=true
            else
                HARDN_STATUS "error" "Failed to restart systemd-timesyncd. Manual check required."
            fi
        else
            HARDN_STATUS "info" "No effective changes to $timesyncd_conf were needed."
            configured=true
        fi

        rm -f "$temp_timesyncd_conf"

        # Check synchronization status and stratum
        if timedatectl show-timesync --property=ServerAddress,NTP,Synchronized 2>/dev/null | grep -q "Synchronized=yes"; then
            hardn_ntp_check_stratum
        fi

        echo "$configured"
}

# Configure ntpd
hardn_ntp_configure_ntpd() {
    local ntp_servers="$1"
    local ntp_conf="/etc/ntp.conf"
    local temp_ntp_conf
    local configured=false

    # Check if the configuration file exists and is writable
    if [[ -f "$ntp_conf" && -w "$ntp_conf" ]]; then
        HARDN_STATUS "info" "Configuring $ntp_conf..."
        # Backup existing config
        cp "$ntp_conf" "${ntp_conf}.bak.$(date +%F-%T)" 2>/dev/null || true

        # Update NTP servers configuration
        temp_ntp_conf=$(mktemp)
        grep -vE "^\s*(pool|server)\s+" "$ntp_conf" > "$temp_ntp_conf"

        {
            printf "# HARDN-XDR configured NTP servers\n"
            for server in $ntp_servers; do
                printf "pool %s iburst\n" "$server"
            done
        } >> "$temp_ntp_conf"

        # Apply changes if needed
        if ! cmp -s "$temp_ntp_conf" "$ntp_conf"; then
            mv "$temp_ntp_conf" "$ntp_conf"
            HARDN_STATUS "pass" "Updated $ntp_conf with recommended pool servers."

            # Restart/Enable ntp service
            if systemctl enable --now ntp; then
                HARDN_STATUS "pass" "ntp service enabled and started successfully."
                configured=true
            else
                HARDN_STATUS "error" "Failed to enable/start ntp service. Manual check required."
            fi
        else
            HARDN_STATUS "info" "No effective changes to $ntp_conf were needed."
            configured=true
        fi

        rm -f "$temp_ntp_conf"

        # Check synchronization status and stratum
        if ntpq -p 2>/dev/null | grep -q '^\*'; then
            hardn_ntp_check_stratum
        fi
    else
        HARDN_STATUS "error" "NTP configuration file $ntp_conf not found or not writable. Skipping NTP configuration."
    fi

    echo "$configured"
}

# Main function to setup NTP
hardn_ntp_setup() {
        local ntp_servers="0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org"
        local configured=false
        local ntp_impl=""

        HARDN_STATUS "info" "Setting up NTP daemon..."

        # Determine NTP implementation using case statement
        if systemctl is-active --quiet systemd-timesyncd; then
            : "timesyncd"
        else
            : "ntpd"
        fi
        ntp_impl="$_"

        # Configure the appropriate NTP implementation
        case "$ntp_impl" in
            timesyncd)
                HARDN_STATUS "info" "systemd-timesyncd is active. Configuring..."
                configured=$(hardn_ntp_configure_timesyncd "$ntp_servers")
                ;;
            ntpd)
                HARDN_STATUS "info" "systemd-timesyncd is not active. Checking/Configuring ntpd..."

                # Handle NTP package installation if needed
                if ! hardn_ntp_is_installed ntp; then
                    HARDN_STATUS "info" "ntp package not found. Attempting to install..."
                    hardn_ntp_install_package ntp &
                    wait $!

                    if ! hardn_ntp_is_installed ntp; then
                        HARDN_STATUS "error" "Failed to install ntp package. Skipping NTP configuration."
                        configured=false
                        return
                    fi
                    HARDN_STATUS "pass" "ntp package installed successfully."
                else
                    HARDN_STATUS "pass" "ntp package is already installed."
                fi

                configured=$(hardn_ntp_configure_ntpd "$ntp_servers")
                ;;
        esac

        # Final status report using ternary-like construct
         if [[ "$configured" = true ]]; then
             HARDN_STATUS "pass" "NTP configuration attempt completed."
             else
             HARDN_STATUS "error" "NTP configuration attempt failed. Manual check required."
         fi

 }
