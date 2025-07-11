#!/bin/bash

hardn_chkrootkit_is_installed() {
        local package="$1"

        # Use case statement to determine package manager and check installation
        case "$(command -v apt dnf yum rpm 2>/dev/null | head -1)" in
            */apt)  dpkg -s "$package" >/dev/null 2>&1 ;;
            */dnf)  dnf list installed "$package" >/dev/null 2>&1 ;;
            */yum)  yum list installed "$package" >/dev/null 2>&1 ;;
            */rpm)  rpm -q "$package" >/dev/null 2>&1 ;;
            *)      return 1 ;;
        esac
}

# Install chkrootkit if not already installed
hardn_chkrootkit_install() {
        HARDN_STATUS "info" "Setting up Chkrootkit..."

        if hardn_chkrootkit_is_installed chkrootkit; then
            HARDN_STATUS "info" "Chkrootkit is already installed."
            return 0
        fi

        HARDN_STATUS "info" "Installing chkrootkit..."

        # Use case statement to determine package manager and install
        case "$(command -v apt dnf yum 2>/dev/null | head -1)" in
            */apt)  apt install -y chkrootkit >/dev/null 2>&1 ;;
            */dnf)  dnf install -y chkrootkit >/dev/null 2>&1 ;;
            */yum)  yum install -y chkrootkit >/dev/null 2>&1 ;;
            *)
                HARDN_STATUS "error" "No supported package manager found (apt, dnf, yum)."
                return 1
                ;;
        esac

        if ! hardn_chkrootkit_is_installed chkrootkit; then
            HARDN_STATUS "error" "Failed to install chkrootkit. Please check your package manager."
            return 1
        fi

        return 0
}

# Configure chkrootkit for daily scans and alerts
hardn_chkrootkit_configure() {
    local email="${1:-your@email.com}"
    local slack_webhook="${2:-https://hooks.slack.com/services/your/webhook/url}"

    # Create configuration file
    cat > /etc/chkrootkit.conf << EOF
RUN_DAILY="yes"
SEND_EMAIL="yes"
EMAIL_TO="$email"
SEND_SLACK="yes"
SLACK_WEBHOOK_URL="$slack_webhook"
EOF

    # Create daily cron job
    cat > /etc/cron.daily/chkrootkit << 'EOF'
#!/bin/sh
EMAIL="your@email.com"
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/your/webhook/url"

RESULT=$(/usr/sbin/chkrootkit)
echo "$RESULT" | mail -s "Chkrootkit Daily Scan Results" "$EMAIL"

# Send to Slack
if [ -n "$SLACK_WEBHOOK_URL" ]; then
    PAYLOAD=$(printf '{"text":"Chkrootkit Daily Scan Results:\n%s"}' "$(echo "$RESULT" | sed 's/"/\"/g')")
    curl -X POST -H 'Content-type: application/json' --data "$PAYLOAD" "$SLACK_WEBHOOK_URL"
fi
EOF
    chmod +x /etc/cron.daily/chkrootkit

    HARDN_STATUS "info" "Chkrootkit configured for daily scans, email, and Slack alerts."
    return 0
}

# Main function to setup chkrootkit
hardn_chkrootkit_setup() {
        hardn_chkrootkit_install || return 1
        hardn_chkrootkit_configure "$@"
        return 0
}
