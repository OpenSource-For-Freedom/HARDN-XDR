# HARDN - Dev branch run file
import os
import subprocess
import threading
import tkinter as tk
from tkinter import ttk

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
        self.total_tasks = 4  # Setup VENV, Setup, Packages, Kernel Security

    def update_status(self, message):
        self.task_count += 1
        self.progress["value"] = (self.task_count / self.total_tasks) * 100
        self.status_text.set(message)
        self.log_text.insert(tk.END, message + "\n")
        self.log_text.see(tk.END)
        self.root.update_idletasks()

    def complete(self):
        self.progress["value"] = 100
        self.status_text.set("Setup complete!")

    def run(self):
        self.root.mainloop()

# Orchestration
def run_setup_venv(gui):
    gui.update_status("Setting up virtual environment...")
    script_dir = os.path.dirname(os.path.abspath(__file__))
    venv_script = os.path.join(script_dir, "../setup/setup_venv.sh")
    if not os.path.exists(venv_script):
        gui.update_status(f"Error: setup_venv.sh not found at {venv_script}")
        return False

    try:
        subprocess.run(["bash", venv_script], check=True)
        gui.update_status("Virtual environment setup complete.")
    except subprocess.CalledProcessError as e:
        gui.update_status(f"Error in setup_venv.sh: {e}")
        return False
    return True

def run_setup(gui):
    gui.update_status("Running setup script...")
    setup_script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../setup/setup.sh")
    try:
        subprocess.run(["bash", setup_script], check=True)
        gui.update_status("Setup script completed.")
    except subprocess.CalledProcessError as e:
        gui.update_status(f"Error in setup.sh: {e}")
        return False
    return True

def run_packages(gui):
    gui.update_status("Installing packages...")
    packages_script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../setup/packages.sh")
    try:
        subprocess.run(["bash", packages_script], check=True)
        gui.update_status("Packages installed successfully.")
    except subprocess.CalledProcessError as e:
        gui.update_status(f"Error in packages.sh: {e}")
        return False
    return True

def run_kernel_security(gui):
    gui.update_status("Running kernel security audit...")
    script_dir = os.path.dirname(os.path.abspath(__file__))
    kernal_executable = os.path.join(script_dir, "../setup/kernal")

    # Check if the compiled Rust executable exists
    if not os.path.exists(kernal_executable):
        gui.update_status(f"Error: kernal executable not found at {kernal_executable}")
        return False

    # Make sure rs file has chmod
    try:
        subprocess.run(["chmod", "+x", kernal_executable], check=True)
        gui.update_status("Ensured kernal executable is executable.")
    except subprocess.CalledProcessError as e:
        gui.update_status(f"Error setting executable permissions for kernal: {e}")
        return False

    # Run rs
    try:
        result = subprocess.run([kernal_executable], check=True, capture_output=True, text=True)
        gui.update_status("Kernel security audit completed.")
        gui.log_text.insert(tk.END, result.stdout + "\n")
    except subprocess.CalledProcessError as e:
        gui.update_status(f"Error in kernel security audit: {e}")
        gui.log_text.insert(tk.END, e.stderr + "\n")
        return False

    return True

def start_hardening():
    gui = StatusGUI()

    def run_tasks():
        # 1 venv
        if not run_setup_venv(gui):
            return

        # 2 setup
        if not run_setup(gui):
            return

        # 3 packages
        if not run_packages(gui):
            return

        # 3 kernal
        if not run_kernel_security(gui):
            return

        # Complete setup
        gui.complete()

    threading.Thread(target=run_tasks, daemon=True).start()
    gui.run()

# MAIN
def main():
    start_hardening()

if __name__ == "__main__":
    main()
