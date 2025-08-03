#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

HARDN_STATUS "info" "Securing shared memory..."
if ! grep -q "tmpfs /run/shm" /etc/fstab; then
	echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab
	HARDN_STATUS "pass" "Shared memory security configured in /etc/fstab"
else
	HARDN_STATUS "info" "Shared memory security already configured"
fi

HARDN_STATUS "pass" "Shared memory hardening completed"

return 0 2>/dev/null || hardn_module_exit 0

