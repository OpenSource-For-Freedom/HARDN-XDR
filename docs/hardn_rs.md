# HARDN.rs Capabilities Overview

## Core Orchestration
1. Validates root access  
2. Sets executable permissions for key scripts  
3. Runs setup.sh and packages.sh hardening scripts  
4. Launches your Python-based GUI  
5. Monitors file system for changes  
6. Installs and manages systemd services & timers  
7. Provides REST API for GUI integration  

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

3. Provides REST API endpoints:
   - `/auth` for authentication  
   - `/network` for network monitoring  
   - `/threats` for threat detection  
   - `/logs` for log management


