#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

HARDN_STATUS "info" "Setting up Chkrootkit..."

if ! is_installed chkrootkit; then
    HARDN_STATUS "info" "Installing chkrootkit..."
    if command -v apt >/dev/null 2>&1; then
        apt install -y chkrootkit >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y chkrootkit >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum install -y chkrootkit >/dev/null 2>&1
    fi
fi

if ! is_installed chkrootkit; then
    HARDN_STATUS "error" "Failed to install chkrootkit. Please check your package manager."
    return 1
fi

# Optional: Configure daily scan and email/slack alerts
EMAIL="${HARDN_EMAIL:-admin@localhost}"
SLACK_WEBHOOK_URL="${HARDN_SLACK_WEBHOOK:-}"

cat <<EOF >/etc/chkrootkit.conf
RUN_DAILY="yes"
SEND_EMAIL="yes"
EMAIL_TO="$EMAIL"
SEND_SLACK="$([ -n "$SLACK_WEBHOOK_URL" ] && echo "yes" || echo "no")"
SLACK_WEBHOOK_URL="$SLACK_WEBHOOK_URL"
EOF

# Create a cron job for daily scan
cat <<EOF >/etc/cron.daily/chkrootkit
#!/bin/sh
# Source the configuration file
[ -f /etc/chkrootkit.conf ] && . /etc/chkrootkit.conf

# Set defaults if not configured
EMAIL="\${EMAIL_TO:-admin@localhost}"
SLACK_WEBHOOK_URL="\${SLACK_WEBHOOK_URL:-}"

RESULT=\$(/usr/sbin/chkrootkit)

# Send email if configured
if [ "\$SEND_EMAIL" = "yes" ] && command -v mail >/dev/null 2>&1; then
    echo "\$RESULT" | mail -s "Chkrootkit Daily Scan Results" "\$EMAIL"
fi

# Send to Slack if configured
if [ "\$SEND_SLACK" = "yes" ] && [ -n "\$SLACK_WEBHOOK_URL" ]; then
    PAYLOAD=\$(printf '{"text":"Chkrootkit Daily Scan Results:\\n%s"}' "\$(echo "\$RESULT" | sed 's/"/\\\\"/g')")
    curl -X POST -H 'Content-type: application/json' --data "\$PAYLOAD" "\$SLACK_WEBHOOK_URL" >/dev/null 2>&1
fi
EOF
chmod +x /etc/cron.daily/chkrootkit

HARDN_STATUS "pass" "Chkrootkit installed successfully."
HARDN_STATUS "info" "Daily scans configured with email notifications to: $EMAIL"
if [ -n "$SLACK_WEBHOOK_URL" ]; then
    HARDN_STATUS "info" "Slack notifications enabled."
else
    HARDN_STATUS "info" "Slack notifications disabled (set HARDN_SLACK_WEBHOOK to enable)."
fi

return 0 2>/dev/null || hardn_module_exit 0
