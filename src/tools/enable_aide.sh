#!/bin/bash
# Installs and configures AIDE
if command -v aide >/dev/null 2>&1 && [ -f /var/lib/aide/aide.db ]; then
    echo "AIDE already initialized. Skipping."
    exit 0
fi

apt install -y aide aide-common
aideinit
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db