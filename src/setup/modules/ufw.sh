#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e
apt install ufw 
ufw default deny incoming
ufw default allow outgoing 
exit 0