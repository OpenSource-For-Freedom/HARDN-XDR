#!/usr/bin/env bash

# Script to remove specified directories
# Author: LinuxUser255
# Date: Current date
# Description: Removes gui, hardn-prime, Setup, Src, target, and TODO directories

## Set script to exit on error
#set -e
#
## Define directories to remove
#DIRS_TO_REMOVE=("gui" "hardn-prime" "Setup" "Src" "target" "TODO")
#
## Print header
#echo "====================================="
#echo "Directory Cleanup Script"
#echo "====================================="
#echo
#
## Check if running from the correct directory
#if [ ! -d "gui" ] && [ ! -d "Setup" ] && [ ! -d "Src" ] && [ ! -d "target" ]; then
#    echo "Error: This script must be run from the HARDN project root directory."
#    echo "Required directories not found in current location."
#    exit 1
#fi
#
## Ask for confirmation
#echo "This script will remove the following directories:"
#for dir in "${DIRS_TO_REMOVE[@]}"; do
#    if [ -d "$dir" ]; then
#        echo "- $dir (exists)"
#    else
#        echo "- $dir (not found)"
#    fi
#done
#echo
#echo "WARNING: This action cannot be undone!"
#echo
#
#read -p "Do you want to proceed? (y/n): " confirm
#if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
#    echo "Operation cancelled."
#    exit 0
#fi
#
## Remove directories
#echo
#echo "Removing directories..."
#for dir in "${DIRS_TO_REMOVE[@]}"; do
#    if [ -d "$dir" ]; then
#        echo "Removing $dir..."
#        rm -rf "$dir"
#        echo "✓ $dir removed successfully."
#    else
#        echo "⚠ $dir not found, skipping."
#    fi
#done
#
#echo
#echo "====================================="
#echo "Cleanup completed successfully!"
#echo "====================================="
#
#exit 0