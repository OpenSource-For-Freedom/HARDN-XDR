# HARDN GUI

A professional, immersive, non-invasive web-based interface for the HARDN security automation framework.

## Features

- **Military-Grade Interface**: Blue/black color scheme with tactical grid patterns and clear status indicators suitable for government and military use
- **Modular Design**: Easily extendable with clean separation of concerns
- **Non-Invasive**: Does not modify the backend, communicates via Unix socket
- **Zero Dependency Proxy**: Uses only standard Python libraries
- **Real-Time Communication**: Provides live monitoring and control

## Directory Structure

```
src/gui/
├── index.html               # Main HTML entry point
├── css/
│   └── style.css            # Styling for the interface
├── js/
│   ├── main.js              # Core frontend logic
│   └── setup-integration.js # Setup/config integration with setup.sh
├── proxy/
│   └── proxy.py             # Zero-dependency HTTP-to-Unix-socket proxy
└── assets/                  # Images and other static assets
```

## How it Works

The HARDN GUI consists of three main components:

1. **Frontend (HTML/CSS/JS)**: The web interface that users interact with
2. **Proxy (Python)**: A bridge between the frontend and backend
3. **Backend (Rust)**: The core HARDN system that runs as a Unix socket server

The frontend communicates with the proxy via HTTP requests, and the proxy forwards these requests to the backend Unix socket. The proxy also handles setup-related actions by directly interfacing with setup.sh and packages.sh.

### Integration with setup.sh and packages.sh

The GUI integrates with the HARDN setup scripts in two ways:

1. **Direct Status Checks**: The proxy checks system components status using command-line tools
2. **Script Execution**: The proxy can run the setup.sh and packages.sh scripts with appropriate parameters

The integration is designed to be:
- Secure: All privileged operations require appropriate permissions
- Non-invasive: Does not modify existing scripts
- Informative: Provides detailed feedback about operations

### Future integration with main.rs

The GUI is prepared for future integration with main.rs user checks and changes. The infrastructure is in place for:

1. **User Settings**: Getting and setting user configuration options
2. **User Changes**: Requesting and approving user-related changes
3. **Authentication**: Validating user credentials and permissions

## How to Run

1. **Start the backend**:
   ```
   cd /path/to/hardn
   cargo run
   ```
   This ensures that `/tmp/hardn.sock` is available.

2. **Start the proxy**:
   ```
   cd /path/to/hardn
   python3 src/gui/proxy/proxy.py
   ```
   You should see a message that the server is running on http://127.0.0.1:8080.

3. **Open the GUI** in a browser:
   - For development/testing, simply open `src/gui/index.html` directly in a browser
   - For production, serve the files using any web server

## Adding or Updating Features

To add new features to the GUI:

1. **Frontend**: Modify the HTML, CSS, and JavaScript files as needed
2. **Proxy Integration**: Add new actions or modify existing ones in proxy.py
3. **Testing**: Test the changes with the backend running

### Security Notes

- The proxy should be run by a user with sufficient privileges to run setup.sh and packages.sh
- For production environments, consider adding additional authentication to the proxy
- The GUI is designed to be run on a trusted network, not exposed to the internet

## Troubleshooting

- **Proxy Connection Issues**: Make sure the backend is running and that `/tmp/hardn.sock` exists
- **Permission Errors**: Ensure the proxy is run by a user with appropriate permissions
- **Missing Components**: Check that all system components (SELinux, AppArmor, UFW) are properly installed

For detailed logs, check the output of the proxy and backend processes.

## Future Development

- Integration with main.rs for user management
- Enhanced visualization of security threats
- Real-time monitoring dashboard
- Advanced filtering and search capabilities

---
**Respect the mission. Keep it clean, secure, and professional.** 