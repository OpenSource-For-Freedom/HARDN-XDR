# HARDN: Updated Build and Run Process

## Updated Build Process

1. Ensure all dependencies are installed:
    ```bash
    sudo apt-get update
    sudo apt-get install -y build-essential cargo python3 python3-pyqt6 debhelper devscripts git
    ```

2. Build the Debian package:
    ```bash
    cd ~/HARDN
    dpkg-buildpackage -us -uc
    ```

3. The `.deb` package will be created in the parent directory. Install it:
    ```bash
    sudo dpkg -i ../hardn_<version>.deb
    ```

4. Resolve any missing dependencies:
    ```bash
    sudo apt-get install -f
    ```

## Updated Run Process

1. Launch the HARDN application with the GUI:
    ```bash
    HARDN
    ```

2. Use the GUI to perform tasks such as:
    - Validating packages.
    - Applying STIG hardening.
    - Configuring GRUB.

3. For advanced users, CLI scripts are still available:
    - Validate packages:
      ```bash
      sudo /usr/bin/hardn-packages.sh
      ```
    - Apply STIG hardening:
      ```bash
      sudo /usr/bin/hardn-setup.sh
      ```
    - Configure GRUB:
      ```bash
      sudo /usr/bin/hardn-grub.sh
      ```

## Features

- Centralized logging for all scripts and tools.
- GUI launches first to verify connections and file paths.
- REST API integration for GUI functionality.
- Command and control runtime daemon for orchestration.
- Modular scripts for STIG compliance and system hardening.