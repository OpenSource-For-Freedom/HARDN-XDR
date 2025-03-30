#!/usr/bin/env bash

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
echo "##############################################################"

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

echo "-------------------------------------------------------"
echo "                   HARDN - SETUP                       "
echo "-------------------------------------------------------"

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use: sudo ./Setup.sh"
   exit 1
fi

# Update system packages
update_system_packages() {
    printf "\e[1;31m[+] Updating system packages...\e[0m\n"
    sudo apt update && sudo apt upgrade -y
}

# Running venv prior 
setup_python_venv() {
    printf "\e[1;31m[+] Setting up Python virtual environment...\e[0m\n"

    # Ensure Python3 and venv are installed
    sudo apt install -y python3 python3-venv python3-pip

    # Create the venv
    if [ ! -d "../.venv" ]; then
        python3 -m venv ../.venv
        printf "\e[1;32m[+] Virtual environment created.\e[0m\n"
    else
        printf "\e[1;33m[+] Virtual environment already exists.\e[0m\n"
    fi

    # Activate the venv and pip
    source ../.venv/bin/activate
    pip install --upgrade pip
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
        printf "\e[1;32m[+] Python packages installed from requirements.txt.\e[0m\n"
    else
        printf "\e[1;33m[+] No requirements.txt found. Skipping Python package installation.\e[0m\n"
    fi
    deactivate
}

# Check dependencies
pkgdeps=(
    gawk
    mariadb-common
    mysql-common
    policycoreutils
    python-matplotlib-data
    unixodbc-common
    gawk-doc
)

check_pkgdeps() {
    for pkg in "${pkgdeps[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            echo "Installing missing package: $pkg"
            sudo apt install -y "$pkg"
        else
            echo "Package $pkg is already installed."
        fi
    done
}

# Offer to resolve unmet dependencies
offer_to_resolve_issues() {
    local deps_to_resolve="$1"
    echo "Dependencies to resolve:"
    echo "$deps_to_resolve"
    echo
    read -p "Do you want to resolve these dependencies? (y/n): " answer
    if [[ $answer =~ ^[Yy]$ ]]; then
        echo "$deps_to_resolve" | sed -E 's/<[^>]*>//g' | tr -s ' ' > dependencies_to_resolve.txt
        echo "List of dependencies to resolve saved in dependencies_to_resolve.txt"
        echo "Attempting to resolve dependencies..."
        sudo apt install -f -y
    elif [[ $answer =~ ^[Nn]$ ]]; then
        echo "No action taken."
    else
        echo "Invalid input. Please enter 'y' or 'n'."
    fi
}

# SELinux
install_selinux() {
    printf "\e[1;31m[+] Installing and configuring SELinux...\e[0m\n"
    sudo apt install -y selinux-utils selinux-basics policycoreutils policycoreutils-python-utils selinux-policy-default
    if command -v getenforce &> /dev/null; then
        if [[ "$(getenforce)" != "Enforcing" ]]; then
            setenforce 1 || printf "\e[1;31m[-] Could not set SELinux to enforcing mode immediately\e[0m\n"
        fi
        sed -i 's/SELINUX=disabled/SELINUX=enforcing/' /etc/selinux/config
        sed -i 's/SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config
    else
        printf "\e[1;31m[-] SELinux is not supported on this system.\e[0m\n"
    fi
}

# Main function
main() {
    update_system_packages
    # setup_python_venv
    check_pkgdeps
    install_selinux
    echo "======================================================="
    echo "             [+] HARDN - Setup Complete                "
    echo "  [+] Please reboot your system to apply changes       "
    echo "======================================================="
}

# Run the main function
main 