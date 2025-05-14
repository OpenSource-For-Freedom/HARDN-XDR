#!/bin/bash
# Script to manage cron jobs for users

# Check if the user provided a crontab file
if [ "$1" == "edit" ]; then
    echo "Opening crontab for editing..."
    crontab -e
elif [ "$1" == "list" ]; then
    echo "Listing current cron jobs..."
    crontab -l
elif [ "$1" == "add" ]; then
    if [ -z "$2" ]; then
        echo "Usage: $0 add '<cron_job>'"
        exit 1
    fi
    echo "$2" | crontab -l 2>/dev/null | { cat; echo "$2"; } | crontab -
    echo "Cron job added: $2"
elif [ "$1" == "remove" ]; then
    if [ -z "$2" ]; then
        echo "Usage: $0 remove '<cron_job>'"
        exit 1
    fi
    crontab -l | grep -v "$2" | crontab -
    echo "Cron job removed: $2"
else
    echo "Usage: $0 {edit|list|add|remove} [cron_job]"
    exit 1
fi