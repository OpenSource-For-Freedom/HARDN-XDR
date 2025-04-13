#!/usr/bin/env python3

import getpass
import os
import shutil
import subprocess
import sys
import time
import pexpect

from Src.command_execute import exec_command




# from src import cmd_exec.py
#def exec_command(command, args, status_callback=None):
#    try:
#        if status_callback:
#            status_callback(f"Executing: {command} {' '.join(args)}")
#        print(f"Executing: {command} {' '.join(args)}")
#        process = subprocess.run([command] + args, check=True, text=True, stdout=subprocess.PIPE,
#                                 stderr=subprocess.PIPE, timeout=300)
#        if status_callback:
#            status_callback(f"Completed: {command} {' '.join(args)}")
#        print(process.stdout)
#        return process.stdout
#    except subprocess.CalledProcessError as e:
#        if status_callback:
#            status_callback(f"Error executing '{command} {' '.join(args)}': {e.stderr}")
#        print(f"Error executing command '{command} {' '.join(args)}': {e.stderr}")
#    except subprocess.TimeoutExpired:
#        if status_callback:
#            status_callback(f"Command timed out: {command} {' '.join(args)}")
#        print(f"Command timed out: {command} {' '.join(args)}")
#    except Exception as e:
#        if status_callback:
#            status_callback(f"Unexpected error: {str(e)}")
#        print(f"Unexpected error: {str(e)}")
#    return None


def ensure_root():
    if os.geteuid() != 0:
        print("Restarting as root...")
        try:
            subprocess.run(["sudo", sys.executable] + sys.argv, check=True)
        except subprocess.CalledProcessError as e:
            print(f"Failed to elevate to root: {e}")
        sys.exit(0)
# Call ensure_root() at the beginning of the script, before any other operations
ensure_root()


def directory_structure(test_mode=False):
    sys.path.append(os.path.dirname(os.path.abspath(__file__)))
    script_dir = os.path.dirname(os.path.abspath(__file__))
    HARDN_DARK_PATH = os.path.join(script_dir, "HARDN_dark.py")

    print("HARDN_DARK_PATH:", HARDN_DARK_PATH)
    if not os.path.exists(HARDN_DARK_PATH):
        print(f"Error: HARDN_dark.py not found at {HARDN_DARK_PATH}")
        sys.exit(1)
        return
    return script_dir


# CLI Status Handler
class StatusHandler:
    def __init__(self):
        self.task_count = 0
        self.total_tasks = 15
        self.grub_password = None
        self.log_file = "/var/log/hardn_cli.log"

        # Create log file if it doesn't exist
        if not os.path.exists(os.path.dirname(self.log_file)):
            os.makedirs(os.path.dirname(self.log_file))

        with open(self.log_file, 'w') as f:
            f.write(f"HARDN CLI started at {time.strftime('%Y-%m-%d %H:%M:%S')}\n")

    def update_status(self, message):
        self.task_count += 1
        progress = int((self.task_count / self.total_tasks) * 100)
        print(f"[{progress}%] {message}")

        # Log to file
        with open(self.log_file, 'a') as f:
            f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} - {message}\n")

    def complete(self, lynis_score=None):
        if lynis_score is not None:
            print(f"[100%] Hardening complete! Lynis score: {lynis_score}")
            with open(self.log_file, 'a') as f:
                f.write(f"Hardening complete! Lynis score: {lynis_score}\n")
        else:
            print("[100%] Hardening complete! Lynis score unavailable")
            with open(self.log_file, 'a') as f:
                f.write("Hardening complete! Lynis score unavailable\n")

    def get_grub_password(self):
        print("\nGRUB Password Configuration")
        print("==========================")
        print("Enter a password to secure GRUB bootloader:")
        self.grub_password = getpass.getpass()
        confirm_password = getpass.getpass("Confirm password: ")

        if self.grub_password != confirm_password:
            print("Passwords do not match. Please try again.")
            return self.get_grub_password()

        return self.grub_password


# SECURITY HARDENING FUNCTIONS
def configure_apparmor(status_handler):
    status_handler.update_status("Configuring AppArmor for Mandatory Access Control...")
    exec_command("apt", ["install", "-y", "apparmor", "apparmor-profiles", "apparmor-utils"],
                 status_handler.update_status)
    exec_command("systemctl", ["enable", "--now", "apparmor"], status_handler.update_status)


def configure_firejail(status_handler):
    status_handler.update_status("Configuring Firejail for Application Sandboxing...")
    exec_command("apt", ["install", "-y", "firejail"], status_handler.update_status)

    browsers = ["firefox", "chromium-browser", "google-chrome", "brave-browser"]
    for browser in browsers:
        browser_path = shutil.which(browser)
        if browser_path:
            status_handler.update_status(f"Configuring Firejail for {browser}...")
            exec_command("firejail", ["--private", browser], status_handler.update_status)
            exec_command("firejail", ["--list"], status_handler.update_status)


def enforce_password_policies(status_handler):
    status_handler.update_status("Enforcing password policies...")
    exec_command("apt", ["install", "-y", "libpam-pwquality"], status_handler.update_status)
    exec_command("sh", ["-c",
                        "echo 'password requisite pam_pwquality.so retry=3 minlen=12 difok=3' >> /etc/pam.d/common-password"],
                 status_handler.update_status)


def remove_clamav(status_handler):
    status_handler.update_status("Removing ClamAV...")
    exec_command("apt", ["remove", "--purge", "-y", "clamav", "clamav-daemon"], status_handler.update_status)
    exec_command("rm", ["-rf", "/var/lib/clamav"], status_handler.update_status)


def install_rkhunter(status_handler):
    status_handler.update_status("Installing Rootkit Hunter (rkhunter)...")
    exec_command("apt", ["install", "-y", "rkhunter"], status_handler.update_status)
    exec_command("rkhunter", ["--update"], status_handler.update_status)
    exec_command("rkhunter", ["--propupd"], status_handler.update_status)


def install_maldetect(status_handler):
    status_handler.update_status("Installing Linux Malware Detect (Maldetect)...")
    try:
        exec_command("apt", ["install", "-y", "maldetect"], status_handler.update_status)
        exec_command("maldet", ["-u"], status_handler.update_status)
        status_handler.update_status("Maldetect installation and update completed successfully.")
    except Exception as e:
        status_handler.update_status(f"Error with Maldetect: {str(e)}")


def setup_auto_updates(status_handler):
    status_handler.update_status("Configuring Auto-Update for Security Packages...")
    cron_jobs = [
        "0 3 * * * /opt/eset/esets/sbin/esets_update",
        "0 2 * * * apt update && apt upgrade -y",
        "0 1 * * * lynis audit system --cronjob >> /var/log/lynis_cron.log 2>&1",
        "0 4 * * * rkhunter --update && rkhunter --checkall --cronjob",
        "0 5 * * * maldet -u && maldet -a /",
        "0 6 * * * aide --check"
    ]
    for job in cron_jobs:
        exec_command("sh", ["-c", f"(crontab -l 2>/dev/null; echo '{job}') | crontab -"], status_handler.update_status)


def configure_tcp_wrappers(status_handler):
    status_handler.update_status("Configuring TCP Wrappers...")
    try:
        exec_command("apt", ["install", "-y", "tcpd"], status_handler.update_status)
        with open("/etc/hosts.allow", "w") as f:
            f.write("ALL: 127.0.0.1\n")
        with open("/etc/hosts.deny", "w") as f:
            f.write("ALL: ALL\n")
        status_handler.update_status("TCP Wrappers configured successfully.")
    except Exception as e:
        status_handler.update_status(f"Error configuring TCP Wrappers: {str(e)}")


def configure_fail2ban(status_handler):
    status_handler.update_status("Setting up Fail2Ban...")
    exec_command("apt", ["install", "-y", "fail2ban"], status_handler.update_status)
    exec_command("systemctl", ["restart", "fail2ban"], status_handler.update_status)
    exec_command("systemctl", ["enable", "--now", "fail2ban"], status_handler.update_status)


def run_lynis_audit(status_handler):
    status_handler.update_status("Running Lynis security audit...")
    try:
        profile_path = "/etc/lynis/custom.prf"
        command = ["sudo", "lynis", "audit", "system"]
        if os.path.exists(profile_path):
            command.extend(["--profile", profile_path])
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        output = []
        for line in iter(process.stdout.readline, ''):
            status_handler.update_status(line.strip())
            output.append(line.strip())
        process.stdout.close()
        process.wait()
        if process.returncode != 0:
            raise subprocess.CalledProcessError(process.returncode, process.args)
        with open("/var/log/lynis.log", "w") as log_file:
            log_file.write("\n".join(output))
        lynis_score = None
        for line in output:
            if "Hardening index" in line:
                lynis_score = line.split(":")[1].strip()
                break
        if lynis_score:
            status_handler.update_status(f"Lynis score: {lynis_score}")
        else:
            status_handler.update_status("Lynis score unavailable")
        return lynis_score
    except Exception as e:
        status_handler.update_status(f"Error running Lynis audit: {str(e)}")
    return None


def configure_grub(status_handler):
    status_handler.update_status("Configuring GRUB Security Settings...")
    grub_cmd = shutil.which("update-grub") or shutil.which("grub-mkconfig")
    if grub_cmd:
        try:
            subprocess.run([grub_cmd, "-o", "/boot/grub/grub.cfg"], check=True, timeout=120)
        except subprocess.TimeoutExpired:
            status_handler.update_status("Command timed out: update-grub")
    else:
        status_handler.update_status("Warning: GRUB update command not found. Skipping GRUB update.")
        status_handler.update_status("If running inside a VM, this may not be necessary.")


def configure_firewall(status_handler):
    status_handler.update_status("Configuring Firewall...")
    exec_command("ufw", ["default", "deny", "incoming"], status_handler.update_status)
    exec_command("ufw", ["default", "allow", "outgoing"], status_handler.update_status)
    exec_command("ufw", ["allow", "out", "80,443/tcp"], status_handler.update_status)
    exec_command("ufw", ["--force", "enable"], status_handler.update_status)
    exec_command("ufw", ["reload"], status_handler.update_status)


def secure_grub(status_handler):
    status_handler.update_status("Configuring GRUB Secure Boot Password...")
    grub_password = status_handler.get_grub_password()

    child = pexpect.spawn("grub-mkpasswd-pbkdf2")
    child.expect("Enter password: ")
    child.sendline(grub_password)
    child.expect("Reenter password: ")
    child.sendline(grub_password)
    child.expect(pexpect.EOF)
    output = child.before.decode()
    
    hashed_password = ""
    for line in output.split("\n"):
        if "PBKDF2 hash of your password is" in line:
            hashed_password = line.split("is ")[1].strip()
            break
            
    if not hashed_password:
        status_handler.update_status("Failed to generate GRUB password hash.")
        return
        
    grub_config = f"set superusers=\"admin\"\npassword_pbkdf2 admin {hashed_password}\n"
    with open("/etc/grub.d/00_password", "w") as f:
        f.write(grub_config)
        
    exec_command("update-grub", [], status_handler.update_status)
