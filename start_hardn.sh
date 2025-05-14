#!/bin/bash

# HARDN System Startup Script
# This script launches the HARDN (Hardened Active Response Defense Network) system
#
# Architecture:
# - Rust backend: Provides core security services and API endpoints
# - Web GUI: Browser-based interface for monitoring and control
#
# The architecture has been optimized by removing the Python proxy component,
# allowing direct communication between the web GUI and Rust backend via HTTP APIs.

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory - assume script is in project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Define paths
GUI_DIR="$SCRIPT_DIR/src/gui"
LOGS_DIR="$SCRIPT_DIR/src/logs"
TOOLS_DIR="$SCRIPT_DIR/src/tools"

# Ensure logs directory exists
if [ ! -d "$LOGS_DIR" ]; then
    mkdir -p "$LOGS_DIR"
fi

# Kill any existing HARDN processes
kill_existing_processes() {
    echo -e "${BLUE}Checking for existing HARDN processes...${NC}"
    
    # Kill existing Rust backend
    pkill -f "target/debug/hardn" 2>/dev/null
    
    # Kill HTTP server for GUI
    pkill -f "python3 -m http.server.*$(basename "$GUI_DIR")" 2>/dev/null
    
    # Clean up any leftover PID files
    rm -f "$LOGS_DIR"/backend.pid 2>/dev/null
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
    
    # Run the detect_os.sh script to check for supported Linux distributions
    if [ -f "$TOOLS_DIR/detect_os.sh" ]; then
        echo -e "${BLUE}Checking Linux distribution compatibility...${NC}"
        bash "$TOOLS_DIR/detect_os.sh" || {
            echo -e "${RED}Error: Unsupported Linux distribution.${NC}"
            exit 1
        }
    fi
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
    
    # Check for Rust/Cargo
    if ! command -v cargo &> /dev/null; then
        echo -e "${RED}Error: Cargo is required but not found.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Cargo found.${NC}"
    
    # Check for security tools dependencies
    echo -e "${BLUE}Checking security tool dependencies...${NC}"
    local missing_deps=()
    
    # Check for sudo
    if ! command -v sudo &> /dev/null; then
        missing_deps+=("sudo")
    fi
    
    # Check for common security tools
    for cmd in "ufw" "fail2ban-client" "apparmor_status" "firejail"; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}Warning: The following recommended dependencies are missing:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "${YELLOW}  - $dep${NC}"
        done
        echo -e "${YELLOW}Some security features may not be available.${NC}"
        echo -e "${YELLOW}Run 'sudo $TOOLS_DIR/install_pkgdeps.sh' to install dependencies.${NC}"
    else
        echo -e "${GREEN}✓ All security tool dependencies found.${NC}"
    fi
}

# Set proper permissions for executable scripts
set_permissions() {
    echo -e "${BLUE}Setting permissions for security tools...${NC}"
    
    if [ -d "$TOOLS_DIR" ]; then
        # Make all .sh files executable
        find "$TOOLS_DIR" -name "*.sh" -exec chmod +x {} \;
        echo -e "${GREEN}✓ Security tools are now executable.${NC}"
    else
        echo -e "${RED}Error: Tools directory not found at $TOOLS_DIR${NC}"
        exit 1
    fi
}

# Start the Rust backend
start_backend() {
    echo -e "${BLUE}Building and starting Rust backend...${NC}"
    
    # Build the Rust backend
    echo -e "${BLUE}Building Rust backend...${NC}"
    cargo build --quiet
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to build Rust backend.${NC}"
        exit 1
    fi
    
    # Start in background
    echo -e "${BLUE}Starting Rust backend...${NC}"
    cargo run > "$LOGS_DIR/backend.log" 2>&1 &
    BACKEND_PID=$!
    
    # Store PID
    echo "$BACKEND_PID" > "$LOGS_DIR/backend.pid"
    
    # Check if process is running
    if ps -p $BACKEND_PID > /dev/null; then
        echo -e "${GREEN}✓ Backend started (PID: $BACKEND_PID).${NC}"
    else
        echo -e "${RED}Error: Failed to start backend.${NC}"
        exit 1
    fi
    
    # Give it a moment to initialize
    sleep 2
    
    echo -e "${BLUE}Backend API available at: http://localhost:8080/api${NC}"
}

# Start the HTTP server for GUI
start_http_server() {
    echo -e "${BLUE}Starting HTTP server for GUI...${NC}"
    if [ ! -d "$GUI_DIR" ]; then
        echo -e "${RED}Error: GUI directory not found at $GUI_DIR${NC}"
        exit 1
    fi
    
    # Find an available port starting from 8000 (different from backend 8080)
    PORT=8000
    
    # Check if netstat is available
    if command -v netstat &> /dev/null; then
    while netstat -tuln | grep ":$PORT " > /dev/null; do
        PORT=$((PORT+1))
    done
    else
        # If netstat is not available, just use default port 8000
        echo -e "${YELLOW}netstat command not found, using default port 8000${NC}"
    fi
    
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
    
    # Stop backend
    if [ -f "$LOGS_DIR/backend.pid" ]; then
        BACKEND_PID=$(cat "$LOGS_DIR/backend.pid")
        if ps -p $BACKEND_PID > /dev/null; then
            kill $BACKEND_PID
            echo -e "${GREEN}✓ Backend stopped.${NC}"
        fi
        rm "$LOGS_DIR/backend.pid"
    fi
    
    echo -e "${GREEN}All services stopped.${NC}"
    exit 0
}

# Main execution
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}     HARDN System Startup Script      ${NC}"
echo -e "${BLUE}======================================${NC}"

kill_existing_processes
check_os
check_requirements
set_permissions
start_backend
start_http_server
open_gui

echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}HARDN system is now running.${NC}"
echo -e "${YELLOW}Press Ctrl+C to shut down all components.${NC}"
echo -e "${BLUE}======================================${NC}"

# Wait for Ctrl+C
trap stop_services INT TERM
wait 