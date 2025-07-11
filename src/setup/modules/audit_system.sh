#!/bin/bash

# HARDN-XDR System Audit and Hardening Module
# This script is sourced by hardn-main.sh

# Check if package is installed
hardn_audit_is_installed() {
        command -v "$1" &>/dev/null
}

# Install missing package if not present
hardn_audit_install_package() {
        local pkg="$1"
        if ! dpkg -s "$pkg" &>/dev/null; then
            HARDN_STATUS "info" "Package '$pkg' not found. Installing..."
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
        else
            HARDN_STATUS "info" "Package '$pkg' is already installed."
        fi
}

# Install required security packages
hardn_audit_install_security_packages() {
        HARDN_STATUS "info" "Installing security packages..."
        apt-get update

        local packages=("libpam-tmpdir" "apt-listbugs" "needrestart")
        for pkg in "${packages[@]}"; do
            hardn_audit_install_package "$pkg"
        done
}

# Remove compilers and development tools
hardn_audit_remove_compilers() {
        HARDN_STATUS "info" "Removing compilers and unnecessary binaries..."

        local compilers=(
            gcc g++ make cpp clang clang++ nasm perl python2 python2.7
        )

        # Process removals in parallel (up to 4 at a time)
        for bin in "${compilers[@]}"; do
            if command -v "$bin" &>/dev/null; then
                HARDN_STATUS "info" "Removing $bin..."
                apt-get remove --purge -y "$bin" &
                # Limit to 4 parallel processes
                [[ $(jobs -r | wc -l) -ge 4 ]] && wait
            fi
        done

        # Wait for all background jobs to complete
        wait

        # Remove development meta-packages
        apt-get remove --purge -y build-essential gcc-* g++-* clang-* || true

        # Clean up
        apt-get autoremove -y
        apt-get autoclean -y
}

hardn_audit_check_crypto() {
        HARDN_STATUS "info" "Checking cryptography and entropy sources..."

        # EXPORT FOR PARALLEL PROCESSES
        export -f HARDN_STATUS 2>/dev/null || true

        # Check for expired SSL certificates in parallel (safe quoting)
        find /etc/ssl /etc/letsencrypt -type f \( -name "*.crt" -o -name "*.pem" \) -print0 2>/dev/null |
        xargs -0 -r -P4 -I{} bash -c "
            if openssl x509 -checkend 0 -noout -in \"\$1\" 2>/dev/null | grep -q expired; then
                HARDN_STATUS \"warn\" \"Expired SSL certificate: \$1\"
            fi
        " _ {}

        # PARALLEL CHECK FOR ACTIVE PRNGS
        systemctl is-active --quiet haveged &  haveged_pid=$!
        systemctl is-active --quiet jitterentropy-rngd &  jitter_pid=$!

        wait $haveged_pid; haveged_status=$?
        wait $jitter_pid; jitter_status=$?

        if [[ $haveged_status -eq 0 || $jitter_status -eq 0 ]]; then
            HARDN_STATUS "pass" "Software PRNG (haveged or jitterentropy-rngd) is active"
        else
            arch=$(uname -m)
            case "$arch" in
                "x86_64"|"i686"|"i386")
                    : "haveged"  # Optimal for x86 architectures
                    ;;
                "aarch64"|"arm"*)
                    : "jitterentropy-rngd"  # Optimal for ARM architectures
                    ;;
                *)
                    : "haveged"  # Default
                    ;;
            esac

            recommended_prng="$_"
            HARDN_STATUS "warn" "No software PRNG is running. Consider installing $recommended_prng"

            # Optionally, offer to install the recommended PRNG
            # Uncomment the following line to install the recommended PRNG
            # hardn_audit_install_package "$recommended_prng"
        fi
}

hardn_audit_secure_permissions() {
        HARDN_STATUS "info" "Setting secure file permissions..."

        # Secure /tmp and /var/tmp
        chmod 1777 /tmp /var/tmp 2>/dev/null || true

        # Secure log files (run in parallel)
        {
            find /var/log -type f -exec chmod 640 {} \; 2>/dev/null || true
        } &
        {
            find /var/log -type d -exec chmod 750 {} \; 2>/dev/null || true
        } &
        wait

        # Secure system files
        chmod 644 /etc/passwd 2>/dev/null || true
        chmod 640 /etc/shadow 2>/dev/null || true
        chmod 644 /etc/group 2>/dev/null || true
        chmod 640 /etc/gshadow 2>/dev/null || true

        # Remove world-writable permissions from config files
        find /etc -type f -name "*.conf" -perm -002 -print0 |
            xargs -0 -r -P4 chmod o-w 2>/dev/null || true

        # Secure cron directories
        find /etc/cron.d -type f -exec chmod 644 {} \; 2>/dev/null || true
        chmod 755 /etc/cron.{daily,hourly,monthly,weekly} 2>/dev/null || true
        chmod -R 755 /etc/cron.{daily,hourly,monthly,weekly} 2>/dev/null || true

        # Secure sudoers directory
        chmod 750 /etc/sudoers.d 2>/dev/null || true

        # Mail queue permissions
        if hardn_audit_is_installed postfix; then
            chmod 700 /var/spool/postfix/maildrop 2>/dev/null || true
        fi
}

hardn_audit_configure_pam() {
        HARDN_STATUS "info" "Enhancing PAM and security limits..."

        local pam_login="/etc/pam.d/login"
        if [[ -f "$pam_login" ]] && ! grep -q "pam_limits.so" "$pam_login"; then
            printf "session required pam_limits.so\n" >> "$pam_login"
        fi

        if ! grep -q '\* hard core 0' /etc/security/limits.conf 2>/dev/null; then
            printf "* hard core 0\n" >> /etc/security/limits.conf
        fi

        # Set umask
        if ! grep -q "umask 027" /etc/profile; then
            printf "umask 027\n" >> /etc/profile
        fi
}

# Harden systemd services
hardn_audit_harden_systemd() {
    HARDN_STATUS "info" "Hardening systemd service file permissions..."

    # Secure systemd files
    find /etc/systemd/system -type f -exec chmod 644 {} \; 2>/dev/null || true
    find /etc/systemd/system -type d -exec chmod 755 {} \; 2>/dev/null || true

    # Services to harden
    local hardened_services=(
        "cron.service" "ssh.service" "rsyslog.service" "dbus.service"
        "cups.service" "avahi-daemon.service" "systemd-udevd.service"
        "getty@.service" "user@.service" "wpa_supplicant.service"
    )

    # Create hardening configs in parallel
    for svc in "${hardened_services[@]}"; do
        {
            local unit_dir="/etc/systemd/system/${svc}.d"
            mkdir -p "$unit_dir"
            cat > "$unit_dir/10-hardening.conf" <<EOF
[Service]
ProtectSystem=full
ProtectHome=yes
PrivateTmp=yes
NoNewPrivileges=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
EOF
        } &
        # Limit to 4 PARALLEL PROCESSES
        [[ $(jobs -r | wc -l) -ge 4 ]] && wait
    done

    # Wait for all background jobs to complete
    wait

    # Reload systemd
    systemctl daemon-reload

    HARDN_STATUS "info" "For further systemd hardening, review 'systemd-analyze security' output."
}

hardn_audit_system_setup() {
        HARDN_STATUS "info" "Applying general system hardening settings..."

        hardn_audit_install_security_packages
        hardn_audit_remove_compilers
        hardn_audit_check_crypto
        hardn_audit_secure_permissions
        hardn_audit_configure_pam
        hardn_audit_harden_systemd

        HARDN_STATUS "pass" "General system hardening settings applied."
}
