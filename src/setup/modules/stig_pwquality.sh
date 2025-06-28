######################## STIG-PAM Password Quality
HARDN_STATUS "info" "Configuring PAM password quality..."
if [ -f /etc/pam.d/common-password ]; then
	if ! grep -q "pam_pwquality.so" /etc/pam.d/common-password; then
		echo "password requisite pam_pwquality.so retry=3 minlen=8 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1" >> /etc/pam.d/common-password
	fi
else
	HARDN_STATUS "warning" "Warning: /etc/pam.d/common-password not found, skipping PAM configuration..."
fi
