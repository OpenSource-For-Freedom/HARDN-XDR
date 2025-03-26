#!/bin/bash

echo "##############################################################"
echo "#       ██░ ██  ▄▄▄       ██▀███  ▓█████▄  ███▄    █         #"
echo "#      ▓██░ ██▒▒████▄    ▓██ ▒ ██▒▒██▀ ██▌ ██ ▀█   █         #"
echo "#      ▒██▀▀██░▒██  ▀█▄  ▓██ ░▄█ ▒░██   █▌▓██  ▀█ ██▒        #"
echo "#      ░▓█ ░██ ░██▄▄▄▄██ ▒██▀▀█▄  ░▓█▄   ▌▓██▒  ▐▌██▒        #"
echo "#      ░▓█▒░██▓ ▓█   ▓██▒░██▓ ▒██▒░▒████▓ ▒██░   ▓██░        #"
echo "#       ▒ ░░▒░▒ ▒▒   ▓▒█░░ ▒▓ ░▒▓░ ▒▒▓  ▒ ░ ▒░   ▒ ▒         #"
echo "#       ▒ ░▒░ ░  ▒   ▒▒ ░  ░▒ ░ ▒░ ░ ▒  ▒ ░ ░░   ░ ▒░        #"
echo "#       ░  ░░ ░  ░   ▒     ░░   ░  ░ ░  ░    ░   ░ ░         #"
echo "#       ░  ░  ░      ░  ░   ░        ░             ░         #"  
echo "#                           ░                                #"
echo "#               THE LINUX SECURITY PROJECT                   #"
echo "#                                                            #"
echo "#                                                            #"      
echo "##############################################################"

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin


echo "-------------------------------------------------------"
echo "                   HARDN - SETUP                       "
echo "-------------------------------------------------------"

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use: sudo ./setup.sh"
   exit 1
fi



cd "$(dirname "$0")"

echo "[+] Updating system packages..."
apt update && apt upgrade -y
sudo apt install -y build-essential python3-dev python3-setuptools python3-wheel cython3

echo "[+] Installing required system dependencies..."
apt install -y python3 python3-venv python3-pip ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums build-essential python3-dev python3-setuptools python3-wheel libpam-pwquality docker.io


echo "-------------------------------------------------------"
echo "                 BUILD PYTHON EVE                      "
echo "-------------------------------------------------------"



echo "[+] Setting up Python virtual environment..."
rm -rf setup/venv
python3 -m venv setup/venv
source setup/venv/bin/activate
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt




####################################################################### build

echo "[+] Installing HARDN as a system-wide command..."
pip install -e .
#!/bin/bash
files=("hardn_dark.py" "gui.py" "kernal.py")

for file in "${files[@]}"; do

    filepath=$(find / -name "$file" 2>/dev/null | head -n 1)
    
    if [ -n "$filepath" ]; then
        chmod +x "$filepath"
        echo "Executable permission added to $filepath"
    else
        echo "Warning: $file not found. Skipping chmod."
    fi
done

echo "-------------------------------------------------------"
echo "                     SECURITY                          "
echo "-------------------------------------------------------"


ufw default deny incoming
ufw default allow outgoing
ufw --force enable


echo "-------------------------------------------------------"
echo "                      THE PURGE                        "
echo "-------------------------------------------------------"

echo "[+] Checking for unnecessary packages to remove..."
if sudo apt autoremove --dry-run | grep -q "The following packages will be REMOVED"; then
    echo "[!] The following packages will be removed:"
    sudo apt autoremove --dry-run | grep "The following packages will be REMOVED" -A 10
    echo "[+] Proceeding with autoremove..."
    sudo apt autoremove -y
else
    echo "[+] No unnecessary packages to remove."
fi

echo "[+] Cleaning up package cache..."
sudo apt autoclean -y
sudo apt clean -y


echo "[+] Ensuring debsums is installed..."
if ! dpkg -l | grep -q debsums; then
	apt install -y debsums
fi

echo "[+] Running Debsums..."
debsums -a -s -c 2>&1 | tee /var/log/debsums.log

echo "-------------------------------------------------------"
echo "                          CRON                         "
echo "-------------------------------------------------------"

echo "[+] Checking for cron jobs..."
if [ -f /etc/cron.deny ]; then
    echo "[!] Removing /etc/cron.deny..."
    rm /etc/cron.deny
fi

(crontab -l 2>/dev/null; echo "* * * * * /path/to/Setup.sh >> /var/log/setup.log 2>&1") | crontab -



# build cron for updates and security checks
echo "[+] Creating cron jobs..."
echo "0 0 * * * root apt update && apt upgrade -y" > /etc/cron.d/hardn
echo "0 0 * * * root lynis audit system" >> /etc/cron.d/hardn
echo "0 0 * * * root debsums -s" >> /etc/cron.d/hardn
echo "0 0 * * * root rkhunter --check" >> /etc/cron.d/hardn
echo "0 0 * * * root clamscan -r /" >> /etc/cron.d/hardn
echo "0 0 * * * root maldet -a /" >> /etc/cron.d/hardn
echo "0 0 * * * root chkrootkit" >> /etc/cron.d/hardn
echo "0 0 * * * root firejail --list" >> /etc/cron.d/hardn
echo "0 0 * * * root harden" >> /etc/cron.d/hardn

# Ensure cron jobs are set to run daily
echo "[+] Setting cron jobs to run daily..."
chmod 644 /etc/cron.d/hardn


# print report of security findings on desktop
echo "[+] Creating daily security report..."
echo "lynis audit system" > /etc/cron.daily/hardn
echo "debsums -s" >> /etc/cron.daily/hardn
echo "rkhunter --check" >> /etc/cron.daily/hardn
echo "clamscan -r /" >> /etc/cron.daily/hardn
echo "maldet -a /" >> /etc/cron.daily/hardn
echo "chkrootkit" >> /etc/cron.daily/hardn
echo "firejail --list" >> /etc/cron.daily/hardn
echo "harden" >> /etc/cron.daily/hardn

# make sure report is password protected by root user
echo "[+] Setting permissions on daily security report..."
chmod 700 /etc/cron.daily/hardn


echo "-------------------------------------------------------"
echo "[+]               HARDN SETUP COMPLETE"
echo "-------------------------------------------------------"