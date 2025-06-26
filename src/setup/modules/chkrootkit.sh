# chkrootkit


install_chkrootkit_from_source() {

        # Trying the FTP, cause the https source is not available
        local download_url="ftp://ftp.chkrootkit.org/pub/seg/pac/chkrootkit.tar.gz"

        ##local download_url="https://www.chkrootkit.org/dl/chkrootkit.tar.gz"
        local download_dir="/tmp/chkrootkit_install"
        local tar_file="$download_dir/chkrootkit.tar.gz"

        mkdir -p "$download_dir"
        cd "$download_dir" || {
            HARDN_STATUS "error" "Error: Cannot change directory to $download_dir."
            return 1
        }

        HARDN_STATUS "info" "Downloading $download_url..."
        if ! wget -q "$download_url" -O "$tar_file"; then
            HARDN_STATUS "error" "Error: Failed to download $download_url."
            cleanup_install_files
            return 1
        fi
        HARDN_STATUS "pass" "Download successful."

        HARDN_STATUS "info" "Extracting..."
        if ! tar -xzf "$tar_file" -C "$download_dir"; then
            HARDN_STATUS "error" "Error: Failed to extract $tar_file."
            cleanup_install_files
            return 1
        fi
        HARDN_STATUS "pass" "Extraction successful."

        local extracted_dir
        extracted_dir=$(tar -tf "$tar_file" | head -1 | cut -f1 -d/)

        if ! [[ -d "$download_dir/$extracted_dir" ]]; then
            HARDN_STATUS "error" "Error: Extracted directory not found."
            cleanup_install_files
            return 1
        fi

        cd "$download_dir/$extracted_dir" || {
            HARDN_STATUS "error" "Error: Cannot change directory to extracted folder."
            cleanup_install_files
            return 1
        }

        HARDN_STATUS "info" "Running chkrootkit installer..."
        if ! [[ -f "chkrootkit" ]]; then
            HARDN_STATUS "error" "Error: chkrootkit script not found in extracted directory."
            cleanup_install_files
            return 1
        fi

        cp chkrootkit /usr/local/sbin/
        chmod +x /usr/local/sbin/chkrootkit

        if [[ -f "chkrootkit.8" ]]; then
            cp chkrootkit.8 /usr/local/share/man/man8/
            mandb >/dev/null 2>&1 || true
        fi

        HARDN_STATUS "pass" "chkrootkit installed to /usr/local/sbin."
        cleanup_install_files
        return 0
}


cleanup_install_files() {
        cd /tmp || true
        rm -rf "/tmp/chkrootkit_install"
}


configure_chkrootkit_cron() {
        if ! command -v chkrootkit >/dev/null 2>&1; then
            HARDN_STATUS "error" "chkrootkit command not found, skipping cron configuration."
            return 1
        fi

        if ! grep -q "/usr/local/sbin/chkrootkit" /etc/crontab; then
            echo "0 3 * * * root /usr/local/sbin/chkrootkit 2>&1 | logger -t chkrootkit" >> /etc/crontab
            HARDN_STATUS "pass" "chkrootkit daily check added to crontab."
        else
            HARDN_STATUS "info" "chkrootkit already in crontab."
        fi

        return 0
}

# Main function
setup_chkrootkit() {
        HARDN_STATUS "info" "Configuring chkrootkit..."

        if ! command -v chkrootkit >/dev/null 2>&1; then
            HARDN_STATUS "info" "chkrootkit package not found. Attempting to download and install from chkrootkit.org..."
            install_chkrootkit_from_source
        else
            HARDN_STATUS "pass" "chkrootkit package is already installed."
        fi

        configure_chkrootkit_cron
}

# Calling main
setup_chkrootkit


