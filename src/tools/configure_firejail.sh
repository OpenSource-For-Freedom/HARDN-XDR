#!/bin/bash
# Configures Firejail for Firefox and Chrome
if ! command -v firejail > /dev/null 2>&1; then
    echo "Firejail is not installed. Please install it first."
    exit 1
fi

if command -v firefox > /dev/null 2>&1; then
    ln -sf /usr/bin/firejail /usr/local/bin/firefox
else
    echo "Firefox is not installed. Skipping Firejail setup for Firefox."
fi

if command -v google-chrome > /dev/null 2>&1; then
    ln -sf /usr/bin/firejail /usr/local/bin/google-chrome
else
    echo "Google Chrome is not installed. Skipping Firejail setup for Chrome."
fi