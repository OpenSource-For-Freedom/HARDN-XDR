#!/bin/bash

#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

HARDN_STATUS "info" "Setting up the HARDN XDR Banner..."

configure_stig_banner() {
    local banner_file="$1"
    local banner_description="$2"

    HARDN_STATUS "info" "Configuring STIG compliant banner for ${banner_description}..."

    if [ -f "$banner_file" ]; then
        cp "$banner_file" "${banner_file}.bak.$(date +%F-%T)" 2>/dev/null || true
    else
        touch "$banner_file"
    fi

    {
        echo "*************************************************************"
        echo "*     ############# H A R D N - X D R ##############        *"
        echo "*  This system is for the use of authorized SIG users.      *"
        echo "*  Individuals using this computer system without authority *"
        echo "*  or in excess of their authority are subject to having    *"
        echo "*  all of their activities on this system monitored and     *"
        echo "*  recorded by system personnel.                            *"
        echo "*                                                           *"
        echo "************************************************************"
    } > "$banner_file"

    chmod 644 "$banner_file"
    HARDN_STATUS "pass" "STIG compliant banner configured in $banner_file."
}

# Configure banner for local logins
configure_stig_banner "/etc/issue" "local logins (/etc/issue)"

# Configure banner for remote logins
configure_stig_banner "/etc/issue.net" "remote logins (/etc/issue.net)"

# Configure banner for message of the day
configure_stig_banner "/etc/motd" "message of the day (/etc/motd)"

HARDN_STATUS "pass" "All HARDN-XDR banners configured successfully."
