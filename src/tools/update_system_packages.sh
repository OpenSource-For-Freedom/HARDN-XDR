#!/bin/bash
# Updates system packages
apt update -y && apt upgrade -y
apt --fix-broken install -y