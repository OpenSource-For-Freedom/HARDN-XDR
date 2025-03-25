#!/bin/bash
# shifting from py to shell as per @bmatei's suggestion****

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Function to execute a command and handle errors
exec_command() {
  echo "Executing: $*"
  if ! "$@"; then
    echo "Error executing: $*"
    exit 1
  fi
}

# Install required APT packages
# wil still install SELinux but not config at this time - Tim
install_apt_dependencies() {
  apt_dependencies=(
    "apparmor" "apparmor-profiles" "apparmor-utils" "firejail" "libpam-pwquality"
    "tcpd" "fail2ban" "rkhunter" "aide" "aide-common" "ufw" "postfix" "debsums"
    "python3-pexpect" "python3-tk" "policycoreutils" "selinux-utils" "selinux-basics" "docker.io"
  )

  for package in "${apt_dependencies[@]}"; do
    echo "Checking for $package..."
    if ! dpkg -s "$package" &>/dev/null; then
      echo "$package not found. Installing..."
      exec_command apt install -y "$package"
    else
      echo "$package is already installed."
    fi
  done
}

# Install required PIP packages
install_pip_dependencies() {
  pip_dependencies=$(cat /home/tim/Desktop/HARDN/requirements.txt)

  for package in $pip_dependencies; do
    echo "Checking for pip package $package..."
    if ! pip show "$package" &>/dev/null; then
      echo "pip package $package not found. Installing..."
      exec_command pip install "$package"
    else
      echo "pip package $package is already installed."
    fi
  done
}

# Enforce password policies
enforce_password_policies() {
  exec_command apt install -y libpam-pwquality
  echo "password requisite pam_pwquality.so retry=3 minlen=12 difok=3" >> /etc/pam.d/common-password
}

# Configure the firewall
configure_firewall() {
  echo "Configuring Firewall..."
  exec_command ufw default deny incoming
  exec_command ufw default allow outgoing
  exec_command ufw allow out 80,443/tcp
  exec_command ufw allow 2375/tcp
  exec_command ufw --force enable
  exec_command ufw reload
}

# Install and configure Maldetect
install_maldetect() {
  echo "Installing Linux Malware Detect (Maldetect)..."
  echo "Downloading and installing Maldetect manually..."
  wget http://www.rfxn.com/downloads/maldetect-current.tar.gz
  tar -xvf maldetect-current.tar.gz
  cd maldetect-*
  sudo ./install.sh
  sudo maldet --update
  configure_maldetect
}

configure_maldetect() {
  echo "Configuring Maldetect..."
  wget http://www.rfxn.com/downloads/maldetect-current.tar.gz
  sudo tar -xvf maldetect-current.tar.gz
  cd maldetect-*
  sudo ./install.sh
  sudo maldet --update
  sed -i 's/^scan_clamscan=.*/scan_clamscan="1"/' /usr/local/maldetect/conf.maldet
  sed -i 's/^scan_sigs=.*/scan_sigs="1"/' /usr/local/maldetect/conf.maldet
  sed -i 's/^quarantine_hits=.*/quarantine_hits="1"/' /usr/local/maldetect/conf.maldet
  sed -i 's/^quarantine_clean=.*/quarantine_clean="1"/' /usr/local/maldetect/conf.maldet
  sed -i 's/^email_alert=.*/email_alert="1"/' /usr/local/maldetect/conf.maldet
  sed -i 's/^email_addr=.*/email_addr="root@localhost"/' /usr/local/maldetect/conf.maldet
}

clamvscan() {
  echo "Running ClamAV scan..."
  exec_command clamscan -r --bell /
}

run_rkhunter() {
  echo "Running RKHunter..."
  exec_command rkhunter --check
}

chkrootkit() {
  echo "Running chkrootkit..."
  exec_command chkrootkit -q
}

configure_debsums() {
  echo "Configuring debsums..."
  exec_command debsums -s
}

enable_aide() {
  echo "Installing and configuring AIDE..."
  exec_command apt install -y aide aide-common
  exec_command aideinit
  mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
  echo "0 0 * * * /usr/bin/aide --check >> /var/log/aide/aide.log 2>&1" > /etc/cron.d/aide
}
# SELinux on hold do to some compatibility errors.- Tim
#configure_selinux() {
  #echo "Configuring SELinux..."
  #exec_command apt install -y policycoreutils selinux-utils selinux-basics
  #exec_command selinux-config-enforcing
#}

configure_docker() {
  echo "Configuring Docker..."
  exec_command apt install -y docker.io
  exec_command systemctl enable --now docker
  exec_command usermod -aG docker "$USER"
}

configure_tcp_wrappers() {
  echo "Configuring TCP Wrappers..."
  echo "ALL: ALL" >> /etc/hosts.deny
  echo "sshd: ALL" >> /etc/hosts.allow
}

add_legal_banners() {
  echo "Adding legal banners..."
  echo "Authorized uses only. All activity is monitored." > /etc/issue
  echo "Authorized uses only. All activity is monitored." > /etc/issue.net
  echo "Authorized uses only. All activity is monitored." > /etc/motd
}

configure_password_hashing_rounds() {
    echo "Configuring password hashing rounds with higher security..."
    sed -i 's/^ENCRYPT_METHOD.*/ENCRYPT_METHOD SHA512/' /etc/login.defs
    sed -i 's/^SHA_CRYPT_MIN_ROUNDS.*/SHA_CRYPT_MIN_ROUNDS 50000/' /etc/login.defs
    sed -i 's/^SHA_CRYPT_MAX_ROUNDS.*/SHA_CRYPT_MAX_ROUNDS 50000/' /etc/login.defs
}

run_lynis() {
  echo "Running Lynis security audit..."
  exec_command apt install -y lynis
  exec_command lynis audit system
}

# sysctl settings
harden_sysctl() {
  echo "Hardening sysctl settings..."
  sysctl -w net.ipv4.conf.all.accept_redirects=0
  sysctl -w net.ipv4.conf.all.send_redirects=0
  sysctl -w net.ipv4.conf.default.accept_redirects=0
  sysctl -w net.ipv4.conf.default.send_redirects=0
  sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1
  sysctl -w net.ipv4.icmp_ignore_bogus_error_responses=1
  sysctl -w net.ipv4.tcp_syncookies=1
  sysctl -w net.ipv4.conf.all.rp_filter=1
  sysctl -w net.ipv4.conf.default.rp_filter=1
  sysctl -p
}

# Disable USB
disable_usb() {
  read -p "Do you want to disable exterior USB inputs? (y/n): " choice
  if [[ "$choice" == "y" ]]; then
    echo "Locking down USB devices..."
    echo 'blacklist usb-storage' >> /etc/modprobe.d/usb-storage.conf
    modprobe -r usb-storage
  else
    echo "USB lockdown skipped by user."
  fi
}

# errors
exec_command() {
  "$@" || { echo "Command failed: $*"; exit 1; }
}

# Main execution flow
install_apt_dependencies
install_pip_dependencies
enforce_password_policies
configure_firewall
install_maldetect
configure_maldetect
clamvscan
run_rkhunter
chkrootkit
configure_debsums
enable_aide
configure_selinux
configure_docker
configure_tcp_wrappers
add_legal_banners
configure_password_hashing_rounds
run_lynis  # last place

main "$@"