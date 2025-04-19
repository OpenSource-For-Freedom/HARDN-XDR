#!/usr/bin/env python3
import os
import sys
import subprocess
import argparse
import toml
from gui.main import launch_gui  

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

CONFIG_PATH = "config/config.toml"

def validate_environment():
    if os.geteuid() != 0:
        print("[!] This script must be run as root. Use 'sudo'.")
        sys.exit(1)
    print("[+] Root access confirmed.")

def load_config(config_path):
    try:
        with open(config_path, "r") as f:
            config = toml.load(f)
            print(f"[+] Loaded configuration from {config_path}")
            return config
    except FileNotFoundError:
        print(f"[!] Config file not found at {config_path}. Continuing with defaults.")
        return {}

def set_executable_permissions():
    files_to_chmod = [
        "src/setup/setup.sh",
        "src/setup/packages.sh",
        "src/kernel.rs"
    ]

    for root, _, files in os.walk("src/gui"):
        for file in files:
            files_to_chmod.append(os.path.join(root, file))

    for file in files_to_chmod:
        if os.path.exists(file):
            os.chmod(file, 0o755)
            print(f"[+] Set exec permission: {file}")
        else:
            print(f"[-] Missing: {file}")

def run_script(script_name):
    try:
        print(f"[~] Running {script_name}...")
        subprocess.check_call(["/bin/bash", script_name])
        print(f"[+] {script_name} completed.")
    except subprocess.CalledProcessError as e:
        print(f"[!] Error running {script_name}: {e}")
        sys.exit(1)

def run_kernel():
    try:
        print("[~] Running kernel.rs...")
        subprocess.check_call(["cargo", "run", "--bin", "kernel"], cwd="src")
        print("[+] Kernel hardened.")
    except subprocess.CalledProcessError as e:
        print(f"[!] Kernel hardening failed: {e}")
        sys.exit(1)

def manage_service(action):
    try:
        print(f"[~] {action.capitalize()}ing hardn.service...")
        subprocess.check_call(["systemctl", action, "hardn.service"])
        print(f"[+] hardn.service {action}ed.")
    except subprocess.CalledProcessError:
        print(f"[!] Could not {action} hardn.service (might not exist).")

def parse_args():
    parser = argparse.ArgumentParser(description="HARDN Orchestration Controller")
    parser.add_argument("--headless", action="store_true", help="Run without GUI")
    parser.add_argument("--setup-only", action="store_true", help="Only run setup scripts")
    parser.add_argument("--kernel-only", action="store_true", help="Only run kernel hardening")
    parser.add_argument("--no-service", action="store_true", help="Don't manage hardn.service")
    parser.add_argument("--config", type=str, default=CONFIG_PATH, help="Path to TOML config")
    return parser.parse_args()

def main():
    args = parse_args()
    config = load_config(args.config)
    validate_environment()
    set_executable_permissions()

    if not args.no_service:
        manage_service("stop")

    if args.setup_only:
        run_script("src/setup/packages.sh")
        run_script("src/setup/setup.sh")
    elif args.kernel_only:
        run_kernel()
    else:
        run_script("src/setup/packages.sh")
        run_script("src/setup/setup.sh")
        run_kernel()

    if not args.no_service:
        manage_service("start")

    if not args.headless:
        launch_gui()

if __name__ == "__main__":
    main()