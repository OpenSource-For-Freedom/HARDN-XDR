import os
import subprocess
import sys


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

def configure_grub_security():
        results = []
        results.append("Configuring GRUB security settings...")

        grub_config_path = '/etc/default/grub'
        if os.path.exists(grub_config_path):
            try:
                with open(grub_config_path, 'a') as grub_file:
                    grub_file.write('\n# Security enhancements\n')
                    grub_file.write('GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX kvm-intel.vmentry_l1d_flush=always"\n')
                    grub_file.write('GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX random.trust_bootloader=off"\n')
                    grub_file.write('GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX slab_nomerge"\n')
                    grub_file.write('GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX page_alloc.shuffle=1"\n')
                    grub_file.write('GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX randomize_kstack_offset=on"\n')
                    grub_file.write('GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX efi=disable_early_pci_dma"\n')
                    grub_file.write('GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX random.trust_cpu=off"\n')
                    grub_file.write('GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX debugfs=off"\n')
                    grub_file.write('GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX init_on_alloc=1 init_on_free=1"\n')
                    grub_file.write('GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX pti=on"\n')
                    grub_file.write('GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX vsyscall=none"\n')
                    grub_file.write('GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX loglevel=0 acpi_no_watchdog nohz_full=all nohibernate ssbd=force-on topology=on thermal.off=1 noearly ioapicreroute pcie_bus_perf rcu_nocb_poll mce=off nohpet idle=poll numa=noacpi gather_data_sampling=force net.ifnames=0 ipv6.disable=1 hibernate=no"\n')
                    
                results.append("GRUB configuration updated with security settings.")
                # Update GRUB configuration
                subprocess.run(['sudo', 'update-grub'], check=True)     
                    
                results.append("GRUB configuration updated successfully.")
            except Exception as e:
                results.append(f"Error updating GRUB configuration: {e}")
        else:
            results.append(f"GRUB configuration file not found at {grub_config_path}.")
        
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
    report.extend(configure_grub_security())
    report.append("Kernel security audit completed.")
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
