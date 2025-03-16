# HARDN - Security Hardening for Debian-based Systems
import os
import sys
import subprocess
import threading
import tkinter as tk
from tkinter import ttk
from packages import (
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
        self.total_tasks = 21  # Updated to include Docker configuration and fixes

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
        self.add_dark_button()

    def add_dark_button(self):
        self.dark_button = ttk.Button(self.root, text="Call DARK", command=self.call_dark, style="TButton")
        self.dark_button_window = self.canvas.create_window(400, 620, window=self.dark_button)

    def call_dark(self):
        self.update_status("Running HARDN DARK...")
        subprocess.run(["python3", "src/hardn_dark.py"], check=True)
        self.update_status("HARDN DARK completed.")

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
        self.root.quit()  # Exit the main loop to continue the script

# START HARDENING PROCESS
def start_hardening(dark_mode=False):
    def run_tasks():
        check_and_install_dependencies(status_gui)
        exec_command("apt", ["update"], status_gui)
        exec_command("apt", ["upgrade", "-y"], status_gui)
        enforce_password_policies(status_gui)
        exec_command("apt", ["install", "-y", "fail2ban"], status_gui)
        exec_command("systemctl", ["enable", "--now", "fail2ban"], status_gui)
        configure_firewall(status_gui)
        exec_command("apt", ["install", "-y", "rkhunter"], status_gui)
        exec_command("rkhunter", ["--update"], status_gui)
        exec_command("rkhunter", ["--propupd"], status_gui)
        install_maldetect(status_gui)
        exec_command("apt", ["install", "-y", "libpam-pwquality"], status_gui)
        enable_aide(status_gui)
        harden_sysctl(status_gui)
        disable_usb(status_gui)
        exec_command("apt", ["install", "-y", "apparmor", "apparmor-profiles", "apparmor-utils"], status_gui)
        exec_command("systemctl", ["enable", "--now", "apparmor"], status_gui)
        configure_postfix(status_gui)
        exec_command("apt", ["autoremove", "-y"], status_gui)  
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
            subprocess.run(["python3", "src/hardn_dark.py"], check=True)
            status_gui.update_status("HARDN DARK completed.")
        
        # Call kernal-py 
        status_gui.update_status("Running kernalpy for kernel-focused security...")
        subprocess.run(["python3", "src/kernalpy.py"], check=True)
        status_gui.update_status("Kernel-focused security completed.")
    
    threading.Thread(target=run_tasks, daemon=True).start()

# MAIN
def main():
    import argparse
    parser = argparse.ArgumentParser(description="HARDN - Security Hardening for Debian-based Systems")
    parser.add_argument("--dark", action="store_true", help="Run HARDN DARK for deep security hardening")
    args = parser.parse_args()

    global status_gui  # global
    status_gui = StatusGUI()  
    status_gui.root.after(100, lambda: start_hardening(dark_mode=args.dark))
    status_gui.run()

if __name__ == "__main__":
    main()