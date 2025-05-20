# Changelog

## Version 1.1.8

### Added
- **New Feature**: Introduced a new feature for enhanced system monitoring.

### Improved
- **Performance**: Optimized system performance for faster execution of tasks.

### Fixed
- **Bug Fixes**: Resolved minor bugs reported in version `1.1.6`.

---
## Version 1.1.6

### Added
- **Internet Connectivity Check**: Added a function to verify internet connectivity before proceeding with the setup.
- **Linux Malware Detect (maldet)**: Automated installation and configuration of maldet.
- **Audit Rules**: Configured audit rules for critical system files like `/etc/passwd` and `/etc/shadow`.

### Improved
- **File Permissions**: Fixed permissions for critical files such as `/etc/shadow` and `/etc/passwd`.
- **Service Management**: Enhanced error handling and ensured `Fail2Ban`, `AppArmor`, and `auditd` are enabled and running at boot.
- **SSH Hardening**: Enforced stricter SSH settings for improved security.
- **Kernel Randomization**: Ensured kernel randomization is applied persistently and at runtime.

### Fixed
- **Error Handling**: Improved error handling for services like `Fail2Ban`, `AppArmor`, and `auditd` to prevent setup failures.


---

## Version 1.1.5

### Added
- **Debian Packaging**: Added support for building Debian packages for HARDN.
- **Error Handling**: Enhanced error handling in scripts to prevent disruptions to user logins or system functionality.

### Improved
- **Script Optimization**: Removed redundant steps and consolidated repetitive code blocks in setup scripts.
- **Documentation**: Updated documentation to reflect the latest changes and features.

### Fixed
- **Cron Jobs**: Ensured cron jobs are non-intrusive and do not disrupt user workflows.
- **GRUB BUG**: removed dependant file due to PAM collision and Kernal alerting flaw. 
- **AIDE Initialization**: Improved AIDE initialization process for better reliability.


---

*Note*: For detailed CLI usage instructions, refer to the [documentation](https://github.com/OpenSource-For-Freedom/HARDN/tree/main/docs).