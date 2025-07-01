#!/bin/bash
HARDN_STATUS "info" "Securing shared memory..."
if ! grep -q "tmpfs /run/shm" /etc/fstab; then
	echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab
fi
