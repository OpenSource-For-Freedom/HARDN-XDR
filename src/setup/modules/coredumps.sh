#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

HARDN_STATUS "info" "Disabling core dumps..."
if ! grep -q "hard core" /etc/security/limits.conf; then
	echo "* hard core 0" >> /etc/security/limits.conf
fi
if ! grep -q "fs.suid_dumpable" /etc/sysctl.conf; then
	echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf
fi
if ! grep -q "kernel.core_pattern" /etc/sysctl.conf; then
	echo "kernel.core_pattern = /dev/null" >> /etc/sysctl.conf
fi
sysctl -p >/dev/null 2>&1
HARDN_STATUS "pass" "Core dumps disabled: Limits set to 0, suid_dumpable set to 0, core_pattern set to /dev/null."
HARDN_STATUS "info" "Kernel security settings applied successfully."
HARDN_STATUS "info" "Starting kernel security hardening..."
