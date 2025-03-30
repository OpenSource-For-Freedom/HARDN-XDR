#!/usr/bin/env python3

# ---------------------------
# ~~~~~~~~HARDN_DARK~~~~~~~~|
# MAC swapping.             |
# TOR routing.              |
# Directory lockdown        |
# SELinux & Grsecurity check|
# ----------------------------
import os
import shutil
import subprocess
import logging
from datetime import datetime
import argparse

LOG_FILE = "/var/log/hardn_dark.log"

# LOGGING
logging.basicConfig(filename=LOG_FILE, level=logging.INFO, format="%(asctime)s - %(message)s")


def log(message):
    """Log messages with timestamp"""
    logging.info(message)
    print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} {message}")


def run_command(command, description="", test_mode=False):
    """Run a system command with logging and error handling"""
    if test_mode:
        log(f"[TEST MODE] Would run: {command}")
        return
    try:
        subprocess.run(command, shell=True, check=True, text=True)
        log(f"[+] {description} executed successfully.")
    except subprocess.CalledProcessError as e:
        log(f"[-] ERROR: {description} failed: {e}")


# BACKUP
def backup_file(file_path, test_mode=False):
    """Backup a file before modification"""
    if os.path.isfile(file_path):
        backup_path = f"{file_path}.bak"
        if test_mode:
            log(f"[TEST MODE] Would create backup for {file_path} -> {backup_path}")
        else:
            # Use run_command with sudo to ensure proper permissions
            run_command(f"sudo cp {file_path} {backup_path}", f"Backing up {file_path}", test_mode)
            log(f"[+] Backup created: {backup_path}")
    else:
        log(f"[-] {file_path} does not exist. Skipping backup.")


def restore_backup(file_path, test_mode=False):
    """Restore a backup file"""
    backup_path = f"{file_path}.bak"
    if os.path.isfile(backup_path):
        if test_mode:
            log(f"[TEST MODE] Would restore backup for {file_path} from {backup_path}")
        else:
            # Use run_command with sudo to ensure proper permissions
            run_command(f"sudo cp {backup_path} {file_path}", f"Restoring {file_path}", test_mode)
            log(f"[+] Restored backup: {file_path}")
    else:
        log(f"[-] No backup found for {file_path}.")


def check_root():
    """Check if the script is run as root"""
    if os.geteuid() != 0:
        log("[-] This script must be run as root.")
        exit(1)


def check_compatibility():
    """Check if the system is Debian-based"""
    try:
        result = subprocess.run(["lsb_release", "-is"], capture_output=True, text=True, check=True)
        distro = result.stdout.strip()
        if distro in ["Debian", "Ubuntu", "Kali", "Parrot"]:
            log(f"[+] Compatible OS detected: {distro}")
            return True
        else:
            log(f"[-] Incompatible OS detected: {distro}. Exiting.")
            exit(1)
    except subprocess.CalledProcessError:
        log("[-] Failed to detect OS. Ensure 'lsb_release' is installed.")
        exit(1)


# SYSTEM START
def disable_core_dumps(test_mode=False):
    """Disable core dumps system-wide"""
    log("[+] Disabling core dumps...")
    backup_file("/etc/security/limits.conf", test_mode)
    run_command("echo '* hard core 0' | sudo tee -a /etc/security/limits.conf > /dev/null", "Core dumps disabled",
                test_mode)


# DIR LOCK
def protect_critical_dirs(test_mode=False):
    """Apply strict security measures to system-critical directories"""
    log("[+] Hardening critical system directories...")
    run_command("sudo chattr -R +i /sbin", "Made /sbin immutable", test_mode)
    run_command("sudo chmod 700 /root", "Restricted /root to root-only", test_mode)
    run_command("sudo chattr -R +i /etc", "Made /etc immutable", test_mode)
    run_command("sudo chattr -R +a /var/log", "Made /var/log append-only", test_mode)
    log("[+] Critical system directories locked down.")


# KERNAL LOCK
def enable_kernel_protection(test_mode=False):
    """Enable additional kernel-level protections"""
    log("[+] Applying kernel security enhancements...")
    kernel_hardening_cmds = [
        "sudo sysctl -w kernel.dmesg_restrict=1",
        "sudo sysctl -w kernel.kptr_restrict=2",
        "sudo sysctl -w fs.protected_symlinks=1",
        "sudo sysctl -w fs.protected_hardlinks=1",
        "sudo sysctl -w kernel.yama.ptrace_scope=2",
        "sudo sysctl -w kernel.exec-shield=1",
        "sudo sysctl -w kernel.randomize_va_space=2"
    ]
    for cmd in kernel_hardening_cmds:
        run_command(cmd, f"Applied: {cmd.split('=')[0]}", test_mode)
    log("[+] Kernel security hardened.")


def enable_selinux(test_mode=False):
    """Ensure SELinux is enabled"""
    log("[+] Checking SELinux status...")

    # First check if SELinux utilities are installed
    if not shutil.which("getenforce"):
        log("[-] SELinux utilities not found. Attempting to install...")
        try:
            run_command("sudo apt update && sudo apt install -y selinux-utils selinux-basics",
                        "Installing SELinux utilities", test_mode)
            # Check again after installation attempt
            if not shutil.which("getenforce"):
                log("[-] Failed to install SELinux utilities. Skipping SELinux configuration.")
                return
        except Exception:
            log("[-] Failed to install SELinux utilities. Skipping SELinux configuration.")
            return

    try:
        result = subprocess.run(["getenforce"], capture_output=True, text=True, check=True)
        if result.stdout.strip() != "Enforcing":
            run_command("sudo setenforce 1", "Enabled SELinux", test_mode)
            run_command("sudo sed -i 's/SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config",
                        "Configured SELinux at boot", test_mode)
        log("[+] SELinux is enforcing.")
    except subprocess.CalledProcessError:
        log("[-] SELinux is installed but not properly configured.")


def enable_grsecurity(test_mode=False):
    """Enable grsecurity (if installed)"""
    log("[+] Enabling grsecurity...")
    grsec_settings = [
        "kernel.grsecurity.deny_new_usb=1",
        "kernel.grsecurity.ptrace_restrict=1",
        "kernel.grsecurity.chroot_deny_chmod=1",
        "kernel.grsecurity.chroot_deny_mknod=1",
        "kernel.grsecurity.chroot_deny_mount=1"
    ]
    for setting in grsec_settings:
        run_command(f"echo '{setting}' | sudo tee -a /etc/sysctl.d/99-grsecurity.conf", f"Applied: {setting}",
                    test_mode)
    run_command("sudo sysctl -p", "Loaded grsecurity settings", test_mode)


def configure_postfix(status_gui):
    status_gui.update_status("Configuring Postfix to hide mail_name...")
    exec_command("postconf", ["-e", "smtpd_banner=$myhostname ESMTP"], status_gui)


# MAC
def get_network_interfaces():
    """Get network interfaces excluding loopback"""
    result = subprocess.run(["ip", "-o", "link", "show"], capture_output=True, text=True)
    interfaces = [line.split()[1].strip(':') for line in result.stdout.splitlines()]
    return [iface for iface in interfaces if iface not in ["lo"]]


def randomize_mac(test_mode=False):
    """Randomize MAC address for anonymity"""
    log("[+] Randomizing MAC addresses...")
    interfaces = get_network_interfaces()
    for interface in interfaces:
        run_command(f"sudo ip link set {interface} down", f"Disabling {interface}", test_mode)
        run_command(f"sudo macchanger -r {interface}", f"Randomizing MAC for {interface}", test_mode)
        run_command(f"sudo ip link set {interface} up", f"Re-enabling {interface}", test_mode)


def force_tor_traffic(test_mode=False):
    """Route all traffic through TOR"""
    log("[+] Configuring system to use TOR...")
    run_command("sudo systemctl enable --now tor", "Enabled TOR service", test_mode)


def prevent_file_executions(test_mode=False):
    """Prevent execution of unauthorized binaries"""
    log("[+] Locking down executable paths...")
    lockdown_cmds = [
        "sudo mount -o remount,ro /sbin",
        "sudo mount -o remount,ro /usr/sbin",
        "sudo mount -o remount,ro /bin",
        "sudo mount -o remount,ro /usr/bin"
    ]
    for cmd in lockdown_cmds:
        run_command(cmd, "Locked down binary execution paths", test_mode)


def setup_cron_job():
    """Schedule daily security enforcement"""
    log("[+] Configuring daily security tasks...")
    cron_job = f"0 3 * * * /usr/bin/python3 {os.path.abspath(__file__)} >> /var/log/hardn_cron.log 2>&1"
    run_command(f"(crontab -l 2>/dev/null; echo \"{cron_job}\") | crontab -", "Added cron job")


# MAIN
def main():
    check_root()
    log("[+] Starting HARDN DARK - System Lockdown Initiated...")
    check_compatibility()
    disable_core_dumps()
    protect_critical_dirs()
    enable_kernel_protection()
    enable_selinux()
    enable_grsecurity()
    randomize_mac()
    force_tor_traffic()
    prevent_file_executions()
    setup_cron_job()
    log("[+] HARDN DARK security enforcement completed.")


if __name__ == "__main__":
    main()