#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

########################################
#        HARDN - Auto Rice Script      #
#             main branch              #
#                                      #
#       Author: Chris Bingham          #
#       Enhancer:  Tim Burns           #
#           Date: 4/5/2025             #
#         Updated: 5/18/2025           #
#                                      #
########################################



auto_start() {
    echo "START..."
    sleep 1
   
}

    SCRIPT_PATH="$(readlink -f "$0")"
    SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
    SETUP_SCRIPT="$SCRIPT_DIR/hardn-setup.sh"
    chmod +x "$SETUP_SCRIPT"


repo="https://github.com/OpenSource-For-Freedom/HARDN/"
progsfile="$SCRIPT_DIR/../../progs.csv" 
repobranch="main"
name=$(whoami)


if [ "$(id -u)" -ne 0 ]; then
        echo ""
        echo "This script must be run as root."
        exit 1
fi

installpkg() {
       dpkg -s "$1" >/dev/null 2>&1
}


error() {
        printf "%s\n" "$1" >&2
        exit 1
}

welcomemsg() {
        whiptail --title "HARDN-XDR" --backtitle "SIG-OS Security" --fb \
            --msgbox "\n\n\n        Welcome to HARDN OS Security!\n\n        HARDN-XDR installs all needed Debian based Security tools for monitoring and response" 15 60

        whiptail --title "Welcome to Unix Security" --backtitle "HARDN-XDR" --fb \
            --yes-button "Confirm" \
            --no-button "Return..." \
            --yesno "\n\n\n        This installer will update your system first..\n\n" 12 70
}


preinstallmsg() {
        whiptail --title "Welcome to HARDN-XDR." --yes-button "Confirm" \
            --no-button "Return" \
            --yesno "\n\n\n        The rest of the install will quickly complete.\n\n        This will take time, so you will have a fully configured HARDN-XDR OS.\n\n        Press <HARDN> and the system will begin installation!\n\n" 13 60 || {
            clear
            exit 1
    }
}

update_system_packages() {
    {
        echo 10; sleep 0.5
        apt update >/dev/null 2>&1 && echo 40
        apt upgrade -y >/dev/null 2>&1 && echo 80
        apt autoremove -y >/dev/null 2>&1 && echo 90
        apt autoclean -y >/dev/null 2>&1 && echo 100
    } | whiptail --gauge "Updating system packages..." 6 50 0 || {
        whiptail --title "Error" --msgbox "Failed to update system packages." 10 60
        exit 1
    }
}

install_package_dependencies() {
    progsfile="$1"
    if [ ! -f "$progsfile" ]; then
        whiptail --msgbox "progs.csv not found: $progsfile" 10 60
        return 1
    fi

    total=$(grep -cv '^#' "$progsfile")
    n=0

    while IFS=, read -r tag pkg comment || [ -n "$tag" ]; do
        [ -z "$pkg" ] && continue
        n=$((n + 1))
        percent=$(( n * 100 / total ))
        whiptail --gauge "Installing dependency: $pkg ($n of $total)" 6 60 "$percent"
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            apt-get install -y "$pkg" >/dev/null 2>&1
        fi
    done < <(grep -v '^#' "$progsfile")
}

  aptinstall() {
          package="$1"
          comment="$2"
          whiptail --title "HARDN Installation" \
              --infobox "Installing \`$package\` ($n of $total) from the repository. $comment" 9 70
          echo "$aptinstalled" | grep -q "^$package$" && return 1
          apt-get install -y "$package" >/dev/null 2>&1
          aptinstalled="$aptinstalled\n$package"
  }

maininstall() {
       	whiptail --title "HARDN Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 9 70
       	installpkg "$1"
}

gitdpkgbuild() {
        repo_url="$1"
        description="$2"
        dir="/tmp/$(basename "$repo_url" .git)"

        whiptail --infobox "Cloning $repo_url... ($description)" 7 70
        git clone --depth=1 "$repo_url" "$dir" >/dev/null 2>&1
        cd "$dir" || exit
        whiptail --infobox "Building and installing $description..." 7 70

        whiptail --infobox "Checking build dependencies for $description..." 7 70
        build_deps=$(dpkg-checkbuilddeps 2>&1 | grep -oP 'Unmet build dependencies: \K.*')
        if [ -n "$build_deps" ];  then
          whiptail --infobox "Installing build dependencies: $build_deps" 7 70
          apt install -y $build_deps >/dev/null 2>&1
        fi

       dpkg-source --before-build . >/dev/null 2>&1
        if sudo dpkg-buildpackage -u -uc 2>&1; then
          sudo dpkg -i ../hardn.deb
        else
          whiptail --infobox "$description Failed to build package. Please check build dependencies." 10 60
          apt install -y debhelper-compat devscripts git-buildpackage
          sudo dpkg-buildpackage -us -uc 2>&1 && sudo dpkg -i  ../hardn.deb
        fi
}

build_hardn_package() {
    whiptail --infobox "Building HARDN Debian package..." 7 60

    temp_dir=$(mktemp -d)
    cd "$temp_dir" || exit 1

    git clone --depth=1 -b main-patch https://github.com/OpenSource-For-Freedom/HARDN.git
    cd HARDN || exit 1

    whiptail --infobox "Running dpkg-buildpackage..." 7 60
    dpkg-buildpackage -us -uc

    cd .. || exit 1
    whiptail --infobox "Installing HARDN package..." 7 60
    dpkg -i hardn_*.deb

    apt-get install -f -y

    cd / || exit 1
    rm -rf "$temp_dir"

    whiptail --infobox "HARDN package installed successfully" 7 60
}

putgitrepo() {
    printf "\033[1;32m[+] Downloading files from Git repo %s to %s...\033[0m\n" "$1" "$2"
    local repo_url="$1"
    local target_dir="$2"
    local branch_override="$3"
    local branch_to_use
    local temp_dir
    local return_status=1 

    if [ -n "$branch_override" ]; then
        branch_to_use="$branch_override"
    elif [ -n "$repobranch" ]; then
        branch_to_use="$repobranch"
    else
        branch_to_use="master"
    fi

    temp_dir=$(mktemp -d)
    if [ -z "$temp_dir" ] || [ ! -d "$temp_dir" ]; then
        whiptail --msgbox "Failed to create temporary directory." 10 70
        return 1
    fi

    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
        if [ $? -ne 0 ]; then
            whiptail --msgbox "Failed to create target directory: $target_dir" 10 70
            rm -rf "$temp_dir"
            return 1
        fi
    fi

   
    if ! chown "$name:$(id -gn "$name")" "$temp_dir"; then
        whiptail --msgbox "Warning: Failed to chown temp directory $temp_dir to $name. Git operations might fail." 10 70
    fi
    

    echo "Cloning $repo_url (branch: $branch_to_use) into $temp_dir..."
    if sudo -u "$name" git clone --depth 1 --single-branch --no-tags -q \
        --recursive -b "$branch_to_use" --recurse-submodules "$repo_url" "$temp_dir"; then
        
        echo "Copying files from $temp_dir to $target_dir..."

        if sudo -u "$name" cp -rfT "$temp_dir/." "$target_dir/"; then
            printf "Files from %s installed to %s successfully.\n" "$repo_url" "$target_dir"
            return_status=0 
        else
            whiptail --msgbox "Failed to copy files from cloned repo $repo_url to $target_dir." 10 70
        fi
    else
        whiptail --msgbox "Failed to clone repository: $repo_url (branch: $branch_to_use). Check URL, branch, and permissions." 10 70
    fi
    
    rm -rf "$temp_dir"
    return $return_status
}


installationloop() {
    local progs_csv_path="/tmp/progs.csv"
   
    if [ -z "$progsfile" ]; then
        error "FATAL: progsfile variable is not set. Cannot fetch package list."
       
    fi

   
    printf "Fetching package list from %s to %s...\n" "$progsfile" "$progs_csv_path"
    if [ -f "$progsfile" ]; then 
        if ! cp "$progsfile" "$progs_csv_path"; then
             error "FATAL: Failed to copy local progsfile $progsfile to $progs_csv_path."
        fi
    else # Assume $progsfile is a URL
        # sed '/^#/d' removes comment lines
        if ! curl -Ls "$progsfile" | sed '/^#/d' > "$progs_csv_path"; then
            error "FATAL: Failed to download package list from $progsfile."
        fi
    fi

    if [ ! -s "$progs_csv_path" ]; then # Check if file is empty or not created
        error "FATAL: Package list $progs_csv_path is empty or could not be fetched."
    fi

    total=$(wc -l < "$progs_csv_path")
    echo "[INFO] Found $total entries to process from $progs_csv_path."
    aptinstalled=$(apt-mark showmanual)
    n=0

    while IFS=, read -r tag program comment || [ -n "$tag" ]; do

        [ -z "$tag" ] && [ -z "$program" ] && continue

        n=$((n + 1))
        
     
        tag=$(echo "$tag" | awk '{$1=$1};1')
        program=$(echo "$program" | awk '{$1=$1};1')
        comment=$(echo "$comment" | awk '{$1=$1};1')

   
        [ -z "$program" ] && echo "INFO: Skipping entry $n, program field is empty. Tag: '$tag'." && continue

        echo "➤ Processing ($n of $total): Program='$program', Tag='$tag', Comment='$comment'"

      
        if echo "$comment" | grep -q "^\".*\"$"; then
            comment="$(echo "$comment" | sed -E 's/(^"|"$)//g')"
        fi

        case "$tag" in
            a) aptinstall "$program" "$comment" ;;
            G) gitdpkgbuild "$program" "$comment" ;;
            # Add other tags here as needed, e.g.:
            # R) putgitrepo "$program" "$comment" ;; # If 'R' is for general repo download
            *)
                echo "INFO: Unknown tag '$tag' for program '$program'. Skipping."
                ;;
        esac
    done < "$progs_csv_path"
    
    # Optional: Clean up the temporary CSV file
    # rm -f "$progs_csv_path" 
    # Keeping it for now might be useful for debugging if issues occur.
    echo "[INFO] Finished processing $n entries from package list."
}


check_security_tools() {
    printf "\\033[1;31m[+] Checking for security packages are installed...\\033[0m\\n"
                for pkg in ufw yara fail2ban aide apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums rkhunter libpam-pwquality libvirt-daemon-system libvirt-clients qemu-kvm docker.io docker-compose openssh-server suricata psad debsecan needrestart tripwire logwatch; do
                        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
                                whiptail --infobox "Installing $pkg..." 7 60
                                apt install -y "$pkg"
                        else
                                whiptail --infobox "$pkg is already installed." 7 60
                        fi
                done

                if ! dpkg -s "yara" >/dev/null 2>&1; then
                    whiptail --infobox "Installing yara..." 7 60
                    apt install -y "yara"
                fi
}



update_sys_pkgs() {
     whiptail --infobox "Updating system packages..." 7 50
         
            apt update && apt upgrade -y
            apt autoremove -y
            apt autoclean -y
        if ! update_system_packages; then
             printf "\033[1;31m[-] System update failed.\033[0m\n"
            whiptail --title "System update failed"
            exit 1
        fi
}


finalize() {
        whiptail --title "Complete!" \
            --msgbox "HARDN-XDR Install Complete." 12 80
}

hardn_setup() {
    if [ -x "$SETUP_SCRIPT" ]; then
        bash "$SETUP_SCRIPT" -s
        whiptail --title "HARDN-XDR Setup" \
            --msgbox "HARDN-XDR\n\nSystem is Validating Configurations and Setup." 12 80
    else
        whiptail --title "Error" --msgbox "Setup script not found or not executable: $SETUP_SCRIPT" 10 60
    fi
}



main() {
    welcomemsg || error "User exited."
    preinstallmsg || error "User exited."

    whiptail --title "Cron Jobs and Alerting Setup" --yesno \
        "\n\n\n        Do you want to proceed with setting up cron jobs and alerting?\n\n        This includes tools like AIDE, Fail2Ban, and others." 12 70 || {
        printf "\033[1;31m[-] User declined cron jobs and alerting setup. Exiting...\033[0m\n"
        exit 1
    }

    update_system_packages
 
    local progs_csv_path="/tmp/progs.csv"
    printf "Fetching package list from %s to %s...\n" "$progsfile" "$progs_csv_path"
    if ! cp "$progsfile" "$progs_csv_path"; then
        error "FATAL: Failed to copy package list from $progsfile."
    fi

    if [ ! -s "$progs_csv_path" ]; then
        error "FATAL: Package list $progs_csv_path is empty or could not be fetched."
    fi
    installationloop
    check_security_tools
    finalize
    hardn_setup
}


auto_start


mkdir -p /etc/hardn
touch /etc/hardn/.first_run_complete


main