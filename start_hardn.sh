#!/bin/bash

# HARDN System Startup Script
# This script launches all necessary components for the HARDN GUI system

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory - assume script is in project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Define paths
BACKEND_SOCKET="$SCRIPT_DIR/src/backend_socket.py"
PROXY_SERVER="$SCRIPT_DIR/src/gui/proxy/proxy.py"
GUI_DIR="$SCRIPT_DIR/src/gui"
LOGS_DIR="$SCRIPT_DIR/src/logs"

# Ensure logs directory exists
if [ ! -d "$LOGS_DIR" ]; then
    mkdir -p "$LOGS_DIR"
fi

# Kill any existing HARDN processes
kill_existing_processes() {
    echo -e "${BLUE}Checking for existing HARDN processes...${NC}"
    
    # Kill existing Python processes for backend and proxy
    pkill -f "python3 $BACKEND_SOCKET" 2>/dev/null
    pkill -f "python3 $PROXY_SERVER" 2>/dev/null
    
    # Kill HTTP server for GUI
    pkill -f "python3 -m http.server.*$(basename "$GUI_DIR")" 2>/dev/null
    
    # Clean up any leftover PID files
    rm -f "$LOGS_DIR"/backend.pid 2>/dev/null
    rm -f "$LOGS_DIR"/proxy.pid 2>/dev/null
    rm -f "$LOGS_DIR"/http.pid 2>/dev/null
    rm -f "$LOGS_DIR"/http.port 2>/dev/null
    
    echo -e "${GREEN}✓ Removed any existing HARDN processes.${NC}"
    
    # Small delay to ensure ports are freed
    sleep 1
}

# Check OS compatibility
check_os() {
    echo -e "${BLUE}Checking operating system...${NC}"
    if [[ "$(uname)" != "Linux" ]]; then
        echo -e "${RED}Error: This script requires Linux.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Operating system is Linux.${NC}"
}

# Check required software
check_requirements() {
    echo -e "${BLUE}Checking required software...${NC}"
    
    # Check Python 3
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}Error: Python 3 is required but not found.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Python 3 found.${NC}"
    
    # Check for HTTP server capability
    if ! command -v python3 -m http.server --help &> /dev/null; then
        echo -e "${RED}Error: Python http.server module is required.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Python HTTP server module found.${NC}"
}

# Start the backend socket server
start_backend() {
    echo -e "${BLUE}Starting backend socket server...${NC}"
    if [ ! -f "$BACKEND_SOCKET" ]; then
        echo -e "${RED}Error: Backend socket script not found at $BACKEND_SOCKET${NC}"
        exit 1
    fi
    
    # Start in background
    python3 "$BACKEND_SOCKET" > "$LOGS_DIR/backend.log" 2>&1 &
    BACKEND_PID=$!
    
    # Store PID
    echo "$BACKEND_PID" > "$LOGS_DIR/backend.pid"
    
    # Check if process is running
    if ps -p $BACKEND_PID > /dev/null; then
        echo -e "${GREEN}✓ Backend socket server started (PID: $BACKEND_PID).${NC}"
    else
        echo -e "${RED}Error: Failed to start backend socket server.${NC}"
        exit 1
    fi
    
    # Give it a moment to initialize
    sleep 2
}

# Start the proxy server
start_proxy() {
    echo -e "${BLUE}Starting proxy server...${NC}"
    if [ ! -f "$PROXY_SERVER" ]; then
        echo -e "${RED}Error: Proxy server script not found at $PROXY_SERVER${NC}"
        exit 1
    fi
    
    # Start in background
    python3 "$PROXY_SERVER" > "$LOGS_DIR/proxy.log" 2>&1 &
    PROXY_PID=$!
    
    # Store PID
    echo "$PROXY_PID" > "$LOGS_DIR/proxy.pid"
    
    # Check if process is running
    if ps -p $PROXY_PID > /dev/null; then
        echo -e "${GREEN}✓ Proxy server started (PID: $PROXY_PID).${NC}"
    else
        echo -e "${RED}Error: Failed to start proxy server.${NC}"
        exit 1
    fi
    
    # Give it a moment to initialize
    sleep 2
}

# Start the HTTP server for GUI
start_http_server() {
    echo -e "${BLUE}Starting HTTP server for GUI...${NC}"
    if [ ! -d "$GUI_DIR" ]; then
        echo -e "${RED}Error: GUI directory not found at $GUI_DIR${NC}"
        exit 1
    fi
    
    # Find an available port starting from 8080
    PORT=8080
    while netstat -tuln | grep ":$PORT " > /dev/null; do
        PORT=$((PORT+1))
    done
    
    # Start in background
    cd "$GUI_DIR" && python3 -m http.server $PORT > "$LOGS_DIR/http.log" 2>&1 &
    HTTP_PID=$!
    
    # Store PID
    cd "$SCRIPT_DIR" && echo "$HTTP_PID" > "$LOGS_DIR/http.pid"
    
    # Check if process is running
    if ps -p $HTTP_PID > /dev/null; then
        echo -e "${GREEN}✓ HTTP server started on port $PORT (PID: $HTTP_PID).${NC}"
        # Store the port for the browser
        echo "$PORT" > "$LOGS_DIR/http.port"
    else
        echo -e "${RED}Error: Failed to start HTTP server.${NC}"
        exit 1
    fi
}

# Open the GUI in the default browser
open_gui() {
    if [ -f "$LOGS_DIR/http.port" ]; then
        PORT=$(cat "$LOGS_DIR/http.port")
        echo -e "${BLUE}Opening HARDN GUI in browser...${NC}"
        
        # Try different browser opening commands based on the environment
        if command -v xdg-open &> /dev/null; then
            xdg-open "http://localhost:$PORT" &> /dev/null
        elif command -v open &> /dev/null; then
            open "http://localhost:$PORT" &> /dev/null
        elif command -v python3 &> /dev/null; then
            python3 -m webbrowser "http://localhost:$PORT" &> /dev/null
        else
            echo -e "${YELLOW}Please open a browser and navigate to: http://localhost:$PORT${NC}"
        fi
        
        echo -e "${GREEN}✓ HARDN GUI should now be accessible in your browser.${NC}"
        echo -e "${BLUE}If it didn't open automatically, please navigate to: http://localhost:$PORT${NC}"
    else
        echo -e "${RED}Error: HTTP port information not found.${NC}"
    fi
}

# Function to stop all services
stop_services() {
    echo -e "\n${BLUE}Stopping services...${NC}"
    
    # Stop HTTP server
    if [ -f "$LOGS_DIR/http.pid" ]; then
        HTTP_PID=$(cat "$LOGS_DIR/http.pid")
        if ps -p $HTTP_PID > /dev/null; then
            kill $HTTP_PID
            echo -e "${GREEN}✓ HTTP server stopped.${NC}"
        fi
        rm "$LOGS_DIR/http.pid"
    fi
    
    # Stop proxy server
    if [ -f "$LOGS_DIR/proxy.pid" ]; then
        PROXY_PID=$(cat "$LOGS_DIR/proxy.pid")
        if ps -p $PROXY_PID > /dev/null; then
            kill $PROXY_PID
            echo -e "${GREEN}✓ Proxy server stopped.${NC}"
        fi
        rm "$LOGS_DIR/proxy.pid"
    fi
    
    # Stop backend server
    if [ -f "$LOGS_DIR/backend.pid" ]; then
        BACKEND_PID=$(cat "$LOGS_DIR/backend.pid")
        if ps -p $BACKEND_PID > /dev/null; then
            kill $BACKEND_PID
            echo -e "${GREEN}✓ Backend server stopped.${NC}"
        fi
        rm "$LOGS_DIR/backend.pid"
    fi
    
    # Clean up port file
    if [ -f "$LOGS_DIR/http.port" ]; then
        rm "$LOGS_DIR/http.port"
    fi
    
    echo -e "${GREEN}All services stopped.${NC}"
}

# Setup trap to catch Ctrl+C and other signals
trap stop_services EXIT INT TERM

# Main execution
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}      HARDN System Startup Script      ${NC}"
echo -e "${BLUE}======================================${NC}"

kill_existing_processes
check_os
check_requirements
start_backend
start_proxy
start_http_server
open_gui

echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}HARDN system is now running.${NC}"
echo -e "${YELLOW}Press Ctrl+C to shut down all services.${NC}"
echo -e "${BLUE}======================================${NC}"

# Keep script running to maintain trap functionality
while true; do
    sleep 1
done 