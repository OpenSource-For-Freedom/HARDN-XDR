#!/bin/bash

# Simple HTTP Server for HARDN-XDR Dashboard
# Serves on port 8021
# Auto-updated by hardn_audit.sh

REPORT_DIR="$(dirname "$0")/dashboard"
PORT=8021
TIMESTAMP="2025-08-07 21:32:56"
SCAN_USER="runner@pkrvmjbmru5nbw0"
SYSTEM_INFO="Linux 6.11.0-1018-azure"

echo "🌐 Starting HARDN-XDR Dashboard Server"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Serving from: $REPORT_DIR"
echo "URL: http://localhost:$PORT"
echo "Report: http://localhost:$PORT/hardn-compliance.html"
echo "Last Scan: $TIMESTAMP"
echo "Scan User: $SCAN_USER"
echo "System: $SYSTEM_INFO"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

cd "$REPORT_DIR"

# Check if Python 3 is available
if command -v python3 >/dev/null 2>&1; then
    echo " Using Python 3 HTTP server..."
    echo " Server starting on http://localhost:$PORT"
    echo ""
    python3 -m http.server $PORT
elif command -v python >/dev/null 2>&1; then
    echo "Using Python 2 HTTP server..."
    echo "Server starting on http://localhost:$PORT"
    echo ""
    python -m SimpleHTTPServer $PORT
else
    echo " Python not found. Please install Python to run the server."
    echo "   Try: sudo apt install python3"
    exit 1
fi
