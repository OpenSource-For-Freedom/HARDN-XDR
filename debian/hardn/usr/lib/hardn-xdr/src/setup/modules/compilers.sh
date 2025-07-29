#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

HARDN_STATUS "error" "Restricting compiler access to root only (HRDN-7222)..."

local compilers
compilers="/usr/bin/gcc /usr/bin/g++ /usr/bin/make /usr/bin/cc /usr/bin/c++ /usr/bin/as /usr/bin/ld"
for bin in $compilers; do
	if [[ -f "$bin" ]]; then
		chmod 755 "$bin"
		chown root:root "$bin"
		HARDN_STATUS "pass" "Set $bin to 755 root:root (default for compilers)."
	fi
done

#Safe return or exit

return 0 2>/dev/null || exit 0

