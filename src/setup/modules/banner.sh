#!/bin/bash

hardn_banner_configure() {
        HARDN_STATUS "info" "Setting up the HARDN XDR Banner..."

        # Configure all banner files in parallel
        {
            hardn_banner_configure_file "/etc/issue" "local logins (/etc/issue)" &
            hardn_banner_configure_file "/etc/issue.net" "remote logins (/etc/issue.net)" &
            hardn_banner_configure_file "/etc/motd" "message of the day (/etc/motd)" &
            wait
        }
}

hardn_banner_configure_file() {
        local banner_file="$1"
        local banner_description="$2"

        HARDN_STATUS "info" "Configuring STIG compliant banner for ${banner_description}..."

        if [[ -f "$banner_file" ]]; then
            cp "$banner_file" "${banner_file}.bak.$(date +%F-%T)" 2>/dev/null
        else
            touch "$banner_file"
        fi

        printf '%s\n' \
            "*************************************************************" \
            "*     ############# H A R D N - X D R ##############        *" \
            "*  This system is for the use of authorized SIG users.      *" \
            "*  Individuals using this computer system without authority *" \
            "*  or in excess of their authority are subject to having    *" \
            "*  all of their activities on this system monitored and     *" \
            "*  recorded by system personnel.                            *" \
            "*                                                           *" \
            "************************************************************" > "$banner_file"

        chmod 644 "$banner_file"
        HARDN_STATUS "pass" "STIG compliant banner configured in $banner_file."
}
