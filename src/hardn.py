import os
import sys
import subprocess
from src.gui.main import launch_gui  # Import GUI >>> from src/gui/main.py

def validate_environment():
    if os.geteuid() != 0:
        print("This script must be run as root. Please use 'sudo'.")
        sys.exit(1)
    print("Environment validated successfully.")

def set_executable_permissions():
    files_to_chmod = [
        "setup/setup.sh",
        "setup/packages.sh",
        "src/kernel.rs",
    ]

    # Add all files in src/gui to the list[]
    gui_dir = "src/gui"
    for root, _, files in os.walk(gui_dir):
        for file in files:
            files_to_chmod.append(os.path.join(root, file))

    try:
        for file in files_to_chmod:
            print(f"Setting executable permissions for {file}...")
            subprocess.check_call(["chmod", "+x", file])
        print("All required files are now executable.")
    except subprocess.CalledProcessError as e:
        print(f"Error setting executable permissions: {e}")
        sys.exit(1)

def run_script(script_name):
    try:
        print(f"Running {script_name}...")
        subprocess.check_call(["/bin/bash", script_name])
        print(f"{script_name} executed successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Error running {script_name}: {e}")
        sys.exit(1)

def run_kernel():
    try:
        print("Running kernel hardening (kernel.rs)...")
        subprocess.check_call(["cargo", "run", "--bin", "kernel"], cwd="src")
        print("Kernel hardening completed successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Error running kernel.rs: {e}")
        sys.exit(1)

def main():
    validate_environment()
    set_executable_permissions()  # Ensure all required files are executable
    launch_gui()  # Launch the GUI
    run_script("setup/setup.sh")  # Run setup.sh
    run_script("setup/packages.sh")  # Run packages.sh
    run_kernel()  # Run kernel.rs

if __name__ == "__main__":
    main()