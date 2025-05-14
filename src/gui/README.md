# HARDN GUI

A professional, immersive web-based interface for the HARDN security automation framework.

## Features

- **Military-Grade Interface**: Blue/black color scheme with tactical grid patterns and clear status indicators suitable for government and military use
- **Modular Design**: Easily extendable with clean separation of concerns
- **Direct API Communication**: Communicates directly with the Rust backend via HTTP APIs
- **Real-Time Communication**: Provides live monitoring and control
- **JWT Authentication**: Secure token-based authentication
- **Security Tools Integration**: Direct management of system security tools like AppArmor, AIDE, Fail2Ban, Firejail, and RKHunter

## Directory Structure

```
src/gui/
├── index.html               # Main HTML entry point
├── security-tools.html      # Security tools management interface
├── css/
│   └── style.css            # Styling for the interface
├── js/
│   ├── main.js              # Core frontend logic
│   ├── api-client.js        # API client for backend communication
│   ├── hardn-dashboard.js   # Dashboard components
│   ├── hardn-security-tools.js # Security tools integration
│   └── setup-integration.js # Setup/config integration
└── assets/                  # Images and other static assets
```

## How it Works

The HARDN GUI consists of two main components:

1. **Frontend (HTML/CSS/JS)**: The web interface that users interact with
2. **Backend (Rust)**: The core HARDN system that provides HTTP API endpoints

The frontend communicates directly with the backend via HTTP requests to the Rust API endpoints. The backend handles all security checks, system monitoring, and threat detection functions.

### Integration with Security Services

The GUI integrates with the HARDN security services in several ways:

1. **Direct API Calls**: The frontend makes HTTP requests to the backend API
2. **WebSocket Connections**: For real-time monitoring and updates
3. **JWT Authentication**: Secure token-based authentication for all operations
4. **Security Tools Integration**: Direct management of system security tools 

The integration is designed to be:
- Secure: All privileged operations require appropriate permissions and authentication
- Efficient: Direct communication eliminates middleware overhead
- Informative: Provides detailed feedback about operations

## Security Tools Integration

The HARDN GUI provides a dedicated Security Tools management interface that allows authorized administrators to:

1. **Monitor** the status of security tools
2. **Enable/Disable** security tools 
3. **Configure** tool-specific settings
4. **Run** security scans and checks

Supported security tools include:

- **AppArmor**: Mandatory Access Control system
- **AIDE**: Advanced Intrusion Detection Environment
- **Fail2Ban**: Protection against brute-force attacks
- **Firejail**: Application sandboxing
- **RKHunter**: Rootkit detection and removal

## How to Run

1. **Start the HARDN system**:
   ```
   cd /path/to/hardn
   ./start_hardn.sh
   ```
   This will build and start both the backend and frontend components.

2. **Open the GUI** in a browser:
   - The startup script will attempt to open your default browser automatically
   - If not, navigate to the URL shown in the terminal (typically http://localhost:8000)

## Adding or Updating Features

To add new features to the GUI:

1. **Frontend**: Modify the HTML, CSS, and JavaScript files as needed
2. **Backend API**: Add new endpoints or modify existing ones in gui_api.rs
3. **Testing**: Test the changes with the backend running

### Security Notes

- The backend should be run by a user with sufficient privileges to perform security checks
- For production environments, consider setting up HTTPS and configuring proper firewall rules
- The GUI is designed to be run on a trusted network, not exposed to the internet without proper security measures

## Troubleshooting

- **Connection Issues**: Make sure the backend is running and the API port (8080) is accessible
- **Permission Errors**: Ensure the backend is run by a user with appropriate permissions
- **Missing Components**: Check that all system components (SELinux, AppArmor, UFW) are properly installed

For detailed logs, check the backend logs in the src/logs directory.

## Future Development

- Enhanced visualization of security threats
- Real-time monitoring dashboard
- Advanced filtering and search capabilities
- Multi-user support with role-based access control
- Expanded security tools integration

---
**Respect the mission. Keep it clean, secure, and professional.** 