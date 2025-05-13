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
    @staticmethod
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
    
    @staticmethod
    def _check_selinux():
        """Check SELinux status with VM awareness"""
        try:
            result = subprocess.run(['getenforce'], capture_output=True, text=True)
            if result.returncode != 0:
                if IS_VM_ENVIRONMENT:
                    return {
                        "status": "warning", 
                        "message": "SELinux not detected, but acceptable in VM environment", 
                        "enforced": False
                    }
                else:
                    return {
                        "status": "error", 
                        "message": "SELinux not detected", 
                        "enforced": False
                    }
                
            status = result.stdout.strip()
            if status == "Enforcing":
                return {
                    "status": "ok", 
                    "message": "SELinux is enforcing", 
                    "enforced": True
                }
            elif status == "Permissive":
                if IS_VM_ENVIRONMENT:
                    return {
                        "status": "warning", 
                        "message": "SELinux is in permissive mode (acceptable in VM)", 
                        "enforced": False
                    }
                else:
                    return {
                        "status": "warning", 
                        "message": "SELinux is in permissive mode", 
                        "enforced": False
                    }
            else:
                if IS_VM_ENVIRONMENT:
                    return {
                        "status": "warning", 
                        "message": "SELinux is disabled (acceptable in VM)", 
                        "enforced": False
                    }
                else:
                    return {
                        "status": "error", 
                        "message": "SELinux is disabled", 
                        "enforced": False
                    }
        except FileNotFoundError:
            if IS_VM_ENVIRONMENT:
                return {
                    "status": "warning", 
                    "message": "SELinux tools not installed (acceptable in VM)", 
                    "enforced": False
                }
            else:
                return {
                    "status": "error", 
                    "message": "SELinux tools not installed", 
                    "enforced": False
                }
        except Exception as e:
            return {
                "status": "error", 
                "message": f"Error checking SELinux: {str(e)}", 
                "enforced": False
            }
    
    @staticmethod
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
    
    @staticmethod
    def _check_apparmor():
        """Check AppArmor status with VM awareness"""
        try:
            result = subprocess.run(['aa-status'], capture_output=True, text=True)
            if result.returncode == 0:
                if "profiles are loaded" in result.stdout:
                    return {
                        "status": "ok", 
                        "message": "AppArmor is active with profiles loaded", 
                        "active": True
                    }
                else:
                    if IS_VM_ENVIRONMENT:
                        return {
                            "status": "warning", 
                            "message": "AppArmor is active but no profiles loaded (acceptable in VM)", 
                            "active": True
                        }
                    else:
                        return {
                            "status": "warning", 
                            "message": "AppArmor is active but no profiles loaded", 
                            "active": True
                        }
            else:
                if IS_VM_ENVIRONMENT:
                    return {
                        "status": "warning", 
                        "message": "AppArmor is not active (acceptable in VM)", 
                        "active": False
                    }
                else:
                    return {
                        "status": "error", 
                        "message": "AppArmor is not active", 
                        "active": False
                    }
        except FileNotFoundError:
            if IS_VM_ENVIRONMENT:
                return {
                    "status": "warning", 
                    "message": "AppArmor tools not installed (acceptable in VM)", 
                    "active": False
                }
            else:
                return {
                    "status": "error", 
                    "message": "AppArmor tools not installed", 
                    "active": False
                }
        except Exception as e:
            return {
                "status": "error", 
                "message": f"Error checking AppArmor: {str(e)}", 
                "active": False
            }
    
    @staticmethod
    def _check_permissions():
        """Check file permissions with VM awareness"""
        # Check permissions for sensitive directories
        sensitive_dirs = [
            '/etc/shadow',
            '/etc/sudoers',
            '/etc/ssh/sshd_config'
        ]
        
        results = []
        for path in sensitive_dirs:
            try:
                if not Path(path).exists():
                    results.append({
                        "path": path,
                        "exists": False,
                        "permissions": None,
                        "status": "warning" if IS_VM_ENVIRONMENT else "error",
                        "message": f"File not found (acceptable in VM)" if IS_VM_ENVIRONMENT else "File not found"
                    })
                    continue
                    
                result = subprocess.run(['stat', '-c', '%a', path], capture_output=True, text=True)
                if result.returncode != 0:
                    results.append({
                        "path": path,
                        "exists": True,
                        "permissions": None,
                        "status": "warning" if IS_VM_ENVIRONMENT else "error",
                        "message": f"Could not check permissions (acceptable in VM)" if IS_VM_ENVIRONMENT 
                                  else "Could not check permissions"
                    })
                    continue
                    
                perms = result.stdout.strip()
                if path == '/etc/shadow' and perms == '640':
                    results.append({
                        "path": path,
                        "exists": True,
                        "permissions": perms,
                        "status": "ok",
                        "message": "Permissions are secure"
                    })
                elif path == '/etc/sudoers' and perms == '440':
                    results.append({
                        "path": path,
                        "exists": True,
                        "permissions": perms,
                        "status": "ok",
                        "message": "Permissions are secure"
                    })
                elif path == '/etc/ssh/sshd_config' and perms == '600':
                    results.append({
                        "path": path,
                        "exists": True,
                        "permissions": perms,
                        "status": "ok",
                        "message": "Permissions are secure"
                    })
                else:
                    if IS_VM_ENVIRONMENT:
                        results.append({
                            "path": path,
                            "exists": True,
                            "permissions": perms,
                            "status": "warning",
                            "message": f"Permissions are not secure: {perms} (acceptable in VM)"
                        })
                    else:
                        results.append({
                            "path": path,
                            "exists": True,
                            "permissions": perms,
                            "status": "error",
                            "message": f"Permissions are not secure: {perms}"
                        })
            except Exception as e:
                results.append({
                    "path": path,
                    "exists": None,
                    "permissions": None,
                    "status": "error",
                    "message": f"Error checking permissions: {str(e)}"
                })
        
        # Determine overall permission status
        if all(r['status'] == 'ok' for r in results):
            return {
                "status": "ok",
                "message": "All file permissions are secure",
                "details": results
            }
        elif IS_VM_ENVIRONMENT and not any(r['status'] == 'error' for r in results):
            return {
                "status": "warning",
                "message": "Some permissions need attention but acceptable in VM",
                "details": results
            }
        else:
            return {
                "status": "error",
                "message": "Some file permissions are not secure",
                "details": results
            }

    @staticmethod
    def check_cpuinfo_for_vm():
        """Check CPU info for VM indicators"""
        try:
            with open('/proc/cpuinfo', 'r') as f:
                cpuinfo = f.read().lower()
                return any(x in cpuinfo for x in ['hypervisor', 'vmware', 'virtualbox', 'kvm', 'xen'])
        except:
            return False
            
    @staticmethod
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
            
    @staticmethod
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
                except:
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
SETUP_ACTIONS = {
    "get_system_status": SetupActions.get_system_status,
    "check_selinux": SetupActions._check_selinux,
    "check_firewall": SetupActions._check_firewall,
    "check_apparmor": SetupActions._check_apparmor,
    "check_permissions": SetupActions._check_permissions
}

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