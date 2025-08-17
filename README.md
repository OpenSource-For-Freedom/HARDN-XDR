# HARDN-XDR

**Linux Security Hardening Extended Detection and Response**

HARDN-XDR is a comprehensive Debian-based security hardening platform designed for government and enterprise compliance standards. It provides automated system hardening, malware detection, and continuous compliance validation through 47+ security modules.

## Features

### 🔒 Security Compliance
- **DISA STIG**: Defense Information Systems Agency Security Technical Implementation Guides
- **CIS Controls**: Center for Internet Security benchmarks and controls
- **FIPS 140-2**: Federal cryptographic standards compliance
- **Debian Security**: Distribution-specific security hardening

### 🛡️ Security Modules (47+)
- **System Hardening**: Kernel security, shared memory protection, core dumps
- **Network Security**: UFW firewall, Fail2Ban, SSH hardening, DNS security
- **Access Control**: Credential protection, SELinux/AppArmor, audit system
- **Malware Detection**: ClamAV, rkhunter, chkrootkit, YARA, behavioral analysis
- **File Integrity**: AIDE, debsums, file permissions, deleted file monitoring
- **Compliance Auditing**: Lynis integration, STIG validation, compliance reporting

### 🏗️ Architecture Support
- **Multi-Architecture**: Native AMD64 and ARM64 support
- **Container-First**: Optimized for Docker, LXC, and VM environments
- **Desktop Support**: GNOME, KDE, XFCE hardening modules
- **Headless Operation**: CI/CD compatible, non-interactive deployment

## Quick Start

### Installation

#### From Debian Package
```bash
# Download the latest release
wget https://github.com/OpenSource-For-Freedom/HARDN-XDR/releases/latest/download/hardn_1.1.63_all.deb

# Install the package
sudo dpkg -i hardn_1.1.63_all.deb
sudo apt-get install -f  # Fix any dependency issues
```

#### From Source
```bash
# Clone the repository
git clone https://github.com/OpenSource-For-Freedom/HARDN-XDR.git
cd HARDN-XDR

# Run the hardening script
sudo ./hardn-xdr
```

### Basic Usage

```bash
# Interactive mode with module selection
sudo hardn-xdr

# Run in headless/CI mode
sudo SKIP_WHIPTAIL=1 ./hardn-xdr

# Run compliance audit and generate dashboard
sudo ./hardn_audit.sh

# Run comprehensive smoke test
sudo ./smoke_test.sh --full
```

## System Requirements

- **OS**: Debian 12+ (Bookworm), Ubuntu 24.04+ (Noble), or compatible derivatives
- **Architecture**: AMD64 or ARM64
- **Memory**: 2GB+ recommended (1GB minimum with memory optimization)
- **Storage**: 500MB free space for full installation
- **Network**: Internet access for package updates and security feeds

## Security Modules Overview

### Essential Modules (Always Applied)
- `auditd.sh` - System audit logging (STIG compliance)
- `sshd.sh` - SSH daemon hardening
- `ufw.sh` - Uncomplicated Firewall setup
- `credential_protection.sh` - Password policies and account security
- `kernel_sec.sh` - Kernel parameter hardening
- `auto_updates.sh` - Automatic security updates
- `aide.sh` - Advanced Intrusion Detection Environment

### Conditional Modules (Container/VM Optimized)
- `fail2ban.sh` - Intrusion prevention system
- `clamav.sh` - Antivirus protection
- `rkhunter.sh` - Rootkit detection
- `chkrootkit.sh` - Additional rootkit scanning
- `suricata.sh` - Network threat detection
- `lynis_audit.sh` - Comprehensive security auditing

### Desktop Modules
- `gnome_hardening.sh` - GNOME desktop security
- `kde_hardening.sh` - KDE Plasma security
- `xfce_hardening.sh` - XFCE desktop security

## Compliance Dashboard

HARDN-XDR includes a Matrix-themed compliance dashboard that provides:
- Real-time compliance metrics for STIG, CIS, FIPS, and Debian standards
- Interactive security findings viewer
- Progress tracking with visual indicators
- Automated report generation

Access the dashboard after running `hardn_audit.sh`:
```bash
# Generate compliance dashboard
sudo ./hardn_audit.sh

# View dashboard (auto-opens web server on port 8021)
# Navigate to: http://localhost:8021/hardn-compliance.html
```

## Documentation

- **[Product Requirements Document](docs/PRD.md)** - Comprehensive project overview
- **[Copilot Instructions](.github/copilot-instructions.md)** - Development guidelines
- **[Implementation Summary](IMPLEMENTATION_SUMMARY.md)** - Recent updates and features
- **[Maintenance Playbook](PLAYBOOK.md)** - Operations and troubleshooting

## Testing and Quality Assurance

```bash
# Run comprehensive smoke tests
sudo ./smoke_test.sh --full

# Test STIG compliance validation
sudo ./smoke_test.sh --compliance

# Quick functionality test
sudo ./smoke_test.sh --quick
```

## Development and Contributing

### Building from Source
```bash
# Install build dependencies
sudo apt-get update
sudo apt-get install debhelper-compat devscripts dpkg-dev build-essential

# Build Debian package
dpkg-buildpackage -us -uc -b

# Test in container environment
docker build -t hardn-xdr-test .
```

### Module Development
```bash
# Create new security module
cp src/setup/modules/template.sh src/setup/modules/new_module.sh

# Follow the established pattern:
# - Source hardn-common.sh
# - Implement module_main() function
# - Add proper error handling
# - Include STIG/CIS compliance documentation
```

## Website and Demo

🌐 **Live Demo**: https://opensource-for-freedom.github.io/HARDN-XDR/

The project includes a Next.js-powered website with:
- Interactive terminal demonstration
- Security feature showcase
- Grey cyber theme design
- Responsive mobile layout

### Website Development
```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Build for GitHub Pages
./build-pages.sh
```

## License

This project is licensed under the terms specified in the [LICENSE](LICENSE) file.

## Support

- **Issues**: [GitHub Issues](https://github.com/OpenSource-For-Freedom/HARDN-XDR/issues)
- **Discussions**: [GitHub Discussions](https://github.com/OpenSource-For-Freedom/HARDN-XDR/discussions)
- **Security**: For security issues, please follow responsible disclosure practices

---

**HARDN-XDR** - Securing Linux systems with government-grade compliance standards.
