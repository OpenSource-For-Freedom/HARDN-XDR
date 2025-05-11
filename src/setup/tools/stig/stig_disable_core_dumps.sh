#!/bin/bash
# STIG Disable Core Dumps
echo "* hard core 0" | tee -a /etc/security/limits.conf > /dev/null
echo "fs.suid_dumpable = 0" | tee /etc/sysctl.d/99-coredump.conf > /dev/null
sysctl -w fs.suid_dumpable=0
