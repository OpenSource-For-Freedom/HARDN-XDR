#!/bin/bash

is_installed() {
    if command -v apt >/dev/null 2>&1; then
        dpkg -s "$1" >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        dnf list installed "$1" >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum list installed "$1" >/dev/null 2>&1
    elif command -v rpm >/dev/null 2>&1; then
        rpm -q "$1" >/dev/null 2>&1
    else
        return 1 # Cannot determine package manager
    fi
}

HARDN_STATUS "info" "Setting up YARA..."

if ! is_installed yara; then
    HARDN_STATUS "info" "YARA not found. Installing..."
    if apt-get install -y yara >/dev/null 2>&1; then
        HARDN_STATUS "pass" "YARA installed successfully."
    else
        HARDN_STATUS "error" "Failed to install YARA. Skipping rule setup."
        return 1
    fi
fi

HARDN_STATUS "info" "Setting up YARA rules..."

# Check if YARA command exists (implies installation)
if ! command -v yara >/dev/null 2>&1; then
    HARDN_STATUS "warning" "Warning: YARA command not found. Skipping rule setup."
else
    HARDN_STATUS "pass" "YARA command found."
    HARDN_STATUS "info" "Creating YARA rules directory..."
    mkdir -p /etc/yara/rules
    chmod 755 /etc/yara/rules

    HARDN_STATUS "info" "Checking for git..."
    if ! command -v git >/dev/null 2>&1; then
        HARDN_STATUS "info" "git not found. Attempting to install..."
        if apt-get update >/dev/null 2>&1 && apt-get install -y git >/dev/null 2>&1; then
            HARDN_STATUS "pass" "git installed successfully."
        else
            HARDN_STATUS "error" "Error: Failed to install git. Cannot download YARA rules."
            return 1
        fi
    else
        HARDN_STATUS "pass" "git command found."
    fi

    local rules_repo_url="https://github.com/Yara-Rules/rules.git"
    local temp_dir
    temp_dir=$(mktemp -d -t yara-rules-XXXXXXXX)

    if [[ ! -d "$temp_dir" ]]; then
        HARDN_STATUS "error" "Error: Failed to create temporary directory for YARA rules."
        return 1
    fi

    HARDN_STATUS "info" "Cloning YARA rules from $rules_repo_url to $temp_dir..."
    if git clone --depth 1 "$rules_repo_url" "$temp_dir" >/dev/null 2>&1; then
        HARDN_STATUS "pass" "YARA rules cloned successfully."

        HARDN_STATUS "info" "Copying .yar rules to /etc/yara/rules/..."
        local copied_count=0
        local find_output
        find_output=$(find -L "$temp_dir" -name "*.yar" -print0)

        if [ -z "$find_output" ]; then
            HARDN_STATUS "warning" "Warning: No .yar files found in the repository."
        else
            while IFS= read -r -d $'\0' yar_file; do
                if cp "$yar_file" /etc/yara/rules/; then
                    ((copied_count++))
                else
                    HARDN_STATUS "warning" "Warning: Failed to copy rule file: $yar_file"
                fi
            done <<< "$find_output"
        fi

        if [[ "$copied_count" -gt 0 ]]; then
            HARDN_STATUS "pass" "Copied $copied_count YARA rule files to /etc/yara/rules/."
        else
            HARDN_STATUS "warning" "Warning: No .yar files found or copied from the repository."
        fi

    else
        HARDN_STATUS "error" "Error: Failed to clone YARA rules repository."
    fi

    HARDN_STATUS "info" "Cleaning up temporary directory $temp_dir..."
    rm -rf "$temp_dir"
    HARDN_STATUS "pass" "Cleanup complete."

    # --- Integration Instructions ---

    # AIDE: Run YARA after AIDE check (example wrapper)
    cat <<'EOF' > /usr/local/bin/aide-with-yara.sh
#!/bin/bash
aide --check
find / -type f -print0 | xargs -0 -P4 yara -r /etc/yara/rules/*.yar
EOF
    chmod +x /usr/local/bin/aide-with-yara.sh
    HARDN_STATUS "info" "Created /usr/local/bin/aide-with-yara.sh to run YARA after AIDE."

    # Suricata: YARA support requires Suricata >= 6.0 and must be enabled at build time.
    # Place rules in /etc/yara/rules/ and add to suricata.yaml:
    if [ -f /etc/suricata/suricata.yaml ]; then
        if ! grep -q 'yara-' /etc/suricata/suricata.yaml; then
            echo -e "\n# YARA integration\n" >> /etc/suricata/suricata.yaml
            echo "yara-signatures-dir: /etc/yara/rules/" >> /etc/suricata/suricata.yaml
            HARDN_STATUS "info" "Added YARA rules directory to Suricata config."
        fi
    fi

    # RKHunter: No native YARA support. Create a wrapper to run YARA after RKHunter.
    cat <<'EOF' > /usr/local/bin/rkhunter-with-yara.sh
#!/bin/bash
rkhunter --check "$@"
find / -type f -print0 | xargs -0 -P4 yara -r /etc/yara/rules/*.yar
EOF
    chmod +x /usr/local/bin/rkhunter-with-yara.sh
    HARDN_STATUS "info" "Created /usr/local/bin/rkhunter-with-yara.sh to run YARA after RKHunter."

    # Auditd: No direct YARA integration. Suggest using audit rules to monitor files, then scan with YARA.
    cat <<'EOF' > /usr/local/bin/auditd-yara-scan.sh
#!/bin/bash
# Example: scan files modified in the last day
find / -type f -mtime -1 -print0 | xargs -0 -P4 yara -r /etc/yara/rules/*.yar
EOF
    chmod +x /usr/local/bin/auditd-yara-scan.sh
    HARDN_STATUS "info" "Created /usr/local/bin/auditd-yara-scan.sh for periodic YARA scans on recent changes."

    HARDN_STATUS "pass" "YARA rules setup and integration scripts completed."
fi
