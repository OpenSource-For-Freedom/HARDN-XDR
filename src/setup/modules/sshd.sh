#!/bin/bash
# sshd.sh - Install and basic setup for OpenSSH server

set -e

# Universal package installer
is_installed() {
    command -v "$1" &>/dev/null
}

# Install OpenSSH server
if is_installed apt-get; then
    sudo apt-get update
    sudo apt-get install -y openssh-server
elif is_installed yum; then
    sudo yum install -y openssh-server
elif is_installed dnf; then
    sudo dnf install -y openssh-server
else
    echo "Unsupported package manager. Please install OpenSSH server manually."
    exit 1
fi

# Define the service name
# On Debian/Ubuntu, the service is ssh.service, and sshd.service is a symlink.
# On RHEL/CentOS, the service is sshd.service.
# We will prefer the canonical name to avoid issues with aliases.
if systemctl list-unit-files | grep -q -w "ssh.service"; then
    SERVICE_NAME="ssh.service"
elif systemctl list-unit-files | grep -q -w "sshd.service"; then
    SERVICE_NAME="sshd.service"
else
    echo "Could not find sshd or ssh service."
    exit 1
fi

# Enable and start sshd service
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"

# STIG-compliant SSH configuration: FIPS ciphers, MACs, and security settings
SSHD_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSHD_CONFIG" ]; then
    # Backup original config
    sudo cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%F-%T)"
    
    # Create STIG-compliant SSH configuration
    sudo tee "${SSHD_CONFIG}.hardn" > /dev/null << 'EOF'
# HARDN-XDR STIG Compliant SSH Configuration
# Based on DISA STIG requirements for SSH hardening

# Network settings
Port 22
AddressFamily inet
ListenAddress 0.0.0.0

# Authentication settings
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# FIPS-approved ciphers (STIG requirement)
Ciphers aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-256,hmac-sha2-512

# Key exchange algorithms (FIPS-approved)
KexAlgorithms diffie-hellman-group14-sha256,diffie-hellman-group16-sha512,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521

# Host key algorithms (FIPS-approved)
HostKeyAlgorithms rsa-sha2-256,rsa-sha2-512,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521

# Protocol and security settings
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Login restrictions
LoginGraceTime 60
MaxAuthTries 3
MaxSessions 4
MaxStartups 10:30:60

# Session settings
ClientAliveInterval 900
ClientAliveCountMax 0
TCPKeepAlive no
Compression no

# Forwarding restrictions
AllowTcpForwarding no
AllowStreamLocalForwarding no
GatewayPorts no
PermitTunnel no
X11Forwarding no
AllowAgentForwarding no

# Environment restrictions
PermitUserEnvironment no
AcceptEnv LANG LC_*
PrintMotd no
PrintLastLog yes

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# SFTP configuration
Subsystem sftp internal-sftp -l INFO -f AUTH

# Banner
Banner /etc/ssh/ssh_banner
EOF

    # Create SSH banner file
    sudo tee /etc/ssh/ssh_banner > /dev/null << 'EOF'
***************************************************************************
                            NOTICE TO USERS
***************************************************************************

This computer system is the private property of its owner, whether
individual, corporate or government. It is for authorized use only.
Users (authorized or unauthorized) have no explicit or implicit
expectation of privacy.

Any or all uses of this system and all files on this system may be
intercepted, monitored, recorded, copied, audited, inspected, and
disclosed to your employer, to authorized site, government, and law
enforcement personnel, as well as authorized officials of government
agencies, both domestic and foreign.

By using this system, the user consents to such interception, monitoring,
recording, copying, auditing, inspection, and disclosure at the
discretion of such personnel or officials. Unauthorized or improper use
of this system may result in civil and criminal penalties and
administrative or disciplinary action, as appropriate. By continuing to
use this system you indicate your awareness of and consent to these terms
and conditions of use. LOG OFF IMMEDIATELY if you do not agree to the
conditions stated in this warning.

***************************************************************************
EOF

    # Replace original config with hardened version
    sudo mv "${SSHD_CONFIG}.hardn" "$SSHD_CONFIG"
    sudo chmod 644 "$SSHD_CONFIG"
    sudo chown root:root "$SSHD_CONFIG"
    
    echo "STIG-compliant SSH configuration applied with FIPS-approved ciphers and MACs."
    echo "Original configuration backed up to ${SSHD_CONFIG}.bak.$(date +%F-%T)"
else
    echo "Warning: $SSHD_CONFIG not found. Skipping configuration."
fi

# Validate SSH configuration before restarting
if sudo sshd -t; then
    echo "SSH configuration validation successful"
    # Restart sshd to apply changes
    sudo systemctl restart "$SERVICE_NAME"
    echo "SSH service restarted with STIG-compliant configuration"
else
    echo "ERROR: SSH configuration validation failed. Restoring backup."
    sudo mv "${SSHD_CONFIG}.bak.$(date +%F-%T)" "$SSHD_CONFIG"
    exit 1
fi

echo "OpenSSH server installed and basic setup complete."