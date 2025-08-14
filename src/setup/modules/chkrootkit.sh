#!/bin/bash
# Source common functions with fallback for development/CI environments
# Source common functions with fallback for development/CI environments
source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
    log_message() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"; }
    check_root() { [[ $EUID -eq 0 ]]; }
    is_installed() { command -v "$1" >/dev/null 2>&1 || dpkg -s "$1" >/dev/null 2>&1; }
    hardn_yesno() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && return 0
        echo "Auto-confirming: $1" >&2
        return 0
    }
    hardn_msgbox() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && echo "Info: $1" >&2 && return 0
        echo "Info: $1" >&2
    }
    is_container_environment() {
        [[ -n "$CI" ]] || [[ -n "$GITHUB_ACTIONS" ]] || [[ -f /.dockerenv ]] || \
        [[ -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null
    }
    is_systemd_available() {
        [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1
    }
    create_scheduled_task() {
        echo "Info: Scheduled task creation skipped in CI environment" >&2
        return 0
    }
    check_container_limitations() {
        if [[ ! -w /proc/sys ]] || [[ -f /.dockerenv ]]; then
            echo "Warning: Container limitations detected:" >&2
            echo "  - read-only /proc/sys - kernel parameter changes limited" >&2
        fi
        return 0
    }
    hardn_module_exit() {
        local exit_code="${1:-0}"
        exit "$exit_code"
    }
    safe_package_install() {
        local package="$1"
        if [[ "$CI" == "true" ]] || ! check_root; then
            echo "Info: Package installation skipped in CI environment: $package" >&2
            return 0
        fi
        echo "Warning: Package installation not implemented in fallback: $package" >&2
        return 1
    }
}
#!/bin/bash

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
    exit 1
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
set -e
