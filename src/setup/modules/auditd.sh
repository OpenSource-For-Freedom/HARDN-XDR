#!/bin/bash
set -e

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

if ! is_installed auditd; then
    HARDN_STATUS "info" "Installing auditd..."
    if command -v apt >/dev/null 2>&1; then
        apt install -y auditd >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y auditd >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum install -y auditd >/dev/null 2>&1
    fi
fi

systemctl daemon-reload
systemctl enable auditd
systemctl restart auditd

HARDN_STATUS "info" "Configuring auditd rules for system security..."

audit_rules_file="/etc/audit/rules.d/hardn-xdr.rules"

# rule credits to bfuzzy!
wget https://raw.githubusercontent.com/bfuzzy/auditd-attack/refs/heads/master/auditd-attack.rules -O $audit_rules_file

# Secure the audit rules file permissions
chmod 600 "$audit_rules_file"
chown root:root "$audit_rules_file"

# Reload auditd rules
augenrules --load 2>/dev/null || service auditd restart
