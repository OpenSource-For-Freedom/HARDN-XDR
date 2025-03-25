# HARDN - Security Hardening for Debian-based Systems
import os
import sys
import subprocess
import threading
import tkinter as tk
from tkinter import ttk
from docker.packages import (
    exec_command, print_ascii_art, check_and_install_dependencies,
    enforce_password_policies, configure_firewall, install_maldetect,
    enable_aide, harden_sysctl, disable_usb, configure_postfix,
    configure_password_hashing_rounds, add_legal_banners,
    run_lynis_audit, configure_selinux, configure_docker,
    fix_sssd_services, fix_systemd_services
)

# Add the current directory to the Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

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
        self.total_tasks = 18  # Updated to include Docker configuration and GRUB password

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

    def complete(self, lynis_score=None):
        self.progress["value"] = 100
        if lynis_score:
            self.status_text.set(f"Hardening complete! Lynis score: {lynis_score}")
        else:
            self.status_text.set("Hardening complete!")
        self.log_text.insert(tk.END, f"Lynis score: {lynis_score}\n")
        self.log_text.see(tk.END)
        self.add_dark_button()  # Add the button for HARDN DARK

    def add_dark_button(self):
        self.dark_button = ttk.Button(self.root, text="Run HARDN DARK", command=self.call_dark, style="TButton")
        self.dark_button_window = self.canvas.create_window(400, 620, window=self.dark_button)

    def call_dark(self):
        self.update_status("Running HARDN DARK...")
        dark_script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../dark/hardn_dark.py")
        try:
            subprocess.run(["python3", dark_script], check=True)
            self.update_status("HARDN DARK completed.")
        except subprocess.CalledProcessError as e:
            self.update_status(f"Error running HARDN DARK: {e}")

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

        self.submit_button = ttk.Button(self.password_window, text="Submit", command=self.submit_password, style="TButton")
        self.submit_button.pack(pady=10)

    def submit_password(self):
        self.grub_password = self.password_entry.get()
        self.password_window.destroy()
        self.update_status("GRUB password received.")

# START HARDENING PROCESS
def start_hardening(dark_mode=False):
    status_gui = StatusGUI()  # Create an instance of StatusGUI

    def run_tasks():
        # Get the absolute path to the packages.sh script
        script_dir = os.path.dirname(os.path.abspath(__file__))
        packages_script = os.path.join(script_dir, "setup", "packages.sh")
        print(f"Resolved path to packages.sh: {packages_script}")  # Debug

        # Check if packages.sh exists
        if not os.path.exists(packages_script):
            status_gui.update_status(f"Error: packages.sh not found at {packages_script}")
            return

        # Run packages.sh for initial setup
        status_gui.update_status("STARTING HARDN...")
        try:
            subprocess.run(["bash", packages_script], check=True)
            status_gui.update_status("packages.sh completed.")
        except subprocess.CalledProcessError as e:
            status_gui.update_status(f"Error running packages.sh: {e}")
            return

        # Prompt for GRUB password
        status_gui.update_status("Prompting for GRUB password...")
        status_gui.get_grub_password()

        # Install Python dependencies
        status_gui.update_status("Installing Python dependencies...")
        requirements_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../setup/requirements.txt")
        subprocess.run(["pip3", "install", "-r", requirements_path], check=True)
        status_gui.update_status("Python dependencies installed.")

        # Run hardening tasks
        status_gui.update_status("Starting hardening tasks...")
        check_and_install_dependencies(status_gui)
        exec_command("apt", ["update"], status_gui)
        exec_command("apt", ["upgrade", "-y"], status_gui)
        enforce_password_policies(status_gui)
        configure_firewall(status_gui)
        install_maldetect(status_gui)
        enable_aide(status_gui)
        harden_sysctl(status_gui)
        disable_usb(status_gui)
        configure_postfix(status_gui)
        configure_password_hashing_rounds(status_gui)
        add_legal_banners(status_gui)
        configure_selinux(status_gui)
        configure_docker(status_gui)
        fix_sssd_services(status_gui)
        fix_systemd_services(status_gui)
        lynis_score = run_lynis_audit(status_gui)
        status_gui.complete(lynis_score)

        if dark_mode:
            status_gui.update_status("Running HARDN DARK...")
            dark_script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../dark/hardn_dark.py")
            subprocess.run(["python3", dark_script], check=True)
            status_gui.update_status("HARDN DARK completed.")

    threading.Thread(target=run_tasks, daemon=True).start()
    status_gui.run()

# Build and run Docker container
def setup_docker():
    print("Building Docker image...")
    subprocess.run(["docker", "build", "-t", "hardn_image", "."], check=True)
    print("Starting Docker container...")
    subprocess.run(["docker-compose", "up", "-d"], check=True)
    print("Docker container is running.")

# MAIN
def main():
    import argparse
    parser = argparse.ArgumentParser(description="HARDN - Security Hardening for Debian-based Systems")
    parser.add_argument("--dark", action="store_true", help="Run HARDN DARK for deep security hardening")
    args = parser.parse_args()

    try:
        start_hardening(dark_mode=args.dark)
    except KeyboardInterrupt:
        print("\nScript interrupted by user. Exiting...")

if __name__ == "__main__":
    main()