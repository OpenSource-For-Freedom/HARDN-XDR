#!/bin/bash
# Sets a generic hostname
hostnamectl set-hostname "MY-PC"
echo "127.0.1.1 MY-PC" | tee -a /etc/hosts