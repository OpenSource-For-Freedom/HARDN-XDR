# HARDN.rs Capabilities Overview

## Core Orchestration
1. Validates root access  
2. Sets executable permissions for key scripts  
3. Runs setup.sh and packages.sh hardening scripts  
4. Compiles and runs kernel hardening (`kernel.c`)  
5. Launches your Python-based GUI  
6. Monitors file system for changes  
7. Installs and manages systemd services & timers  

---

## GUI Backend Integration
1. Starts a live in-memory backend with:
   - Authentication service  
   - Network monitor  
   - Threat detection  
   - Log manager  

2. Runs async threads to monitor:
   - Active network connections  
   - Threat detection loop  

3. Starts a Unix socket IPC server at `/tmp/hardn.sock`:
   - Accepts JSON requests from the GUI  
   - Supports actions: `auth`, `network`, `threats`, `logs`  
   - Returns structured JSON responses for each service  


