### Please review and make necessarry changes, as you guys know more about the licensing, etc.. -Alexis
# HARDN - Hardened Active Response Defense Network

HARDN is a comprehensive security hardening and monitoring solution for Linux systems. It provides real-time threat detection, network monitoring, and security configuration management through an intuitive web interface.

## System Architecture

HARDN uses a two-tier architecture:
1. **Rust Backend**: Provides security services, system monitoring, and REST API endpoints
2. **Web GUI**: Browser-based interface for managing and monitoring system security

## Features

- Real-time network connection monitoring
- Threat detection and mitigation
- Security configuration management (SELinux, AppArmor, firewall)
- System log analysis
- Token-based authentication

## Getting Started

### Prerequisites

- Linux-based operating system
- Rust and Cargo (1.60+)
- Python 3 (for serving the web UI)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-org/hardn.git
cd hardn
```

2. Build the project:
```bash
cargo build --release
```

### Configuration

For production deployments, create a `.env` file in the project root with your configuration settings. See `config/README.md` for available options.

### Running HARDN

Use the start script to launch all components:
```bash
./start_hardn.sh
```

This will start:
- The Rust backend server on port 8080
- A web server for the GUI on port 8000

### Development

For development mode:
```bash
HARDN_ENV=development ./start_hardn.sh
```

## License

[Insert license information here]


