#!/usr/bin/env python3
# HARDN_DARK
import os
import shutil
import subprocess
import logging
from datetime import datetime
import argparse

LOG_FILE = "/var/log/hardn_deep.log"

# logging
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
        exit(1)

def backup_file(file_path, test_mode=False):
    """Backup a file before modification"""
    if os.path.isfile(file_path):
        backup_path = f"{file_path}.bak"
        if test_mode:
            log(f"[TEST MODE] Would create backup for {file_path} -> {backup_path}")
        else:
            shutil.copy(file_path, backup_path)
            log(f"[+] Backup created: {backup_path}")
    else:
        log(f"[-] {file_path} does not exist. Skipping backup.")

def restore_backups():
    """Restore backups if needed"""
    log("[+] Restoring backups...")
    for root, _, files in os.walk("/etc/security/"):
        for file in files:
            if file.endswith(".bak"):
                original_file = os.path.join(root, file[:-4])
                backup_file = os.path.join(root, file)
                shutil.move(backup_file, original_file)
                log(f"[+] Restored: {original_file}")
# check system comp
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

def disable_core_dumps(test_mode=False):
    """Disable core dumps system-wide"""
    log("[+] Disabling core dumps...")
    backup_file("/etc/security/limits.conf", test_mode)
    run_command("echo '* hard core 0' | sudo tee -a /etc/security/limits.conf > /dev/null", "Core dumps disabled", test_mode)

# tcp wrappers here becasue its in main file (hardn.py)

def restrict_non_local_logins(test_mode=False):
    """Restrict non-local logins except SSH"""
    log("[+] Restricting non-local logins...")
    if os.path.isfile("/etc/security/access.conf"):
        backup_file("/etc/security/access.conf", test_mode)
        run_command("echo '-:ALL:ALL EXCEPT LOCAL,sshd' | sudo tee -a /etc/security/access.conf > /dev/null", "Restricted non-local logins", test_mode)
    else:
        log("[-] /etc/security/access.conf does not exist. Skipping.")

def secure_files(test_mode=False): # sandbox dir
    """Secure critical system files"""
    log("[+] Securing system configuration files...")
    files_to_secure = [
        "/etc/security/limits.conf",
        "/etc/hosts.deny",
        "/etc/security/access.conf"
    ]
    
    for file in files_to_secure:
        if os.path.isfile(file):
            backup_file(file, test_mode)
            run_command(f"sudo chmod 600 {file}", f"Secured {file}", test_mode)
        else:
            log(f"[-] {file} does not exist. Skipping.")

def setup_cron_job(): # daily
    """Setup cron job to run HARDN DARK daily"""
    log("[+] Configuring automatic security hardening cron job...")
    cron_job = f"0 3 * * * /usr/bin/python3 {os.path.abspath(__file__)} >> /var/log/hardn_cron.log 2>&1"
    
    # Check if exists and load 
    cron_jobs = subprocess.run(["crontab", "-l"], capture_output=True, text=True).stdout
    if cron_job not in cron_jobs:
        run_command(f"(crontab -l 2>/dev/null; echo \"{cron_job}\") | crontab -", "Added HARDN DARK cron job")
    else:
        log("[+] Cron job already exists. Skipping.")

def disable_usb_storage(test_mode=False):
    """Disable USB storage devices"""
    log("[+] Disabling USB storage devices...")
    usb_rule = "/etc/modprobe.d/usb-storage.conf"
    backup_file(usb_rule, test_mode)
    run_command("echo 'blacklist usb-storage' | sudo tee /etc/modprobe.d/usb-storage.conf > /dev/null", "USB storage blocked", test_mode)
    run_command("modprobe -r usb-storage", "Unloaded USB storage module", test_mode)

def restrict_su_command(test_mode=False):
    """Restrict su command to only admin group members"""
    log("[+] Restricting 'su' command...")
    backup_file("/etc/pam.d/su", test_mode)
    run_command("echo 'auth required pam_wheel.so' | sudo tee -a /etc/pam.d/su > /dev/null", "Restricted 'su' to admin group", test_mode)

def restart_services(test_mode=False):
    """Restart necessary services"""
    log("[+] Restarting necessary services...")
    services = ["ssh", "fail2ban", "systemd-logind"]
    for service in services:
        run_command(f"systemctl restart {service}", f"Restarted {service} service", test_mode)

def main():
    # Arg's and stuff 
    parser = argparse.ArgumentParser(description="HARDN DARK - Deep Security Hardening for Debian-based Systems")
    parser.add_argument("--test", action="store_true", help="Run in test mode without applying changes")
    parser.add_argument("--restore", action="store_true", help="Restore backups (rollback)")
    args = parser.parse_args()
    
    test_mode = args.test # test

    log("[+] Starting HARDN DARK - Hold on Tight...")
    
    if args.restore:
        restore_backups()
        log("[+] Backups restored. Exiting.")
        exit(0)

    if test_mode:
        log("[TEST MODE] No changes will be applied. This is a dry run.")

    check_compatibility()
    disable_core_dumps(test_mode)
    configure_tcp_wrappers(test_mode)
    restrict_non_local_logins(test_mode)
    secure_files(test_mode)
    disable_usb_storage(test_mode)
    restrict_su_command(test_mode)
    restart_services(test_mode)
    setup_cron_job()

    log("[+] HARDN DARK hardening completed successfully.")

# main 
if __name__ == "__main__":
    main()