#!/usr/bin/env bash

# Backup and Recovery Security Module
# Part of HARDN-XDR Security Framework
# Purpose: STIG compliance for secure backup and recovery procedures
# STIG Requirements: Offline/immutable backups, hardened recovery processes

# Source common functions with fallback for development/CI environments
source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
    log_message() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"; }
    check_root() { [[ $EUID -eq 0 ]]; }
    is_installed() { command -v "$1" >/dev/null 2>&1 || dpkg -s "$1" >/dev/null 2>&1; }
    hardn_yesno() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && return 0
        echo "Auto-confirming: $1" >&2
        return 0
    }
    hardn_msgbox() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && echo "Info: $1" >&2 && return 0
        echo "Info: $1" >&2
    }
    is_container_environment() {
        [[ -n "$CI" ]] || [[ -n "$GITHUB_ACTIONS" ]] || [[ -f /.dockerenv ]] || \
        [[ -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null
    }
    is_systemd_available() {
        [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1
    }
    create_scheduled_task() {
        echo "Info: Scheduled task creation skipped in CI environment" >&2
        return 0
    }
    check_container_limitations() {
        if [[ ! -w /proc/sys ]] || [[ -f /.dockerenv ]]; then
            echo "Warning: Container limitations detected:" >&2
            echo "  - read-only /proc/sys - kernel parameter changes limited" >&2
        fi
        return 0
    }
    hardn_module_exit() {
        local exit_code="${1:-0}"
        exit "$exit_code"
    }
    safe_package_install() {
        local package="$1"
        if [[ "$CI" == "true" ]] || ! check_root; then
            echo "Info: Package installation skipped in CI environment: $package" >&2
            return 0
        fi
        echo "Warning: Package installation not implemented in fallback: $package" >&2
        return 1
    }
}

MODULE_NAME="Backup and Recovery Security"
CONFIG_DIR="/etc/hardn-xdr/backup-security"
LOG_FILE="/var/log/security/backup-security.log"
BACKUP_POLICY_FILE="$CONFIG_DIR/backup-security-policy.txt"

backup_security_main() {
    HARDN_STATUS "info" "Starting $MODULE_NAME configuration..."

    if ! check_root; then
        HARDN_STATUS "error" "This module requires root privileges"
        return 1
    fi

    mkdir -p "$CONFIG_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"

    # Create backup security documentation
    create_backup_security_policy

    # Set up secure backup procedures
    setup_secure_backup_procedures

    # Configure recovery security
    configure_recovery_security

    # Create automated backup validation
    setup_backup_validation

    HARDN_STATUS "pass" "$MODULE_NAME configuration completed"
    exit 0
}

create_backup_security_policy() {
    HARDN_STATUS "info" "Creating backup security policy documentation..."
    
    cat > "$BACKUP_POLICY_FILE" << 'EOF'
HARDN-XDR Backup and Recovery Security Policy
=============================================

STIG Requirements:
- Backups must be encrypted and stored offline when possible
- Recovery procedures must be tested and documented
- Backup integrity must be verified regularly
- Access to backups must be controlled and logged

1. BACKUP SECURITY PRINCIPLES
=============================

1.1 Encryption Requirements:
- All backups MUST be encrypted using strong algorithms (AES-256 or better)
- Encryption keys must be managed separately from backup data
- Use different encryption keys for different backup sets

1.2 Storage Requirements:
- Primary backups stored on separate systems/networks
- Critical backups stored offline (air-gapped)
- Immutable backup storage when possible (WORM media, object lock)
- Geographic separation for disaster recovery

1.3 Access Controls:
- Role-based access to backup systems
- Multi-person authorization for backup restoration
- All backup operations logged and monitored
- Regular access review and audit

2. BACKUP PROCEDURES
====================

2.1 System Backup Components:
- Operating system configuration (/etc)
- User data and home directories
- Application data and databases
- System logs and audit trails
- Security configurations and keys (separately)

2.2 Backup Schedule:
- Daily incremental backups
- Weekly full system backups
- Monthly offline backup verification
- Quarterly disaster recovery testing

2.3 Backup Verification:
- Automated integrity checks after each backup
- Regular restoration testing
- Checksum verification of backup files
- Encryption validation

3. RECOVERY PROCEDURES
======================

3.1 Recovery Planning:
- Document recovery time objectives (RTO)
- Define recovery point objectives (RPO)
- Maintain updated recovery procedures
- Regular recovery procedure testing

3.2 Emergency Recovery:
- Secure boot media preparation
- Network isolation during recovery
- Integrity verification before restoration
- Post-recovery security validation

3.3 Recovery Security:
- Verify backup integrity before restoration
- Malware scanning of restored data
- Re-apply security configurations
- Audit and log all recovery operations

4. COMPLIANCE REQUIREMENTS
===========================

4.1 STIG Compliance:
- Encrypted backup storage
- Offline backup capabilities
- Recovery procedure documentation
- Regular backup testing and validation

4.2 Audit Requirements:
- All backup operations logged
- Regular compliance assessments
- Backup policy review and updates
- Recovery testing documentation

5. IMPLEMENTATION CHECKLIST
============================

□ Backup encryption configured
□ Offline storage procedures established
□ Recovery procedures documented and tested
□ Access controls implemented
□ Monitoring and alerting configured
□ Regular backup validation scheduled
□ Staff training completed
□ Compliance documentation maintained

For detailed implementation procedures, see the accompanying scripts and documentation.
EOF

    HARDN_STATUS "info" "Backup security policy created at $BACKUP_POLICY_FILE"
}

setup_secure_backup_procedures() {
    HARDN_STATUS "info" "Setting up secure backup procedures..."
    
    # Create secure backup script template
    cat > "$CONFIG_DIR/secure-backup-template.sh" << 'EOF'
#!/bin/bash
# HARDN-XDR Secure Backup Script Template
# Customize this script for your specific backup requirements

set -euo pipefail

# Configuration
BACKUP_SOURCE="/etc /home /var/log /usr/local"
BACKUP_DEST="/backup/hardn-xdr"
ENCRYPTION_KEY_FILE="/etc/hardn-xdr/backup.key"
BACKUP_LOG="/var/log/security/backup.log"
RETENTION_DAYS=90

# Ensure backup destination exists
mkdir -p "$BACKUP_DEST"

# Generate encryption key if it doesn't exist
if [[ ! -f "$ENCRYPTION_KEY_FILE" ]]; then
    echo "Generating backup encryption key..."
    openssl rand -out "$ENCRYPTION_KEY_FILE" 32
    chmod 600 "$ENCRYPTION_KEY_FILE"
    chown root:root "$ENCRYPTION_KEY_FILE"
fi

# Create backup with encryption
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DEST/hardn-backup-$BACKUP_DATE.tar.gz.enc"

echo "$(date): Starting secure backup to $BACKUP_FILE" >> "$BACKUP_LOG"

# Create compressed archive and encrypt
tar czf - $BACKUP_SOURCE 2>/dev/null | \
    openssl aes-256-cbc -salt -in - -out "$BACKUP_FILE" -pass file:"$ENCRYPTION_KEY_FILE"

if [[ $? -eq 0 ]]; then
    echo "$(date): Backup completed successfully" >> "$BACKUP_LOG"
    
    # Generate checksum
    sha256sum "$BACKUP_FILE" > "$BACKUP_FILE.sha256"
    
    # Test backup integrity
    if openssl aes-256-cbc -d -in "$BACKUP_FILE" -pass file:"$ENCRYPTION_KEY_FILE" | tar tzf - >/dev/null 2>&1; then
        echo "$(date): Backup integrity verified" >> "$BACKUP_LOG"
    else
        echo "$(date): WARNING - Backup integrity check failed!" >> "$BACKUP_LOG"
        exit 1
    fi
else
    echo "$(date): ERROR - Backup failed!" >> "$BACKUP_LOG"
    exit 1
fi

# Cleanup old backups
find "$BACKUP_DEST" -name "hardn-backup-*.tar.gz.enc" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
find "$BACKUP_DEST" -name "hardn-backup-*.sha256" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true

echo "$(date): Backup procedure completed" >> "$BACKUP_LOG"
EOF

    chmod +x "$CONFIG_DIR/secure-backup-template.sh"
    chown root:root "$CONFIG_DIR/secure-backup-template.sh"
    
    # Create backup restoration script template
    cat > "$CONFIG_DIR/secure-restore-template.sh" << 'EOF'
#!/bin/bash
# HARDN-XDR Secure Restore Script Template
# Use this script to safely restore from encrypted backups

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <backup-file.tar.gz.enc>"
    echo "Example: $0 /backup/hardn-xdr/hardn-backup-20241213_120000.tar.gz.enc"
    exit 1
fi

BACKUP_FILE="$1"
ENCRYPTION_KEY_FILE="/etc/hardn-xdr/backup.key"
RESTORE_LOG="/var/log/security/restore.log"
RESTORE_DIR="/tmp/hardn-restore-$(date +%Y%m%d_%H%M%S)"

# Verify backup file exists
if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "Error: Backup file $BACKUP_FILE not found"
    exit 1
fi

# Verify encryption key exists
if [[ ! -f "$ENCRYPTION_KEY_FILE" ]]; then
    echo "Error: Encryption key $ENCRYPTION_KEY_FILE not found"
    exit 1
fi

# Verify backup integrity
echo "$(date): Starting secure restoration from $BACKUP_FILE" >> "$RESTORE_LOG"

if [[ -f "$BACKUP_FILE.sha256" ]]; then
    echo "Verifying backup checksum..."
    if sha256sum -c "$BACKUP_FILE.sha256"; then
        echo "$(date): Backup checksum verified" >> "$RESTORE_LOG"
    else
        echo "$(date): ERROR - Backup checksum verification failed!" >> "$RESTORE_LOG"
        exit 1
    fi
else
    echo "Warning: No checksum file found for verification"
fi

# Create restore directory
mkdir -p "$RESTORE_DIR"

# Decrypt and extract backup
echo "Decrypting and extracting backup..."
if openssl aes-256-cbc -d -in "$BACKUP_FILE" -pass file:"$ENCRYPTION_KEY_FILE" | tar xzf - -C "$RESTORE_DIR"; then
    echo "$(date): Backup successfully restored to $RESTORE_DIR" >> "$RESTORE_LOG"
    echo "Backup restored to: $RESTORE_DIR"
    echo "Review the contents before applying to the system"
    echo "Use with caution - verify all files before overwriting system files"
else
    echo "$(date): ERROR - Backup restoration failed!" >> "$RESTORE_LOG"
    rm -rf "$RESTORE_DIR"
    exit 1
fi
EOF

    chmod +x "$CONFIG_DIR/secure-restore-template.sh"
    chown root:root "$CONFIG_DIR/secure-restore-template.sh"
    
    HARDN_STATUS "info" "Secure backup scripts created in $CONFIG_DIR"
}

configure_recovery_security() {
    HARDN_STATUS "info" "Configuring recovery security procedures..."
    
    # Create recovery security checklist
    cat > "$CONFIG_DIR/recovery-security-checklist.txt" << 'EOF'
HARDN-XDR Recovery Security Checklist
=====================================

PRE-RECOVERY SECURITY CHECKS:
□ Verify backup integrity and checksums
□ Scan backup for malware using updated definitions
□ Confirm backup source and creation date
□ Verify encryption key authenticity
□ Document current system state

RECOVERY ENVIRONMENT SECURITY:
□ Isolate recovery system from network if possible
□ Use clean, trusted recovery media
□ Verify recovery system integrity
□ Enable full logging of recovery operations
□ Have incident response team on standby

RECOVERY PROCESS SECURITY:
□ Verify each file before restoration
□ Apply security patches after restoration
□ Restore security configurations
□ Re-enable security monitoring
□ Validate system integrity post-recovery

POST-RECOVERY SECURITY VALIDATION:
□ Run full system security scan
□ Verify all security controls are active
□ Check system logs for anomalies
□ Validate user accounts and permissions
□ Test security tools and monitoring
□ Update security baselines
□ Document recovery process and findings

RECOVERY TESTING REQUIREMENTS:
□ Monthly recovery procedure testing
□ Quarterly full disaster recovery test
□ Annual recovery plan review and update
□ Document all test results
□ Update procedures based on test findings
EOF

    # Create recovery boot media instructions
    cat > "$CONFIG_DIR/recovery-boot-media-guide.txt" << 'EOF'
HARDN-XDR Recovery Boot Media Creation Guide
===========================================

PURPOSE: Create secure, hardened boot media for emergency recovery operations

REQUIREMENTS:
- Clean USB drive (minimum 8GB)
- Debian Live ISO with security tools
- Encryption tools and utilities
- Network utilities and monitoring tools

CREATION PROCESS:
1. Download latest Debian Live ISO
2. Verify ISO checksum and signature
3. Create bootable USB with additional tools
4. Add HARDN-XDR recovery scripts
5. Test boot media on different hardware
6. Document hardware compatibility

SECURITY CONSIDERATIONS:
- Use trusted sources for ISO downloads
- Verify cryptographic signatures
- Store boot media securely when not in use
- Regular updates and testing
- Multiple copies in different locations

RECOVERY BOOT MEDIA CONTENTS:
- Debian Live environment
- Cryptsetup and encryption tools
- Network analysis utilities
- File integrity tools
- Backup/restore utilities
- Security scanning tools
- HARDN-XDR configuration files
- Recovery documentation

USAGE PROCEDURES:
1. Boot from recovery media
2. Validate hardware integrity
3. Establish secure network connection (if needed)
4. Mount and verify backup integrity
5. Perform selective restoration
6. Apply security configurations
7. Validate system integrity
8. Document recovery actions

MAINTENANCE:
- Update recovery media monthly
- Test boot process quarterly
- Verify tool functionality
- Update documentation
- Review and improve procedures
EOF

    HARDN_STATUS "info" "Recovery security documentation created in $CONFIG_DIR"
}

setup_backup_validation() {
    HARDN_STATUS "info" "Setting up automated backup validation..."
    
    # Create backup validation script
    cat > "$CONFIG_DIR/validate-backups.sh" << 'EOF'
#!/bin/bash
# HARDN-XDR Backup Validation Script
# Automated validation of backup integrity and security

set -euo pipefail

BACKUP_DIR="/backup/hardn-xdr"
ENCRYPTION_KEY_FILE="/etc/hardn-xdr/backup.key"
VALIDATION_LOG="/var/log/security/backup-validation.log"

echo "$(date): Starting backup validation" >> "$VALIDATION_LOG"

if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "$(date): ERROR - Backup directory $BACKUP_DIR not found" >> "$VALIDATION_LOG"
    exit 1
fi

if [[ ! -f "$ENCRYPTION_KEY_FILE" ]]; then
    echo "$(date): ERROR - Encryption key $ENCRYPTION_KEY_FILE not found" >> "$VALIDATION_LOG"
    exit 1
fi

VALIDATION_ERRORS=0
BACKUPS_CHECKED=0

# Find recent backup files
for backup_file in "$BACKUP_DIR"/hardn-backup-*.tar.gz.enc; do
    if [[ -f "$backup_file" ]]; then
        ((BACKUPS_CHECKED++))
        echo "$(date): Validating $backup_file" >> "$VALIDATION_LOG"
        
        # Check if backup is less than 7 days old
        if [[ $(find "$backup_file" -mtime -7) ]]; then
            # Verify checksum if available
            if [[ -f "$backup_file.sha256" ]]; then
                if sha256sum -c "$backup_file.sha256" >/dev/null 2>&1; then
                    echo "$(date): Checksum OK for $backup_file" >> "$VALIDATION_LOG"
                else
                    echo "$(date): ERROR - Checksum failed for $backup_file" >> "$VALIDATION_LOG"
                    ((VALIDATION_ERRORS++))
                    continue
                fi
            fi
            
            # Test decryption
            if openssl aes-256-cbc -d -in "$backup_file" -pass file:"$ENCRYPTION_KEY_FILE" | tar tzf - >/dev/null 2>&1; then
                echo "$(date): Encryption/integrity OK for $backup_file" >> "$VALIDATION_LOG"
            else
                echo "$(date): ERROR - Cannot decrypt/read $backup_file" >> "$VALIDATION_LOG"
                ((VALIDATION_ERRORS++))
            fi
        fi
    fi
done

echo "$(date): Backup validation completed - $BACKUPS_CHECKED backups checked, $VALIDATION_ERRORS errors" >> "$VALIDATION_LOG"

if [[ $VALIDATION_ERRORS -gt 0 ]]; then
    echo "$(date): WARNING - Backup validation found $VALIDATION_ERRORS errors!" >> "$VALIDATION_LOG"
    exit 1
else
    echo "$(date): All backup validations passed" >> "$VALIDATION_LOG"
fi
EOF

    chmod +x "$CONFIG_DIR/validate-backups.sh"
    chown root:root "$CONFIG_DIR/validate-backups.sh"
    
    # Create monitoring script for backup health
    cat > "$CONFIG_DIR/backup-health-monitor.sh" << 'EOF'
#!/bin/bash
# HARDN-XDR Backup Health Monitoring
# Checks backup system health and compliance

set -euo pipefail

BACKUP_DIR="/backup/hardn-xdr"
HEALTH_LOG="/var/log/security/backup-health.log"
ALERT_THRESHOLD_DAYS=2

echo "$(date): Starting backup health check" >> "$HEALTH_LOG"

# Check if recent backups exist
RECENT_BACKUPS=$(find "$BACKUP_DIR" -name "hardn-backup-*.tar.gz.enc" -mtime -$ALERT_THRESHOLD_DAYS 2>/dev/null | wc -l)

if [[ $RECENT_BACKUPS -eq 0 ]]; then
    echo "$(date): ALERT - No recent backups found (within $ALERT_THRESHOLD_DAYS days)" >> "$HEALTH_LOG"
    # Here you could add alerting mechanisms (email, SIEM, etc.)
else
    echo "$(date): Found $RECENT_BACKUPS recent backups" >> "$HEALTH_LOG"
fi

# Check backup storage space
BACKUP_USAGE=$(df "$BACKUP_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
if [[ $BACKUP_USAGE -gt 85 ]]; then
    echo "$(date): WARNING - Backup storage $BACKUP_USAGE% full" >> "$HEALTH_LOG"
else
    echo "$(date): Backup storage usage: $BACKUP_USAGE%" >> "$HEALTH_LOG"
fi

# Check encryption key availability
if [[ -f "/etc/hardn-xdr/backup.key" ]]; then
    echo "$(date): Encryption key available" >> "$HEALTH_LOG"
else
    echo "$(date): ERROR - Encryption key not found!" >> "$HEALTH_LOG"
fi

echo "$(date): Backup health check completed" >> "$HEALTH_LOG"
EOF

    chmod +x "$CONFIG_DIR/backup-health-monitor.sh"
    chown root:root "$CONFIG_DIR/backup-health-monitor.sh"
    
    HARDN_STATUS "info" "Backup validation and monitoring scripts created"
    
    # Create cron job suggestions
    cat > "$CONFIG_DIR/cron-suggestions.txt" << 'EOF'
Suggested Cron Jobs for HARDN-XDR Backup Security
=================================================

Add these entries to root's crontab (crontab -e):

# Daily backup validation (run every morning at 6 AM)
0 6 * * * /etc/hardn-xdr/backup-security/validate-backups.sh

# Backup health monitoring (run every 4 hours)
0 */4 * * * /etc/hardn-xdr/backup-security/backup-health-monitor.sh

# Weekly full backup (run every Sunday at 2 AM)
0 2 * * 0 /etc/hardn-xdr/backup-security/secure-backup-template.sh

Example installation:
echo "0 6 * * * /etc/hardn-xdr/backup-security/validate-backups.sh" | crontab -
EOF

    HARDN_STATUS "info" "Cron job suggestions created at $CONFIG_DIR/cron-suggestions.txt"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    backup_security_main "$@"
fi

return 0 2>/dev/null || exit 0
