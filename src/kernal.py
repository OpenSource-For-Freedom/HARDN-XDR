import os
import subprocess

def check_kernel_version():
    kernel_version = subprocess.check_output(['uname', '-r']).decode().strip()
    return f"Current kernel version: {kernel_version}"

def audit_kernel_security():
    results = []
    results.append("Auditing kernel security settings...")

    try:
        selinux_status = subprocess.check_output(['sestatus']).decode().strip()
        results.append(f"SELinux status: {selinux_status}")
    except FileNotFoundError:
        results.append("SELinux is not installed.")

    try:
        apparmor_status = subprocess.check_output(['aa-status'], stderr=subprocess.STDOUT).decode().strip()
        results.append(f"AppArmor Status:\n{apparmor_status}")
    except subprocess.CalledProcessError as e:
        if e.returncode == 4:
            results.append("Error: Insufficient privileges to read AppArmor status. Run the script with elevated privileges (e.g., using sudo).")
        else:
            results.append(f"Error: Failed to check AppArmor status. Command output:\n{e.output.decode().strip()}")
    except FileNotFoundError:
        results.append("Error: The 'aa-status' command is not available. Ensure AppArmor is installed.")

    return results

def kernal_security():
    results = []
    results.append("Checking kernel security...")

    try:
        modules = subprocess.check_output(['lsmod']).decode().strip()
        results.append(f"Loaded kernel modules:\n{modules}")
    except Exception as e:
        results.append(f"Error checking kernel modules: {e}")

    try:
        sysctl_output = subprocess.check_output(['sysctl', '-a']).decode().strip()
        results.append(f"Kernel parameters:\n{sysctl_output}")
    except Exception as e:
        results.append(f"Error checking kernel parameters: {e}")

    kernel_version = subprocess.check_output(['uname', '-r']).decode().strip()
    if kernel_version.startswith('5.'):
        results.append("Kernel version is up to date.")
    else:
        results.append("Kernel version is not up to date. Please update it for security.")

    try:
        with open('/proc/sys/kernel/randomize_va_space') as f:
            aslr_status = f.read().strip()
        if aslr_status == '2':
            results.append("Kernel ASLR is enabled.")
        else:
            results.append("Kernel ASLR is not enabled. Please enable it for security.")
    except Exception as e:
        results.append(f"Error checking ASLR status: {e}")

    return results

def grub_password():
    results = []
    results.append("Checking GRUB password...")
    grub_cfg = '/etc/grub.d/40_custom'
    if os.path.exists(grub_cfg):
        with open(grub_cfg, 'r') as file:
            content = file.read()
            if 'password' in content:
                results.append("GRUB password is set.")
            else:
                results.append("GRUB password is not set. Please set it for security.")
    else:
        results.append(f"{grub_cfg} does not exist.")
    return results

def generate_report():
    report = []
    report.append(check_kernel_version())
    report.extend(audit_kernel_security())
    report.extend(kernal_security())
    report.extend(grub_password())
    return "\n".join(report)

def main():
    report = generate_report()
    # Assuming HARDN GUI has a method to display text
    try:
        try:
            from hardn_gui import display_report  # Replace with actual GUI integration
            display_report(report)
        except ModuleNotFoundError:
            print("HARDN GUI module not found. Printing report to console:")
            print(report)
    except ImportError:
        print("HARDN GUI not found. Printing report to console:")
        print(report)

if __name__ == "__main__":
    main()
