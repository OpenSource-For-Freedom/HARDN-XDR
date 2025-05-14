#!/bin/bash
# Locks inactive accounts for STIG compliance
useradd -D -f 35
for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
    chage --inactive 35 "$user"
done