#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

HARDN_STATUS "info" "Disabling core dumps..."
if ! grep -q "^\* hard core 0" /etc/security/limits.conf 2>/dev/null; then
	echo "* hard core 0" >> /etc/security/limits.conf
fi
if ! grep -q "^fs.suid_dumpable = 0" /etc/sysctl.conf 2>/dev/null; then
	echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf
fi
if ! grep -q "^kernel.core_pattern = /dev/null" /etc/sysctl.conf 2>/dev/null; then
	echo "kernel.core_pattern = /dev/null" >> /etc/sysctl.conf
fi
if sysctl -p >/dev/null 2>&1; then
    HARDN_STATUS "pass" "Core dumps disabled successfully."
    HARDN_STATUS "info" "Settings applied: limits=0, suid_dumpable=0, core_pattern=/dev/null"
else
    HARDN_STATUS "warning" "Core dump settings configured, but sysctl reload failed. Reboot may be required."
fi

return 0 2>/dev/null || hardn_module_exit 0
