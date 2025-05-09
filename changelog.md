# Changelog

<p align="center">
  <img src="https://img.shields.io/badge/OS: UBUNTU 24.04-red?style=for-the-badge&labelColor=grey" alt="OS: UBUNTU 24.04"><br><br>
</p>

## Version 1.1.5 – 2025-05-09

### Added
- Ubuntu Pro FIPS 140-2 compliance script now checks and attaches Ubuntu Pro license interactively if needed.
- User confirmation and interactive shell checks to prevent accidental or automated execution of FIPS setup.
- Improved safety and logging for all critical system changes in FIPS script.

### Improved
- FIPS script now guides the user through the Ubuntu Pro token process for FIPS enablement.
- Enhanced compatibility and safety for login and system boot.

### Fixed
- Prevented FIPS script from running in non-interactive or login environments.
- Ensured no changes are made unless user explicitly confirms.

---

## Version 1

### Added
- **HARDN-Endpoint**: Introduced enhanced CLI-based support for ensuring STIG compliance on Debian 12.
- Added automated STIG compliance validation for Ubuntu Pro, integrated into the CLI workflow.
- Replace UFW with IPTables for more granular Firewall control and policies.
- ASCII banner.
- Testing support for STIG and Licensed FIPS compliance on Ubuntu Pro 24.04.

### Improved
- Kernel principles to align with NIST best practices.

### Fixed
- Aide load and database directory build.
- Fail2ban audit errors

---

*Note*: For detailed CLI usage instructions, refer to the [documentation](https://github.com/OpenSource-For-Freedom/HARDN/blob/main/README.md).
