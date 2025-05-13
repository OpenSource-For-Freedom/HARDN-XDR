#!/usr/bin/env python3

"""
HARDN Backend Socket
This implements a real backend socket to handle requests from the GUI proxy.
This provides limited functionality, but is enough to get the GUI working.
"""

import socket
import os
import sys
import json
import threading
import time
import subprocess
from pathlib import Path

SOCKET_PATH = '/tmp/hardn.sock'
BASE_DIR = Path(__file__).resolve().parent.parent

# Setup script paths
SETUP_SCRIPT = BASE_DIR / "src" / "setup" / "setup.sh"
PACKAGES_SCRIPT = BASE_DIR / "src" / "setup" / "packages.sh"

def is_running_in_vm():
    """
    Detect if running in a virtual machine environment.
    Returns True if VM detected, False otherwise.
    """
    # Method 1: Check /proc/cpuinfo for hypervisor flags
    try:
        with open('/proc/cpuinfo', 'r') as f:
            cpuinfo = f.read().lower()
            if any(x in cpuinfo for x in ['hypervisor', 'vmware', 'virtualbox', 'kvm', 'xen']):
                return True
    except Exception:
        pass
    
    # Method 2: Check dmesg for VM indicators
    try:
        result = subprocess.run(['dmesg'], capture_output=True, text=True)
        if result.returncode == 0:
            dmesg_output = result.stdout.lower()
            if any(x in dmesg_output for x in ['vmware', 'virtualbox', 'hypervisor', 'virtual machine']):
                return True
    except Exception:
       pass

    return False

IS_VM_ENVIRONMENT = is_running_in_vm()

class SetupActions:
    get_system_status = None

    @classmethod
    def _get_status_with_vm_context(cls, param, param1, is_vm):
        """
        Return the status message with VM awareness
        """
        if is_vm:
            return f"VM detected: {param}"
        else:
            return f"{param} ({param1})"

    def _create_status_response(path, exists, permissions, status, message):
        """Helper to create a standardized status response"""
        return {
            "path": path,
            "exists": exists,
            "permissions": permissions,
            "status": status,
            "message": message
        }

    @staticmethod
    def _get_status_with_vm_context(base_status, base_message, is_vm):
        """Helper to get status and message with VM context"""
        status = "warning" if is_vm else "error"
        vm_suffix = " (acceptable in VM)" if is_vm else ""
        return status, f"{base_message}{vm_suffix}"

    @staticmethod
    def _get_file_status(path, expected_perms, is_vm):
        """Helper to check a file's permissions and return its status"""
        try:
            # Check if file exists
            if not Path(path).exists():
                status, message = SetupActions._get_status_with_vm_context(
                    "error", "File not found", is_vm
                )
                return SetupActions._create_status_response(
                    path, False, None, status, message
                )
                
            # Check if we can get permissions
            result = subprocess.run(['stat', '-c', '%a', path], capture_output=True, text=True)
            if result.returncode != 0:
                status, message = SetupActions._get_status_with_vm_context(
                    "error", "Could not check permissions", is_vm
                )
                return SetupActions._create_status_response(
                    path, True, None, status, message
                )
                
            # Check if permissions match expected
            perms = result.stdout.strip()
            if perms == expected_perms:
                return SetupActions._create_status_response(
                    path, True, perms, "ok", "Permissions are secure"
                )
            else:
                status, message = SetupActions._get_status_with_vm_context(
                    "error", f"Permissions are not secure: {perms}", is_vm
                )
                return SetupActions._create_status_response(
                    path, True, perms, status, message
                )
                
        except Exception as e:
            return SetupActions._create_status_response(
                path, None, None, "error", f"Error checking permissions: {str(e)}"
            )

def get_system_status():
        """Get the system security status with VM awareness"""
        status = {
            "selinux": SetupActions._check_selinux(),
            "firewall": SetupActions._check_firewall(),
            "apparmor": SetupActions._check_apparmor(),
            "permissions": SetupActions._check_permissions(),
            "environment": "virtual_machine" if IS_VM_ENVIRONMENT else "physical_machine"
        }
        
        # Add system checks status
        if all(v.get("status") == "ok" for k, v in status.items() if k != "environment"):
            status["overall"] = {
                "status": "ok",
                "message": "All security components are properly configured"
            }
        else:
            status["overall"] = {
                "status": "warning" if IS_VM_ENVIRONMENT else "error",
                "message": "Some security components need attention" if IS_VM_ENVIRONMENT 
                          else "Security components are not properly configured"
            }
            
        return status
    
def _get_status_message(status_type, is_vm=False):
    """Helper to get consistent status messages"""
    messages = {
        "not_detected": ("SELinux not detected", "SELinux not detected, but acceptable in VM environment"),
        "permissive": ("SELinux is in permissive mode", "SELinux is in permissive mode (acceptable in VM)"),
        "disabled": ("SELinux is disabled", "SELinux is disabled (acceptable in VM)"),
        "not_installed": ("SELinux tools not installed", "SELinux tools not installed (acceptable in VM)")
    }
    return messages[status_type][1 if is_vm else 0]

def _get_status_level(status_type, is_vm=False):
    """Helper to determine status level based on condition and environment"""
    if status_type == "enforcing":
        return "ok"
    if status_type in ["not_detected", "disabled"]:
        return "warning" if is_vm else "error"
    return "warning"  # permissive mode is always a warning

def _check_selinux():
    """Check SELinux status with VM awareness"""
    try:
        result = subprocess.run(['getenforce'], capture_output=True, text=True)
        
        if result.returncode != 0:
            status_type = "not_detected"
        else:
            selinux_status = result.stdout.strip()
            if selinux_status == "Enforcing":
                return {
                    "status": "ok",
                    "message": "SELinux is enforcing",
                    "enforced": True
                }
            elif selinux_status == "Permissive":
                status_type = "permissive"
            else:
                status_type = "disabled"
                
        # Handle all non-enforcing cases
        return {
            "status": SetupActions._get_status_level(status_type, IS_VM_ENVIRONMENT),
            "message": SetupActions._get_status_message(status_type, IS_VM_ENVIRONMENT),
            "enforced": False
        }
            
    except FileNotFoundError:
        status_type = "not_installed"
        return {
            "status": SetupActions._get_status_level(status_type, IS_VM_ENVIRONMENT),
            "message": SetupActions._get_status_message(status_type, IS_VM_ENVIRONMENT),
            "enforced": False
        }
    except Exception as e:
        return {
            "status": "error",
            "message": f"Error checking SELinux: {str(e)}",
            "enforced": False
        }


def _check_firewall():
        """Check firewall status with VM awareness"""
        try:
            result = subprocess.run(['systemctl', 'is-active', 'firewalld'], capture_output=True, text=True)
            if result.stdout.strip() == "active":
                return {
                    "status": "ok",
                    "message": "Firewall is active",
                    "active": True
                }
            else:
                if IS_VM_ENVIRONMENT:
                    return {
                        "status": "warning",
                        "message": "Firewall is not active (acceptable in VM)",
                        "active": False
                    }
                else:
                    return {
                        "status": "error",
                        "message": "Firewall is not active",
                        "active": False
                    }
        except Exception as e:
            if IS_VM_ENVIRONMENT:
                return {
                    "status": "warning",
                    "message": f"Error checking firewall (acceptable in VM): {str(e)}",
                    "active": False
                }
            else:
                return {
                    "status": "error",
                    "message": f"Error checking firewall: {str(e)}",
                    "active": False
                }


def _get_apparmor_status(result, is_vm):
        """Helper to determine AppArmor status and message based on command result"""
        if result.returncode == 0:
            if "profiles are loaded" in result.stdout:
                return {
                    "status": "ok",
                    "message": "AppArmor is active with profiles loaded",
                    "active": True
                }
            else:
                status = "warning"
                message = "AppArmor is active but no profiles loaded"
                if is_vm:
                    message += " (acceptable in VM)"
                return {
                    "status": status,
                    "message": message,
                    "active": True
                }
        else:
            status = "warning" if is_vm else "error"
            message = "AppArmor is not active"
            if is_vm:
                message += " (acceptable in VM)"
            return {
                "status": status,
                "message": message,
                "active": False
            }


def _get_apparmor_not_found_status(is_vm):
        """Helper to create status when AppArmor tools are not found"""
        status = "warning" if is_vm else "error"
        message = "AppArmor tools not installed"
        if is_vm:
            message += " (acceptable in VM)"
        return {
            "status": status,
            "message": message,
            "active": False
        }


def _check_apparmor():
        """Check AppArmor status with VM awareness"""
        try:
            result = subprocess.run(['aa-status'], capture_output=True, text=True)
            return SetupActions._get_apparmor_status(result, IS_VM_ENVIRONMENT)
        except FileNotFoundError:
            return SetupActions._get_apparmor_not_found_status(IS_VM_ENVIRONMENT)
        except Exception as e:
            return {
                "status": "error", 
                "message": f"Error checking AppArmor: {str(e)}", 
                "active": False
            }

def check_cpuinfo_for_vm():
        """Check CPU info for VM indicators"""
        try:
            with open('/proc/cpuinfo', 'r') as f:
                cpuinfo = f.read().lower()
                return any(x in cpuinfo for x in ['hypervisor', 'vmware', 'virtualbox', 'kvm', 'xen'])
        except:
            return False


def check_dmesg_for_vm():
        """Check dmesg output for VM indicators"""
        try:
            result = subprocess.run(['dmesg'], capture_output=True, text=True)
            if result.returncode == 0:
                output = result.stdout.lower()
                return any(x in output for x in ['vmware', 'virtualbox', 'hypervisor', 'virtual machine'])
            return False
        except:
            return False


def check_directories_for_vm():
        """Check for VM-specific directories"""
        vm_dirs = ['/sys/devices/virtual/dmi/id/product_name', '/sys/hypervisor/type']
        for vm_dir in vm_dirs:
            if os.path.exists(vm_dir):
                try:
                    with open(vm_dir, 'r') as f:
                        content = f.read().lower()
                        if any(x in content for x in ['vmware', 'virtualbox', 'qemu', 'kvm', 'xen']):
                            return True
                except FileNotFoundError:
                    pass
        return False


# Sample data for network, threats, and logs
SAMPLE_DATA = {
    'network': [
        {'ip': '192.168.1.1', 'port': 80},
        {'ip': '10.0.0.5', 'port': 443},
        {'ip': '172.16.0.10', 'port': 22},
        {'ip': '192.168.1.100', 'port': 8080}
    ],
    'threats': {
        'level': 2,
        'items': [
            {'id': 1, 'description': 'Suspicious login attempt', 'level': 3},
            {'id': 2, 'description': 'Port scan detected', 'level': 2},
            {'id': 3, 'description': 'Unusual outbound traffic', 'level': 1}
        ]
    },
    'logs': [
        '2025-04-28 09:00:00 - System startup',
        '2025-04-28 09:05:23 - User login: admin',
        '2025-04-28 09:10:15 - Security scan initiated',
        '2025-04-28 09:15:42 - Firewall rule updated',
        '2025-04-28 09:18:30 - Network scan complete'
    ],
    'status': {
        'status': 'online', 
        'version': '1.0.0', 
        'uptime': '2h 15m'
    }
}

# Action mapping
def _check_permissions():
    """Check critical file permissions with VM awareness"""
    results = {
        "passwd": SetupActions._get_file_status("/etc/passwd", "644", IS_VM_ENVIRONMENT),
        "shadow": SetupActions._get_file_status("/etc/shadow", "640", IS_VM_ENVIRONMENT),
        "sshd_config": SetupActions._get_file_status("/etc/ssh/sshd_config", "600", IS_VM_ENVIRONMENT),
        "sudoers": SetupActions._get_file_status("/etc/sudoers", "440", IS_VM_ENVIRONMENT)
    }
    
    # Determine overall status
    if all(item["status"] == "ok" for item in results.values()):
        overall_status = "ok"
        message = "All critical file permissions are secure"
    else:
        overall_status = "warning" if IS_VM_ENVIRONMENT else "error"
        message = "Some file permissions need attention" if IS_VM_ENVIRONMENT else "Insecure file permissions detected"
    
    results["overall"] = {
        "status": overall_status,
        "message": message
    }
    
    return results

def handle_client(client_socket):
    """Handle client connection"""
    try:
        # Read client request
        data = client_socket.recv(4096).decode('utf-8').strip()
        print(f"Received: {data}")
        
        try:
            request = json.loads(data)
            action = request.get('action', '')
            
            # Generate response based on action
            if action in SAMPLE_DATA:
                response = SAMPLE_DATA[action]
            elif action in SETUP_ACTIONS:
                response = SETUP_ACTIONS[action]()
            else:
                response = {"error": f"Unknown action: {action}"}
                
            # Send response back
            client_socket.sendall(json.dumps(response).encode('utf-8') + b'\n')
            
        except json.JSONDecodeError:
            client_socket.sendall(json.dumps({"error": "Invalid JSON"}).encode('utf-8') + b'\n')
            
    except Exception as e:
        print(f"Error handling client: {e}")
    finally:
        client_socket.close()

def main():
    # call the is running in VM function
    is_running_in_vm()
    """Start the backend Unix socket server"""
    # Remove socket file if it exists
    try:
        if os.path.exists(SOCKET_PATH):
            os.unlink(SOCKET_PATH)
    except Exception as e:
        print(f"Error removing socket file: {e}")
        sys.exit(1)
    
    # Create server socket
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    server.listen(5)
    
    print(f"Backend server listening on {SOCKET_PATH}")
    print(f"Environment: {'Virtual Machine' if IS_VM_ENVIRONMENT else 'Physical Machine'}")
    print("Press Ctrl+C to stop")
    
    try:
        while True:
            client, _ = server.accept()
            client_thread = threading.Thread(target=handle_client, args=(client,))
            client_thread.daemon = True
            client_thread.start()
    except KeyboardInterrupt:
        print("Shutting down...")
    finally:
        server.close()
        if os.path.exists(SOCKET_PATH):
            os.unlink(SOCKET_PATH)
            os.unlink(SOCKET_PATH)

if __name__ == "__main__":
    main()