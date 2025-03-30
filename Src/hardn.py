#!/user/bin/env python3

import os
import subprocess
import sys
import threading
import shutil
import tkinter as tk
from tkinter import ttk
import pexpect

# Add current to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def ensure_root():
    if os.geteuid() != 0:
        print("Restarting as root...")
        try:
            subprocess.run(["sudo", sys.executable] + sys.argv, check=True)
        except subprocess.CalledProcessError as e:
            print(f"Failed to elevate to root: {e}")
        sys.exit(0)

ensure_root()

def exec_command(command, args, status_gui=None):
    try:
        if status_gui:
            status_gui.update_status(f"Executing: {command} {' '.join(args)}")
        print(f"Executing: {command} {' '.join(args)}")
        process = subprocess.run([command] + args, check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=300)
        if status_gui:
            status_gui.update_status(f"Completed: {command} {' '.join(args)}")
        print(process.stdout)
    except subprocess.CalledProcessError as e:
        if status_gui:
            status_gui.update_status(f"Error executing '{command} {' '.join(args)}': {e.stderr}")
        print(f"Error executing command '{command} {' '.join(args)}': {e.stderr}")
    except subprocess.TimeoutExpired:
        if status_gui:
            status_gui.update_status(f"Command timed out: {command} {' '.join(args)}")
        print(f"Command timed out: {command} {' '.join(args)}")
    except Exception as e:
        if status_gui:
            status_gui.update_status(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")

def print_ascii_art():
    art = """
             ██░ ██  ▄▄▄       ██▀███  ▓█████▄  ███▄    █ 
            ▓██░ ██▒▒████▄    ▓██ ▒ ██▒▒██▀ ██▌ ██ ▀█   █ 
            ▒██▀▀██░▒██  ▀█▄  ▓██ ░▄█ ▒░██   █▌▓██  ▀█ ██▒
            ░▓█ ░██ ░██▄▄▄▄██ ▒██▀▀█▄  ░▓█▄   ▌▓██▒  ▐▌██▒
            ░▓█▒░██▓ ▓█   ▓██▒░██▓ ▒██▒░▒████▓ ▒██░   ▓██░
             ▒ ░░▒░▒ ▒▒   ▓▒█░░ ▒▓ ░▒▓░ ▒▒▓  ▒ ░ ▒░   ▒ ▒ 
             ▒ ░▒░ ░  ▒   ▒▒ ░  ░▒ ░ ▒░ ░ ▒  ▒ ░ ░░   ░ ▒░
             ░  ░░ ░  ░   ▒     ░░   ░  ░ ░  ░    ░   ░ ░ 
             ░  ░  ░      ░  ░   ░        ░             ░ 
                                ░                 
                "HARDN" - The Linux Security Project
              ----------------------------------------
              "A single Debian tool to fully secure an 
             OS using automation, monitoring, heuristics 
                        and availability.
                      DEV: Tim "Tank" Burns
                          License: MIT
              ----------------------------------------
    """
    return art

# GET DIR
script_dir = os.path.dirname(os.path.abspath(__file__))

# FILE PATH - to dependents 
HARDN_DARK_PATH = os.path.join(script_dir, "HARDN_dark.py")

print("HARDN_DARK_PATH:", HARDN_DARK_PATH)

# GUI
class StatusGUI:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("HARDN")
        self.root.geometry("800x600")
        self.root.configure(bg='#333333')

        self.canvas = tk.Canvas(self.root, width=800, height=600, bg='#333333', highlightthickness=0)
        self.canvas.pack(fill="both", expand=True)

        self.progress = ttk.Progressbar(self.root, length=700, mode="determinate")
        self.progress_window = self.canvas.create_window(400, 550, window=self.progress)

        self.status_text = tk.StringVar()
        self.status_label = ttk.Label(self.root, textvariable=self.status_text, background='#333333', foreground='white')
        self.status_label_window = self.canvas.create_window(400, 580, window=self.status_label)

        self.log_text = tk.Text(self.root, height=10, width=90, bg='#222222', fg='white', highlightthickness=0)
        self.log_text_window = self.canvas.create_window(400, 400, window=self.log_text)

        self.task_count = 0
        self.total_tasks = 15  

        self.display_ascii_art()

    def display_ascii_art(self):
        ascii_art = print_ascii_art()
        self.canvas.create_text(400, 200, text=ascii_art, fill="white", font=("Courier", 8), anchor="center")

    def update_status(self, message):
        self.task_count += 1
        self.progress["value"] = (self.task_count / self.total_tasks) * 100
        self.status_text.set(message)
        self.log_text.insert(tk.END, message + "\n")
        self.log_text.see(tk.END)
        self.root.update_idletasks()
        
# LYNIS - def, currently having gui output issue for scoring 
    def complete(self, lynis_score=None):
        self.progress["value"] = 100
        if lynis_score is not None:
            self.status_text.set(f"Hardening complete! Lynis score: {lynis_score}")
            self.log_text.insert(tk.END, f"Lynis score: {lynis_score}\n")
        else:
            self.status_text.set("Hardening complete! Lynis score unavailable")
            self.log_text.insert(tk.END, "Lynis score unavailable\n")

    def run(self):
        self.root.mainloop()

    def get_grub_password(self):
        self.password_window = tk.Toplevel(self.root)
        self.password_window.title("Enter GRUB Password")
        self.password_window.geometry("300x150")
        self.password_window.configure(bg='#333333')

        self.password_label = ttk.Label(self.password_window, text="Enter GRUB Password:", background='#333333', foreground='white')
        self.password_label.pack(pady=10)

        self.password_entry = ttk.Entry(self.password_window, show="*")
        self.password_entry.pack(pady=10)

        self.submit_button = ttk.Button(self.password_window, text="Submit", command=self.submit_password)
        self.submit_button.pack(pady=10)

    def submit_password(self):
        self.grub_password = self.password_entry.get()
        self.password_window.destroy()
        self.root.quit()  # Exit the main loop to continue the script

# SECURITY HARDENING FUNCTIONS
def configure_apparmor(status_gui):
    status_gui.update_status("Configuring AppArmor for Mandatory Access Control...")
    exec_command("apt", ["install", "-y", "apparmor", "apparmor-profiles", "apparmor-utils"], status_gui)
    exec_command("systemctl", ["enable", "--now", "apparmor"], status_gui)

def configure_firejail(status_gui):
    status_gui.update_status("Configuring Firejail for Application Sandboxing...")
    exec_command("apt", ["install", "-y", "firejail"], status_gui)
    
    browsers = ["firefox", "chromium-browser", "google-chrome", "brave-browser"]
    for browser in browsers:
        browser_path = shutil.which(browser)
        if browser_path:
            status_gui.update_status(f"Configuring Firejail for {browser}...")
            exec_command("firejail", ["--private", browser], status_gui)
            exec_command("firejail", ["--list"], status_gui)

def enforce_password_policies(status_gui):
    exec_command("apt", ["install", "-y", "libpam-pwquality"], status_gui)
    exec_command("sh", ["-c", "echo 'password requisite pam_pwquality.so retry=3 minlen=12 difok=3' >> /etc/pam.d/common-password"], status_gui)

def remove_clamav(status_gui):
    status_gui.update_status("Removing ClamAV...")
    exec_command("apt", ["remove", "--purge", "-y", "clamav", "clamav-daemon"], status_gui)
    exec_command("rm", ["-rf", "/var/lib/clamav"], status_gui)

def install_rkhunter(status_gui):
    status_gui.update_status("Installing Rootkit Hunter (rkhunter)...")
    exec_command("apt", ["install", "-y", "rkhunter"], status_gui)
    exec_command("rkhunter", ["--update"], status_gui)
    exec_command("rkhunter", ["--propupd"], status_gui)
# LMD 
def install_maldetect(status_gui):
    status_gui.update_status("Installing Linux Malware Detect (Maldetect)...")
    try:
        exec_command("apt", ["install", "-y", "maldetect"], status_gui)
        exec_command("maldet", ["-u"], status_gui)
        status_gui.update_status("Maldetect installation and update completed successfully.")
    except subprocess.CalledProcessError as e:
        status_gui.update_status(f"Error installing Maldetect: {e.stderr}")
        print(f"Error installing Maldetect: {e.stderr}")
    except subprocess.TimeoutExpired:
        status_gui.update_status("Command timed out: apt install maldetect or maldet -u")
        print("Command timed out: apt install maldetect or maldet -u")
    except Exception as e:
        status_gui.update_status(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")
# UPDATE 
def setup_auto_updates(status_gui):
    status_gui.update_status("Configuring Auto-Update for Security Packages...")
    cron_jobs = [
        "0 3 * * * /opt/eset/esets/sbin/esets_update",
        "0 2 * * * apt update && apt upgrade -y",
        "0 1 * * * lynis audit system --cronjob >> /var/log/lynis_cron.log 2>&1",
        "0 4 * * * rkhunter --update && rkhunter --checkall --cronjob",
        "0 5 * * * maldet -u && maldet -a /",
        "0 6 * * * aide --check"
    ]
    for job in cron_jobs:
        exec_command("sh", ["-c", f"(crontab -l 2>/null; echo '{job}') | crontab -"], status_gui)
# TCP WRAP
def configure_tcp_wrappers(status_gui):
    status_gui.update_status("Configuring TCP Wrappers...")
    try:
        exec_command("apt", ["install", "-y", "tcpd"], status_gui)
        with open("/etc/hosts.allow", "w") as f:
            f.write("ALL: 127.0.0.1\n")
        with open("/etc/hosts.deny", "w") as f:
            f.write("ALL: ALL\n")
        status_gui.update_status("TCP Wrappers configured successfully.")
    except subprocess.CalledProcessError as e:
        status_gui.update_status(f"Error configuring TCP Wrappers: {e.stderr}")
        print(f"Error configuring TCP Wrappers: {e.stderr}")
    except Exception as e:
        status_gui.update_status(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")
# F2B
def configure_fail2ban(status_gui):
    status_gui.update_status("Setting up Fail2Ban...")
    exec_command("apt", ["install", "-y", "fail2ban"], status_gui)
    exec_command("systemctl", ["restart", "fail2ban"], status_gui)
    exec_command("systemctl", ["enable", "--now", "fail2ban"], status_gui)
# LYNIS START
def run_lynis_audit(status_gui):
    status_gui.update_status("Running Lynis security audit...")
    try:
        profile_path = "/etc/lynis/custom.prf"
        command = ["sudo", "lynis", "audit", "system"]
        if os.path.exists(profile_path):
            command.extend(["--profile", profile_path])
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        output = []
        for line in iter(process.stdout.readline, ''):
            status_gui.update_status(line.strip())
            print(line.strip())
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
            status_gui.update_status(f"Lynis score: {lynis_score}")
            print(f"Lynis score: {lynis_score}")
        else:
            status_gui.update_status("Lynis score unavailable")
            print("Lynis score unavailable")
        return lynis_score
    except subprocess.CalledProcessError as e:
        status_gui.update_status(f"Error running Lynis audit: {e.stderr}")
        print(f"Error running Lynis audit: {e.stderr}")
    except Exception as e:
        status_gui.update_status(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")
# GRIB
def configure_grub(status_gui):
    status_gui.update_status("Configuring GRUB Security Settings...")
    grub_cmd = shutil.which("update-grub") or shutil.which("grub-mkconfig")
    if grub_cmd:
        try:
            subprocess.run([grub_cmd, "-o", "/boot/grub/grub.cfg"], check=True, timeout=120)
        except subprocess.TimeoutExpired:
            status_gui.update_status("Command timed out: update-grub")
    else:
        print("Warning: GRUB update command not found. Skipping GRUB update.")
        print("If running inside a VM, this may not be necessary.")
# UFW
def configure_firewall(status_gui):
    status_gui.update_status("Configuring Firewall...")
    exec_command("ufw", ["default", "deny", "incoming"], status_gui)
    exec_command("ufw", ["default", "allow", "outgoing"], status_gui)
    exec_command("ufw", ["allow", "out", "80,443/tcp"], status_gui)
    exec_command("ufw", ["--force", "enable"], status_gui)
    exec_command("ufw", ["reload"], status_gui)
# GRUB SEC
def secure_grub(status_gui):
    status_gui.update_status("Configuring GRUB Secure Boot Password...")
    status_gui.get_grub_password()
    status_gui.root.mainloop()  # Wait for the user to enter the password
    grub_password = status_gui.grub_password
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
        status_gui.update_status("Failed to generate GRUB password hash.")
        return
    grub_config = f"set superusers=\"admin\"\npassword_pbkdf2 admin {hashed_password}\n"
    with open("/etc/grub.d/00_password", "w") as f:
        f.write(grub_config)
    exec_command("update-grub", [], status_gui)

def enable_aide(status_gui):
    status_gui.update_status("Installing and configuring AIDE...")
    exec_command("apt", ["install", "-y", "aide", "aide-common"], status_gui)
    status_gui.update_status("Initializing AIDE database (this may take a while)...")
    threading.Thread(target=run_aideinit, args=(status_gui,)).start()

def run_aideinit(status_gui):
    try:
        exec_command("aideinit", [], status_gui)
        exec_command("mv", ["/var/lib/aide/aide.db.new", "/var/lib/aide/aide.db"], status_gui)
    except subprocess.TimeoutExpired:
        status_gui.update_status("Command timed out: aideinit && mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db")

def harden_sysctl(status_gui):
    exec_command("sysctl", ["-w", "net.ipv4.conf.all.accept_redirects=0"], status_gui)
    exec_command("sysctl", ["-w", "net.ipv4.conf.all.send_redirects=0"], status_gui)

def disable_usb(status_gui):
    status_gui.update_status("Locking down USB devices...")
    exec_command("sh", ["-c", "echo 'blacklist usb-storage' >> /etc/modprobe.d/usb-storage.conf"], status_gui)
    exec_command("modprobe", ["-r", "usb-storage"], status_gui)

def software_integrity_check(status_gui):
    status_gui.update_status("Software Integrity Check...")
    exec_command("debsums", ["-s"], status_gui)

def run_audits(status_gui):
    status_gui.update_status("Running Security Audits...")
    lynis_cmd = shutil.which("lynis")
    if not lynis_cmd:
        status_gui.update_status("Lynis not found. Please ensure Lynis is installed.")
        return
    
    profile_path = "/etc/lynis/custom.prf"
    if not os.path.exists(profile_path):
        profile_path = "default"
    
    exec_command(lynis_cmd, ["audit", "system", "--profile", profile_path], status_gui)

def scan_with_eset(status_gui):
    status_gui.update_status("Scanning system with ESET NOD32 (ES32) Antivirus...")
    exec_command("/opt/eset/esets/sbin/esets_scan", ["/home"], status_gui)

def configure_postfix(status_gui):
    status_gui.update_status("Configuring Postfix to hide mail_name...")
    exec_command("postconf", ["-e", "smtpd_banner=$myhostname ESMTP"], status_gui)