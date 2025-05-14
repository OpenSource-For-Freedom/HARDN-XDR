#!/bin/bash
# Centralized Logging Utility

LOG_FILE="/var/log/hardn-centralized.log"
GUI_LOG_FILE="/var/log/hardn-gui-output.log"

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE" "$GUI_LOG_FILE"
}

info() {
    log "INFO" "$1"
}

warn() {
    log "WARN" "$1"
}

error() {
    log "ERROR" "$1"
}