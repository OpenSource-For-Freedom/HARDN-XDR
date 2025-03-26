#!/usr/bin/env python3
# built IAW "STIG" compliance 
import os
import shutil
import subprocess
import logging
from datetime import datetime
import argparse

LOG_FILE = "/var/log/hardn_deep.log"
logging.basicConfig(filename=LOG_FILE, level=logging.INFO, format="%(asctime)s - %(message)s")

def log(message):
    logging.info(message)
    print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} {message}")

def run_command(command, description="", test_mode=False):
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
    log("[+] Restoring backups...")
    for root, _, files in os.walk("/etc/"):
        for file in files:
            if file.endswith(".bak"):
                original_file = os.path.join(root, file[:-4])
                backup_file = os.path.join(root, file)
                shutil.move(backup_file, original_file)
                log(f"[+] Restored: {original_file}")

def check_compatibility():
    try:
        result = subprocess.run(["lsb_release", "-is"], capture_output=True, text=True, check=True)
        distro = result.stdout.strip()
        if distro in ["Debian", "Ubuntu", "Kali", "Parrot", "LinuxMint", "Pop!_OS"]:
            log(f"[+] Compatible OS detected: {distro}")
            return True
        else:
            log(f"[-] Incompatible OS detected: {distro}. Exiting.")
            exit(1)
    except subprocess.CalledProcessError:
        log("[-] Failed to detect OS. Ensure 'lsb_release' is installed.")
        exit(1)

def disable_core_dumps(test_mode=False):
    log("[+] Disabling core dumps...")
    backup_file("/etc/security/limits.conf", test_mode)
    run_command("echo '* hard core 0' | sudo tee -a /etc/security/limits.conf > /dev/null", "Core dumps disabled", test_mode)

def restrict_non_local_logins(test_mode=False):
    log("[+] Restricting non-local logins...")
    if os.path.isfile("/etc/security/access.conf"):
        backup_file("/etc/security/access.conf", test_mode)
        run_command("echo '-:ALL:ALL EXCEPT LOCAL,sshd' | sudo tee -a /etc/security/access.conf > /dev/null", "Restricted non-local logins", test_mode)
    else:
        log("[-] /etc/security/access.conf does not exist. Skipping.")

def secure_files(test_mode=False):
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

def disable_usb_storage(test_mode=False):
    log("[+] Disabling USB storage devices...")
    usb_rule = "/etc/modprobe.d/usb-storage.conf"
    backup_file(usb_rule, test_mode)
    run_command("echo 'blacklist usb-storage' | sudo tee /etc/modprobe.d/usb-storage.conf > /dev/null", "USB storage blocked", test_mode)
    run_command("modprobe -r usb-storage", "Unloaded USB storage module", test_mode)

def restrict_su_command(test_mode=False):
    log("[+] Restricting 'su' command...")
    backup_file("/etc/pam.d/su", test_mode)
    run_command("echo 'auth required pam_wheel.so' | sudo tee -a /etc/pam.d/su > /dev/null", "Restricted 'su' to admin group", test_mode)

def restart_services(test_mode=False):
    log("[+] Restarting necessary services...")
    services = ["ssh", "fail2ban", "systemd-logind"]
    for service in services:
        run_command(f"systemctl restart {service}", f"Restarted {service} service", test_mode)

def setup_cron_job():
    log("[+] Configuring automatic security hardening cron job...")
    cron_job = f"0 3 * * * /usr/bin/python3 {os.path.abspath(__file__)} >> /var/log/hardn_cron.log 2>&1"
    cron_jobs = subprocess.run(["crontab", "-l"], capture_output=True, text=True).stdout
    if cron_job not in cron_jobs:
        run_command(f"(crontab -l 2>/dev/null; echo \"{cron_job}\") | crontab -", "Added HARDN DARK cron job")
    else:
        log("[+] Cron job already exists. Skipping.")

def stig_compliance_tasks(test_mode=False):
    log("[+] Applying STIG compliance controls...")

    run_command("apt update", "System update", test_mode)
    run_command("apt install -y auditd apparmor aide ufw openscap-utils libopenscap8 lynis", "STIG packages installed", test_mode)

    run_command("ufw default deny incoming", "Set default deny for incoming traffic", test_mode)
    run_command("ufw default allow outgoing", "Set default allow for outgoing traffic", test_mode)
    run_command("ufw enable", "Enable UFW firewall", test_mode)

    run_command("systemctl enable auditd", "Enable auditd", test_mode)
    run_command("systemctl start auditd", "Start auditd", test_mode)

    sysctl_conf = """
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
"""
    with open("/etc/sysctl.d/99-stig.conf", "w") as f:
        f.write(sysctl_conf)
    run_command("sysctl -p /etc/sysctl.d/99-stig.conf", "Apply sysctl STIG config", test_mode)

    pwquality_conf = "/etc/security/pwquality.conf"
    backup_file(pwquality_conf, test_mode)
    with open(pwquality_conf, "a") as f:
        f.write("\nminlen = 14\nretry = 3\nucredit = -1\nlcredit = -1\ndcredit = -1\nocredit = -1\n")
    log("[+] Password policy hardened")

    with open("/etc/sysctl.d/10-disable-ipv6.conf", "w") as f:
        f.write("net.ipv6.conf.all.disable_ipv6 = 1\nnet.ipv6.conf.default.disable_ipv6 = 1\n")
    run_command("sysctl -p /etc/sysctl.d/10-disable-ipv6.conf", "Disable IPv6", test_mode)

    banner_text = "You are accessing a U.S. Government Information System. Unauthorized use is prohibited."
    for banner_file in ["/etc/issue", "/etc/issue.net"]:
        backup_file(banner_file, test_mode)
        with open(banner_file, "w") as f:
            f.write(banner_text)
        log(f"[+] Set banner in {banner_file}")

    run_command("aideinit", "Initialize AIDE DB", test_mode)
    run_command("cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db", "Deploy AIDE DB", test_mode)

    run_command("lynis audit system", "Run Lynis scan", test_mode)

    log("[+] STIG compliance hardening completed.")

def main():
    parser = argparse.ArgumentParser(description="HARDN DARK - Deep Security Hardening for Debian-based Systems")
    parser.add_argument("--test", action="store_true", help="Run in test mode without applying changes")
    parser.add_argument("--restore", action="store_true", help="Restore backups (rollback)")
    args = parser.parse_args()

    test_mode = args.test
    log("[+] Starting HARDN DARK - Hold on Tight...")

    if args.restore:
        restore_backups()
        log("[+] Backups restored. Exiting.")
        exit(0)

    if test_mode:
        log("[TEST MODE] No changes will be applied. This is a dry run.")

    check_compatibility()
    disable_core_dumps(test_mode)
    restrict_non_local_logins(test_mode)
    secure_files(test_mode)
    disable_usb_storage(test_mode)
    restrict_su_command(test_mode)
    restart_services(test_mode)
    stig_compliance_tasks(test_mode)
    setup_cron_job()

    log("[+] HARDN DARK hardening completed successfully.")

if __name__ == "__main__":
    main()