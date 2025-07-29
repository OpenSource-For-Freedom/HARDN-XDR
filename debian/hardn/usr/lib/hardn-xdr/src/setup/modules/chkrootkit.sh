#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

is_installed() {
    if command -v apt >/dev/null 2>&1; then
        dpkg -s "$1" >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        dnf list installed "$1" >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum list installed "$1" >/dev/null 2>&1
    elif command -v rpm >/dev/null 2>&1; then
        rpm -q "$1" >/dev/null 2>&1
    else
        return 1 # Cannot determine package manager
    fi
}

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
EMAIL="your@email.com"
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/your/webhook/url"

cat <<EOF >/etc/chkrootkit.conf
RUN_DAILY="yes"
SEND_EMAIL="yes"
EMAIL_TO="$EMAIL"
SEND_SLACK="yes"
SLACK_WEBHOOK_URL="$SLACK_WEBHOOK_URL"
EOF

# Create a cron job for daily scan
cat <<'EOF' >/etc/cron.daily/chkrootkit
#!/bin/sh
EMAIL="your@email.com"
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/your/webhook/url"

RESULT=$(/usr/sbin/chkrootkit)
echo "$RESULT" | mail -s "Chkrootkit Daily Scan Results" "$EMAIL"

# Send to Slack
if [ -n "$SLACK_WEBHOOK_URL" ]; then
    PAYLOAD=$(printf '{"text":"Chkrootkit Daily Scan Results:\n%s"}' "$(echo "$RESULT" | sed 's/"/\\"/g')")
    curl -X POST -H 'Content-type: application/json' --data "$PAYLOAD" "$SLACK_WEBHOOK_URL"
fi
EOF
chmod +x /etc/cron.daily/chkrootkit

HARDN_STATUS "info" "Chkrootkit configured for daily scans, email, and Slack alerts."

#Safe return or exit
return 0 2>/dev/null || exit 0
