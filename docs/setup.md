# Updated Setup Instructions for HARDN

## Installation Steps

1. Download the Debian package:
   ```bash
   wget https://example.com/hardn_<version>.deb
   ```

2. Install the package:
   ```bash
   sudo dpkg -i hardn_<version>.deb
   ```

3. Resolve any missing dependencies:
   ```bash
   sudo apt-get install -f
   ```

4. Run the HARDN application:
   ```bash
   HARDN
   ```

## Features

- Centralized logging for all scripts and tools.
- GUI launches first to verify connections and file paths.
- REST API integration for GUI functionality.
- Command and control runtime daemon for orchestration.
- Modular scripts for STIG compliance and system hardening.