import os
import sys
import subprocess
import shutil
import threading
import pexpect
import tkinter as tk
from tkinter import messagebox
import time

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

def check_and_install_dependencies(status_gui):
    apt_dependencies = [
        "apparmor", "apparmor-profiles", "apparmor-utils", "firejail", "libpam-pwquality",
        "tcpd", "fail2ban", "rkhunter", "aide", "aide-common", "ufw", "postfix", "debsums", "python3-pexpect", "python3-tk", "policycoreutils", "selinux-utils", "selinux-basics", "docker.io"
    ]
    # PIP
    pip_dependencies = []
    with open('/home/tim/Desktop/HARDN/requirements.txt', 'r') as f:
        pip_dependencies = f.read().splitlines()

    for package in apt_dependencies:
        try:
            status_gui.update_status(f"Checking for {package}...")
            result = subprocess.run(f"dpkg -s {package}", shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if "install ok installed" not in result.stdout.decode():
                status_gui.update_status(f"{package} not found. Installing...")
                exec_command("apt", ["install", "-y", package], status_gui)
            else:
                status_gui.update_status(f"{package} is already installed.")
        except subprocess.CalledProcessError:
            status_gui.update_status(f"{package} not found. Installing...")
            exec_command("apt", ["install", "-y", package], status_gui)

    for package in pip_dependencies:
        try:
            status_gui.update_status(f"Checking for pip package {package}...")
            result = subprocess.run(f"pip show {package}", shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            if not result.stdout:
                status_gui.update_status(f"pip package {package} not found. Installing...")
                exec_command("pip", ["install", package], status_gui)
            else:
                status_gui.update_status(f"pip package {package} is already installed.")
        except subprocess.CalledProcessError:
            status_gui.update_status(f"pip package {package} not found. Installing...")
            exec_command("pip", ["install", package], status_gui)

def enforce_password_policies(status_gui):
    exec_command("apt", ["install", "-y", "libpam-pwquality"], status_gui)
    exec_command("sh", ["-c", "echo 'password requisite pam_pwquality.so retry=3 minlen=12 difok=3' >> /etc/pam.d/common-password"], status_gui)
# SECURITY PACKAGES #######################################################################
def configure_firewall(status_gui):
    status_gui.update_status("Configuring Firewall...")
    exec_command("ufw", ["default", "deny", "incoming"], status_gui)
    exec_command("ufw", ["default", "allow", "outgoing"], status_gui)
    exec_command("ufw", ["allow", "out", "80,443/tcp"], status_gui)
    exec_command("ufw", ["allow", "2375/tcp"], status_gui)  # docker
    exec_command("ufw", ["--force", "enable"], status_gui)
    exec_command("ufw", ["reload"], status_gui)

def install_maldetect(status_gui):
    status_gui.update_status("Installing Linux Malware Detect (Maldetect)...")
    try:
        exec_command("apt", ["install", "-y", "maldetect"], status_gui)
        exec_command("maldet", ["-u"], status_gui)
        status_gui.update_status("Maldetect installation and update completed successfully.")
        configure_maldetect(status_gui)
    except subprocess.CalledProcessError as e:
        status_gui.update_status(f"Error installing Maldetect: {e.stderr}")
        print(f"Error installing Maldetect: {e.stderr}")
    except subprocess.TimeoutExpired:
        status_gui.update_status("Command timed out: apt install maldetect or maldet -u")
        print("Command timed out: apt install maldetect or maldet -u")
    except Exception as e:
        status_gui.update_status(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")

def configure_maldetect(status_gui):
    status_gui.update_status("Configuring Maldetect for system-wide monitoring...")
    try:
        # Enable monitoring of all directories
        exec_command("sed", ["-i", "s/^scan_clamscan=.*/scan_clamscan=\"1\"/", "/usr/local/maldetect/conf.maldet"], status_gui)
        exec_command("sed", ["-i", "s/^scan_sigs=.*/scan_sigs=\"1\"/", "/usr/local/maldetect/conf.maldet"], status_gui)
        exec_command("sed", ["-i", "s/^quarantine_hits=.*/quarantine_hits=\"1\"/", "/usr/local/maldetect/conf.maldet"], status_gui)
        exec_command("sed", ["-i", "s/^quarantine_clean=.*/quarantine_clean=\"1\"/", "/usr/local/maldetect/conf.maldet"], status_gui)
        exec_command("sed", ["-i", "s/^email_alert=.*/email_alert=\"1\"/", "/usr/local/maldetect/conf.maldet"], status_gui)
        exec_command("sed", ["-i", "s/^email_addr=.*/email_addr=\"root@localhost\"/", "/usr/local/maldetect/conf.maldet"], status_gui)
        status_gui.update_status("Maldetect configuration completed successfully.")
        
        # Set up a monitoring thread to check for malware detections
        threading.Thread(target=monitor_maldetect, args=(status_gui,)).start()
    except subprocess.CalledProcessError as e:
        status_gui.update_status(f"Error configuring Maldetect: {e.stderr}")
        print(f"Error configuring Maldetect: {e.stderr}")
    except Exception as e:
        status_gui.update_status(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")

def monitor_maldetect(status_gui):
    log_file = "/usr/local/maldetect/event_log"
    try:
        with open(log_file, "r") as f:
            f.seek(0, os.SEEK_END)  # Move to the end of the file
            while True:
                line = f.readline()
                if "malware hit" in line or "malware detected" in line:
                    status_gui.update_status("Malware detected! Check Maldetect logs for details.")
                    show_alert("Malware detected! Check Maldetect logs for details.")
                time.sleep(1)
    except Exception as e:
        status_gui.update_status(f"Error monitoring Maldetect: {str(e)}")
        print(f"Error monitoring Maldetect: {str(e)}")

def show_alert(message):
    root = tk.Tk()
    root.withdraw()  
    messagebox.showwarning("Malware Alert", message)
    root.destroy()
    
def clamvscan(status_gui):
    status_gui.update_status("Running ClamAV scan...")
    try:
        exec_command("clamscan", ["-r", "--bell", "/"], status_gui)
        status_gui.update_status("ClamAV scan completed successfully.")
    except subprocess.CalledProcessError as e:
        status_gui.update_status(f"Error running ClamAV scan: {e.stderr}")
        print(f"Error running ClamAV scan: {e.stderr}")
    except subprocess.TimeoutExpired:
        status_gui.update_status("Command timed out: clamscan -r --bell /")
        print("Command timed out: clamscan -r --bell /")
    except Exception as e:
        status_gui.update_status(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")
        status_gui.update_status("ClamAV scan completed successfully.")
        print("ClamAV scan completed successfully.")
        
def run_rkhunter(status_gui):
    status_gui.update_status("Running RKHunter...")
    try:
        exec_command("rkhunter", ["--check"], status_gui)
        status_gui.update_status("RKHunter completed successfully.")
    except subprocess.CalledProcessError as e:
        status_gui.update_status(f"Error running RKHunter: {e.stderr}")
        print(f"Error running RKHunter: {e.stderr}")
    except subprocess.TimeoutExpired:
        status_gui.update_status("Command timed out: rkhunter --check")
        print("Command timed out: rkhunter --check")
    except Exception as e:
        status_gui.update_status(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")
        status_gui.update_status("RKHunter completed successfully.")
        print("RKHunter completed successfully.")
        
def chkrootkit(status_gui):
    status_gui.update_status("Running chkrootkit...")
    try:
        exec_command("chkrootkit", ["-q"], status_gui)
        status_gui.update_status("chkrootkit completed successfully.")
    except subprocess.CalledProcessError as e:
        status_gui.update_status(f"Error running chkrootkit: {e.stderr}")
        print(f"Error running chkrootkit: {e.stderr}")
    except subprocess.TimeoutExpired:
        status_gui.update_status("Command timed out: chkrootkit -q")
        print("Command timed out: chkrootkit -q")
    except Exception as e:
        status_gui.update_status(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")
        status_gui.update_status("chkrootkit completed successfully.")
        print("chkrootkit completed successfully.")
        
def conigure_debsums(status_gui):
    status_gui.update_status("Configuring debsums...")
    try:
        exec_command("debsums", ["-s"], status_gui)
        status_gui.update_status("debsums configuration completed successfully.")
    except subprocess.CalledProcessError as e:
        status_gui.update_status(f"Error configuring debsums: {e.stderr}")
        print(f"Error configuring debsums: {e.stderr}")
    except subprocess.TimeoutExpired:
        status_gui.update_status("Command timed out: debsums -s")
        print("Command timed out: debsums -s")
    except Exception as e:
        status_gui.update_status(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")
        status_gui.update_status("debsums configuration completed successfully.")
        print("debsums configuration completed successfully.")
        
               
def enable_aide(status_gui):
    status_gui.update_status("Installing and configuring AIDE...")
    exec_command("apt", ["install", "-y", "aide", "aide-common"], status_gui)    
    status_gui.update_status("Initializing AIDE database (this may take a while)...")
    threading.Thread(target=run_aideinit, args=(status_gui,)).start()
    configure_aide_cron(status_gui)

def configure_aide_cron(status_gui):
    status_gui.update_status("Configuring AIDE to run daily...")
    cron_job = "0 0 * * * /usr/bin/aide --check >> /var/log/aide/aide.log 2>&1"
    cron_file = "/etc/cron.d/aide"
    with open(cron_file, "w") as f:
        f.write(cron_job + "\n")
    status_gui.update_status("AIDE daily cron job configured successfully.")

def run_aideinit(status_gui):
    try:
        exec_command("aideinit", [], status_gui)       
        exec_command("mv", ["/var/lib/aide/aide.db.new", "/var/lib/aide/aide.db"], status_gui)
    except subprocess.CalledProcessError as e:
        status_gui.update_status(f"Error executing 'aideinit': {e.stderr}")
        print(f"Error executing 'aideinit': {e.stderr}")
    except subprocess.TimeoutExpired:
        status_gui.update_status("Command timed out: aideinit && mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db")
    except Exception as e:
        status_gui.update_status(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")

def harden_sysctl(status_gui):
    status_gui.update_status("Hardening sysctl settings...")
    exec_command("sysctl", ["-w", "net.ipv4.conf.all.accept_redirects=0"], status_gui)
    exec_command("sysctl", ["-w", "net.ipv4.conf.all.send_redirects=0"], status_gui)
    exec_command("sysctl", ["-w", "net.ipv4.conf.default.accept_redirects=0"], status_gui)
    exec_command("sysctl", ["-w", "net.ipv4.conf.default.send_redirects=0"], status_gui)
    exec_command("sysctl", ["-w", "net.ipv4.icmp_echo_ignore_broadcasts=1"], status_gui)
    exec_command("sysctl", ["-w", "net.ipv4.icmp_ignore_bogus_error_responses=1"], status_gui)
    exec_command("sysctl", ["-w", "net.ipv4.tcp_syncookies=1"], status_gui)
    exec_command("sysctl", ["-w", "net.ipv4.conf.all.rp_filter=1"], status_gui)
    exec_command("sysctl", ["-w", "net.ipv4.conf.default.rp_filter=1"], status_gui)
    exec_command("sysctl", ["-w", "net.ipv4.tcp_timestamps=0"], status_gui)
    exec_command("sysctl", ["-w", "net.ipv4.tcp_max_syn_backlog=2048"], status_gui)
    exec_command("sysctl", ["-w", "net.ipv4.tcp_synack_retries=2"], status_gui)
    exec_command("sysctl", ["-w", "net.ipv4.tcp_syn_retries=5"], status_gui)
    exec_command("sysctl", ["-p"], status_gui)
    status_gui.update_status("Sysctl settings hardened successfully.")

def disable_usb(status_gui):
    def ask_user():
        root = tk.Tk()       
        root.withdraw()  
        result = messagebox.askyesno("Disable USB", "Do you want to disable exterior USB inputs?")
        root.destroy()
        return result

    if ask_user():
        status_gui.update_status("Locking down USB devices...")
        exec_command("sh", ["-c", "echo 'blacklist usb-storage' >> /etc/modprobe.d/usb-storage.conf"], status_gui)        
        exec_command("modprobe", ["-r", "usb-storage"], status_gui)
    else:
        status_gui.update_status("USB lockdown skipped by user.")

def configure_postfix(status_gui):
    status_gui.update_status("Configuring Postfix to hide mail_name...")
    exec_command("postconf", ["-e", "smtpd_banner=$myhostname ESMTP $mail_name"], status_gui)    
    exec_command("postconf", ["-e", "inet_interfaces=loopback-only"], status_gui)
    exec_command("postconf", ["-e", "smtpd_tls_security_level=may"], status_gui)
    exec_command("postconf", ["-e", "smtp_tls_security_level=may"], status_gui)
    exec_command("postconf", ["-e", "smtp_tls_note_starttls_offer=yes"], status_gui)
    exec_command("postconf", ["-e", "smtpd_tls_received_header=yes"], status_gui)
    exec_command("postconf", ["-e", "smtpd_tls_session_cache_timeout=3600s"], status_gui)
    exec_command("postconf", ["-e", "tls_random_source=dev:/dev/urandom"], status_gui)
    exec_command("systemctl", ["restart", "postfix"], status_gui)
    status_gui.update_status("Postfix configured successfully.")

def configure_password_hashing_rounds(status_gui):
    status_gui.update_status("Configuring password hashing rounds...")
    exec_command("sed", ["-i", "s/^ENCRYPT_METHOD.*/ENCRYPT_METHOD MD5/", "/etc/login.defs"], status_gui)    
    exec_command("sed", ["-i", "s/^MD5_CRYPT_MIN_ROUNDS.*/MD5_CRYPT_MIN_ROUNDS 10000/", "/etc/login.defs"], status_gui)
    exec_command("sed", ["-i", "s/^MD5_CRYPT_MAX_ROUNDS.*/MD5_CRYPT_MAX_ROUNDS 10000/", "/etc/login.defs"], status_gui)

def add_legal_banners(status_gui):
    status_gui.update_status("Adding legal banners...")
    with open("/etc/issue", "w") as f:    
        f.write("*******Authorized uses only. All activity is monitored and reported to law enforcement. Unauthorized access will be prosecuted to the fullest extent of the law.*******.\n") 
    with open("/etc/issue.net", "w") as f:
        f.write("*******Authorized uses only. All activity is monitored and reported to law enforcement. Unauthorized access will be prosecuted to the fullest extent of the law.*******.\n")
    with open("/etc/motd", "w") as f:                                                       
        f.write("*******Authorized uses only. All activity is monitored and reported to law enforcement. Unauthorized access will be prosecuted to the fullest extent of the law.*******.\n")

def configure_selinux(status_gui):
    status_gui.update_status("Configuring SELinux...")
    try:    
        exec_command("apt", ["install", "-y", "policycoreutils", "selinux-utils", "selinux-basics"], status_gui)
        exec_command("selinux-config-enforcing", [], status_gui)
        status_gui.update_status("SELinux configured successfully.")
        configure_selinux_policies(status_gui)
        configure_selinux_cron(status_gui)
    except subprocess.CalledProcessError as e:
        status_gui.update_status(f"Error configuring SELinux: {e.stderr}")
        print(f"Error configuring SELinux: {e.stderr}")
    except Exception as e:
        status_gui.update_status(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")

def configure_selinux_policies(status_gui):
    status_gui.update_status("Configuring SELinux policies for HARDN and LEGION files...")
    try:   
        # Allow HARDN and LEGION 
        exec_command("semanage", ["fcontext", "-a", "-t", "bin_t", "/home/tim/Desktop/HARDN(/.*)?"], status_gui)
        exec_command("semanage", ["fcontext", "-a", "-t", "bin_t", "/home/tim/Desktop/LEGION(/.*)?"], status_gui)
        hardn_path = os.path.expanduser("~/Desktop/HARDN")
        legion_path = os.path.expanduser("~/Desktop/LEGION")
        exec_command("restorecon", ["-Rv", hardn_path], status_gui)
        exec_command("restorecon", ["-Rv", legion_path], status_gui)
        
        # Allow to run normally
        for package in ["apparmor", "firejail", "fail2ban", "rkhunter", "aide", "ufw", "postfix", "docker.io"]:
            exec_command("semanage", ["fcontext", "-a", "-t", "bin_t", f"/usr/bin/{package}"], status_gui)  
            exec_command("restorecon", ["-v", f"/usr/bin/{package}"], status_gui)
        
        status_gui.update_status("SELinux policies configured successfully.")
    except subprocess.CalledProcessError as e:
        status_gui.update_status(f"Error configuring SELinux policies: {e.stderr}")
        print(f"Error configuring SELinux policies: {e.stderr}")
    except Exception as e:
        status_gui.update_status(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")

def configure_selinux_cron(status_gui):
    status_gui.update_status("Configuring SELinux weekly audit cron job...")
    cron_job = "0 0 * * 0 /usr/sbin/auditctl -s >> /var/log/selinux_audit.log 2>&1"    
    cron_file = "/etc/cron.d/selinux_audit"
    with open(cron_file, "w") as f:
        f.write(cron_job + "\n")
    status_gui.update_status("SELinux weekly audit cron job configured successfully.")

def configure_docker(status_gui):
    if status_gui:
        status_gui.update_status("Configuring Docker...")
    try:   
        exec_command("apt", ["install", "-y", "docker.io"], status_gui)
        exec_command("systemctl", ["enable", "--now", "docker"], status_gui) 
        exec_command("usermod", ["-aG", "docker", os.getlogin()], status_gui)
        status_gui.update_status("Docker configured successfully.")
        
        status_gui.update_status("Pulling Docker image and setting up Docker Compose...")
        exec_command("docker-compose", ["-f", "/path/to/docker-compose.yml", "up", "-d"], status_gui)
        status_gui.update_status("Docker image pulled and Docker Compose setup completed successfully.")
    except subprocess.CalledProcessError as e:
        status_gui.update_status(f"Error configuring Docker: {e.stderr}")
        print(f"Error configuring Docker: {e.stderr}")
    except Exception as e:
        status_gui.update_status(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")
        
def configure_tcp_wrappers(test_mode=False):
        """Configure TCP Wrappers for access control"""
        print("[+] Configuring TCP Wrappers...")
        hosts_deny = "/etc/hosts.deny"
        hosts_allow = "/etc/hosts.allow"
        
        def backup_file(file_path, test_mode=False):
            """Creates a backup of the specified file."""
            if test_mode:
                print(f"[TEST MODE] Would back up: {file_path}")
            else:
                backup_path = f"{file_path}.bak"
                shutil.copy(file_path, backup_path)
                print(f"Backup created: {backup_path}")
        
        backup_file(hosts_deny, test_mode)
        backup_file(hosts_allow, test_mode)
        
        exec_command("sh", ["-c", "echo 'ALL: ALL' >> /etc/hosts.deny"], None)
        exec_command("sh", ["-c", "echo 'sshd: ALL' >> /etc/hosts.allow"], None)
    

def run_lynis_audit(status_gui):
    status_gui.update_status("Running Lynis security audit...")
    subprocess.run(["lynis", "audit", "system", "--pentest"], stdout=open("/var/log/lynis.log", "a"), stderr=subprocess.STDOUT, check=True)
    try:   
        profile_path = "/etc/lynis/custom.prf"
        command = ["sudo", "lynis", "audit", "system", "--pentest"]
        if os.path.exists(profile_path):
            command.extend(["--profile", profile_path])
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
        
        # Write the output to a CSV file on the user's desktop file on the user's desktop
        user_desktop = os.path.join(os.path.expanduser("~"), "Desktop")
        csv_file_path = os.path.join(user_desktop, "lynis_audit_report.csv")
        with open(csv_file_path, "w") as csv_file:
            for line in output:
                csv_file.write(f"{line}\n")
        
        # Lock down CSV to be -r--r--r--
        os.chmod(csv_file_path, 0o444)
        
        status_gui.update_status(f"Lynis audit report saved to {csv_file_path}")
        print(f"Lynis audit report locked and saved to {csv_file_path}")
        
        lynis_score = None
        for line in output:
            if "Hardening index" in line:    
                status_gui.update_status(f"Lynis score: {line.split(':')[1].strip()}")
                ##############
                ##############
                lynis_score = line.split(":")[1].strip()
                break
        if lynis_score:
            status_gui.update_status(f"Lynis score: {lynis_score}")
            print(f"Lynis score: {lynis_score}")
        else:
            status_gui.update_status("Lynis score not found in output.")
            print("Lynis score not found in output.")
        if status_gui:
            status_gui.complete(lynis_score)
        return lynis_score
    except subprocess.CalledProcessError as e:
        status_gui.update_status(f"Error running Lynis audit: {e.stderr}")
        print(f"Error running Lynis audit: {e.stderr}")
    except Exception as e:
        status_gui.update_status(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")
        
 # CHECK- sssd services for ubunut and Debian alike       
def check_sssd_config(status_gui):
    status_gui.update_status("Checking SSSD configuration...")
    try:
        exec_command("sssd", ["-t"], status_gui)
        status_gui.update_status("SSSD configuration is valid.")
        return True
    except subprocess.CalledProcessError as e:
        status_gui.update_status(f"SSSD configuration error: {e.stderr}")
        print(f"SSSD configuration error: {e.stderr}")
        return False

def fix_sssd_services(status_gui):
    if not check_sssd_config(status_gui):
        status_gui.update_status("Skipping SSSD service fixes due to configuration errors.")
        return

    services = [
        "sssd-nss.service", "sssd-pac.service", "sssd-pam.service",
        "sssd-ssh.service", "sssd-sudo.service", "sssd.service"
    ]
    for service in services:
        try:
            exec_command("systemctl", ["enable", service], status_gui)
            exec_command("systemctl", ["start", service], status_gui)
        except subprocess.CalledProcessError as e:
            status_gui.update_status(f"Error enabling {service}: {e.stderr}")
            print(f"Error enabling {service}: {e.stderr}")

def fix_systemd_services(status_gui):
    services = [
        "switcheroo-control.service",
        "systemd-ask-password-console.service",
        "systemd-ask-password-plymouth.service",
        "systemd-ask-password-wall.service",
        "systemd-bsod.service",
        "systemd-fsckd.service",
        "systemd-initctl.service"
    ]
    for service in services:
        try:
            exec_command("systemctl", ["enable", service], status_gui)
            exec_command("systemctl", ["start", service], status_gui)
        except subprocess.CalledProcessError as e:
            status_gui.update_status(f"Error enabling {service}: {e.stderr}")
            print(f"Error enabling {service}: {e.stderr}")