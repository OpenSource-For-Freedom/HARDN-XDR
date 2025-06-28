#######################################
# Banner settings
# This module handles the banner
#######################################


HARDN_STATUS "info" "Setting up the HARDN XDR Banner..."


configure_stig_banner() {
        local banner_file="$1"
        local banner_description="$2"

        HARDN_STATUS "info" "Configuring STIG compliant banner for ${banner_description}..."

        if [ -f "$banner_file" ]; then
            # Backup existing banner file
            cp "$banner_file" "${banner_file}.bak.$(date +%F-%T)" 2>/dev/null || true
        else
            touch "$banner_file"
        fi

        # Write the STIG compliant banner
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

# Configure banner for remote logins
configure_stig_banner "/etc/issue.net" "remote logins (/etc/issue.net)"


