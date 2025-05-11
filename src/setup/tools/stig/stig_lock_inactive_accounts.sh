#!/bin/bash
# STIG Lock Inactive Accounts
useradd -D -f 35
awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | while read -r user; do
    chage --inactive 35 "$user"
done
