#!/usr/bin/env bash

# Create Python virtual environment and install dependencies
printf "\e[1;31m[+] Setting up Python virtual environment...\e[0m\n"
python3 -m venv venv
# sleep for 3 seconds
sleep 3
source venv/bin/activate
