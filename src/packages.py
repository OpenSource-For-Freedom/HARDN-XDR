import os
import sys
import subprocess
import shutil
import threading
import pexpect

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
    dependencies = [
        "apparmor", "apparmor-profiles", "apparmor-utils", "firejail", "libpam-pwquality",
        "tcpd", "fail2ban", "rkhunter", "aide", "aide-common", "ufw", "postfix", "debsums", "python3-pexpect", "python3-tk", "policycoreutils", "selinux-utils", "selinux-basics", "docker.io"
    ]
    
    for package in dependencies:
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

def enforce_password_policies(status_gui):
    exec_command("apt", ["install", "-y", "libpam-pwquality"], status_gui)
    exec_command("sh", ["-c", "echo 'password requisite pam_pwquality.so retry=3 minlen=12 difok=3' >> /etc/pam.d/common-password"], status_gui)

def configure_firewall(status_gui):
    status_gui.update_status("Configuring Firewall...")
    exec_command("ufw", ["default", "deny", "incoming"], status_gui)
    exec_command("ufw", ["default", "allow", "outgoing"], status_gui)
    exec_command("ufw", ["allow", "out", "80,443/tcp"], status_gui)
    exec_command("ufw", ["--force", "enable"], status_gui)
    exec_command("ufw", ["reload"], status_gui)

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

def enable_aide(status_gui):
    status_gui.update_status("Installing and configuring AIDE...")
    exec_command("apt", ["install", "-y", "aide", "aide-common"], status_gui)
    status_gui.update_status("Initializing AIDE database (this may take a while)...")
    threading.Thread(target=run_aideinit, args=(status_gui,)).start()

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
    exec_command("sysctl", ["-w", "net.ipv4.conf.all.accept_redirects=0"], status_gui)
    exec_command("sysctl", ["-w", "net.ipv4.conf.all.send_redirects=0"], status_gui)

def disable_usb(status_gui):
    status_gui.update_status("Locking down USB devices...")
    exec_command("sh", ["-c", "echo 'blacklist usb-storage' >> /etc/modprobe.d/usb-storage.conf"], status_gui)
    exec_command("modprobe", ["-r", "usb-storage"], status_gui)

def configure_postfix(status_gui):
    status_gui.update_status("Configuring Postfix to hide mail_name...")
    exec_command("postconf", ["-e", "smtpd_banner=$myhostname ESMTP $mail_name"], status_gui)
    exec_command("systemctl", ["restart", "postfix"], status_gui)

def configure_password_hashing_rounds(status_gui):
    status_gui.update_status("Configuring password hashing rounds...")
    exec_command("sed", ["-i", "s/^ENCRYPT_METHOD.*/ENCRYPT_METHOD SHA512/", "/etc/login.defs"], status_gui)
    exec_command("sed", ["-i", "s/^SHA_CRYPT_MIN_ROUNDS.*/SHA_CRYPT_MIN_ROUNDS 5000/", "/etc/login.defs"], status_gui)
    exec_command("sed", ["-i", "s/^SHA_CRYPT_MAX_ROUNDS.*/SHA_CRYPT_MAX_ROUNDS 5000/", "/etc/login.defs"], status_gui)

def add_legal_banners(status_gui):
    status_gui.update_status("Adding legal banners...")
    with open("/etc/issue", "w") as f:
        f.write("Authorized uses only. All activity may be monitored and reported.\n")
    with open("/etc/issue.net", "w") as f:
        f.write("Authorized uses only. All activity may be monitored and reported.\n")
    with open("/etc/motd", "w") as f:                                                       
        f.write("Authorized uses only. All activity may be monitored and reported.\n")

def configure_selinux(status_gui):
    status_gui.update_status("Configuring SELinux...")
    try:
        exec_command("apt", ["install", "-y", "policycoreutils", "selinux-utils", "selinux-basics"], status_gui)
        exec_command("selinux-activate", [], status_gui)
        exec_command("selinux-config-enforcing", [], status_gui)
        status_gui.update_status("SELinux configured successfully.")
    except subprocess.CalledProcessError as e:
        status_gui.update_status(f"Error configuring SELinux: {e.stderr}")
        print(f"Error configuring SELinux: {e.stderr}")
    except Exception as e:
        status_gui.update_status(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")

def configure_docker(status_gui):
    status_gui.update_status("Configuring Docker...")
    try:
        exec_command("apt", ["install", "-y", "docker.io"], status_gui)
        exec_command("systemctl", ["enable", "--now", "docker"], status_gui)
        exec_command("usermod", ["-aG", "docker", os.getlogin()], status_gui)
        status_gui.update_status("Docker configured successfully.")
    except subprocess.CalledProcessError as e:
        status_gui.update_status(f"Error configuring Docker: {e.stderr}")
        print(f"Error configuring Docker: {e.stderr}")
    except Exception as e:
        status_gui.update_status(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")

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
        return lynis_score
    except subprocess.CalledProcessError as e:
        status_gui.update_status(f"Error running Lynis audit: {e.stderr}")
        print(f"Error running Lynis audit: {e.stderr}")
    except Exception as e:
        status_gui.update_status(f"Unexpected error: {str(e)}")
        print(f"Unexpected error: {str(e)}")