######################### STIG banner (/etc/issue.net)
HARDN_STATUS "error" "Configuring STIG compliant banner for remote logins (/etc/issue.net)..."
local banner_net_file="/etc/issue.net"
if [ -f "$banner_net_file" ]; then
	# Backup existing banner file
	cp "$banner_net_file" "${banner_net_file}.bak.$(date +%F-%T)" 2>/dev/null || true
else
	touch "$banner_net_file"
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
} > "$banner_net_file"
chmod 644 "$banner_net_file"
HARDN_STATUS "pass" "STIG compliant banner configured in $banner_net_file."    
