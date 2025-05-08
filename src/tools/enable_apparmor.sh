#!/bin/bash
# Enables and configures AppArmor
apt install -y apparmor apparmor-utils apparmor-profiles
systemctl restart apparmor
systemctl enable --now apparmor