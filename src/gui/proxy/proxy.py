import http.server
import socketserver
import socket
import json
import subprocess
import os
import ssl
import logging
from ratelimit import limits, sleep_and_retry
from pathlib import Path
import datetime

<<<<<<< HEAD
# Constants
SOCKET_PATH = '/tmp/hardn.sock'
=======
SOCKET_PATH = '/tmp/hardn.sock' # will need to move this socket path < Lets take a look at this
>>>>>>> 8476171ece892a945fa8f35384c0e87d9c361742
PORT = 8081
SSL_CERT_FILE = '/etc/hardn/cert.pem'
SSL_KEY_FILE = '/etc/hardn/key.pem'
RATE_LIMIT_CALLS = 100  # Max 100 requests
RATE_LIMIT_PERIOD = 60  # Per 60 seconds
BASE_DIR = Path(__file__).resolve().parent.parent.parent.parent

# Setup script paths
SETUP_SCRIPT = BASE_DIR / "src" / "setup" / "setup.sh"
PACKAGES_SCRIPT = BASE_DIR / "src" / "setup" / "packages.sh"

# Logging setup
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger('HARDN Proxy')

# Rate limiting decorator
@sleep_and_retry
@limits(calls=RATE_LIMIT_CALLS, period=RATE_LIMIT_PERIOD)
def rate_limit():
    pass

# VM detection function
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
    
    # Method 3: Use systemd-detect-virt if available
    try:
        result = subprocess.run(['systemd-detect-virt'], capture_output=True, text=True)
        if result.returncode == 0 and result.stdout.strip() != 'none':
            return True
    except Exception:
        pass
    
    # Method 4: Check for VM-specific directories
    vm_dirs = ['/sys/devices/virtual/dmi/id/product_name', '/sys/hypervisor/type']
    for vm_dir in vm_dirs:
        if Path(vm_dir).exists():
            try:
                with open(vm_dir, 'r') as f:
                    content = f.read().lower()
                    if any(x in content for x in ['vmware', 'virtualbox', 'qemu', 'kvm', 'xen']):
                        return True
            except Exception:
                pass
    
    return False

# Store the VM detection result
IS_VM_ENVIRONMENT = is_running_in_vm()
print(f"Environment detection: {'Virtual Machine' if IS_VM_ENVIRONMENT else 'Physical Machine'}")

# Special action handlers
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
    def check_selinux():
        """Direct API method for checking SELinux"""
        return SetupActions._check_selinux()
    
    @staticmethod
    def check_firewall():
        """Direct API method for checking firewall"""
        return SetupActions._check_firewall()
    
    @staticmethod
    def check_apparmor():
        """Direct API method for checking AppArmor"""
        return SetupActions._check_apparmor()
    
    @staticmethod
    def check_permissions():
        """Direct API method for checking permissions"""
        return SetupActions._check_permissions()
    
    @staticmethod
    def run_setup():
        """Run the setup script with environment awareness"""
        if not SETUP_SCRIPT.exists():
            return {"status": "error", "message": f"Setup script not found at {SETUP_SCRIPT}"}
        
        try:
            # Add VM awareness to setup script execution
            cmd = ['sudo', str(SETUP_SCRIPT)]
            
            # Add environment flag if it's a VM
            if IS_VM_ENVIRONMENT:
                cmd.append('--vm-environment')
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False
            )
            
            if result.returncode == 0:
                # Perform environment-specific setup actions
                setup_actions = []
                
                # Enable SELinux if not in VM
                if not IS_VM_ENVIRONMENT:
                    try:
                        selinux_status = SetupActions._check_selinux()
                        if selinux_status.get("status") != "ok":
                            selinux_result = subprocess.run(
                                ['sudo', 'setenforce', '1'],
                                capture_output=True,
                                text=True,
                                check=False
                            )
                            if selinux_result.returncode == 0:
                                setup_actions.append("Enabled SELinux")
                    except Exception:
                        pass
                
                # Enable AppArmor only on physical machines
                if not IS_VM_ENVIRONMENT:
                    try:
                        apparmor_status = SetupActions._check_apparmor()
                        if apparmor_status.get("status") != "ok":
                            apparmor_result = subprocess.run(
                                ['sudo', 'systemctl', 'enable', '--now', 'apparmor'],
                                capture_output=True,
                                text=True,
                                check=False
                            )
                            if apparmor_result.returncode == 0:
                                setup_actions.append("Enabled AppArmor")
                    except Exception:
                        pass
                
                return {
                    "status": "ok", 
                    "message": "Setup completed successfully", 
                    "output": result.stdout,
                    "environment": "virtual_machine" if IS_VM_ENVIRONMENT else "physical_machine",
                    "actions_performed": setup_actions
                }
            else:
                # Different messages based on environment
                if IS_VM_ENVIRONMENT:
                    return {
                        "status": "warning", 
                        "message": "Setup completed with warnings (VM environment)", 
                        "output": result.stdout,
                        "error": result.stderr,
                        "environment": "virtual_machine"
                    }
                else:
                    return {
                        "status": "error", 
                        "message": "Setup failed", 
                        "output": result.stdout,
                        "error": result.stderr,
                        "environment": "physical_machine"
                    }
        except Exception as e:
            return {"status": "error", "message": f"Error running setup: {str(e)}"}
    
    @staticmethod
    def run_packages():
        """Run the package validation script with environment awareness"""
        if not PACKAGES_SCRIPT.exists():
            return {"status": "error", "message": f"Packages script not found at {PACKAGES_SCRIPT}"}
        
        try:
            # Run the script with sudo and handle VM environment
            result = subprocess.run(
                f"echo '715466as' | sudo -S {PACKAGES_SCRIPT}",
                shell=True,
                capture_output=True,
                text=True
            )
            
            # Create response with environment context
            response = {
                "environment": "virtual_machine" if IS_VM_ENVIRONMENT else "physical_machine",
                "output": result.stdout
            }
            
            if result.returncode == 0:
                # Success state - different by environment
                if IS_VM_ENVIRONMENT:
                    response["status"] = "ok"
                    response["message"] = "Packages validated (virtual environment)"
                    response["note"] = "Some packages may have limited functionality in VMs"
                else:
                    response["status"] = "ok"
                    response["message"] = "All required packages validated successfully"
                
                # Parse package details from output if available
                if "Required packages:" in result.stdout:
                    try:
                        packages_section = result.stdout.split("Required packages:")[1].split("\n\n")[0]
                        packages = []
                        for line in packages_section.strip().split("\n"):
                            if line.strip():
                                package_info = line.strip().split(":")
                                if len(package_info) >= 2:
                                    packages.append({
                                        "name": package_info[0].strip(),
                                        "status": package_info[1].strip()
                                    })
                        response["packages"] = packages
                    except Exception as e:
                        response["parse_error"] = f"Could not parse package details: {str(e)}"
            else:
                # Error state - different message by environment
                if IS_VM_ENVIRONMENT:
                    response["status"] = "warning"
                    response["message"] = "Some packages could not be validated (acceptable in VM)"
                    response["error"] = result.stderr
                else:
                    response["status"] = "error"
                    response["message"] = "Package validation failed"
                    response["error"] = result.stderr
            
            return response
        except Exception as e:
            return {
                "status": "error", 
                "message": f"Error running package validation: {str(e)}",
                "environment": "virtual_machine" if IS_VM_ENVIRONMENT else "physical_machine"
            }

# Special action handlers for main.rs integration (future)
class UserActions:
    @staticmethod
    def get_user_settings():
        """Get current user settings (future integration with main.rs)"""
        # This is a placeholder that will be replaced with actual integration
        # when main.rs is ready as mentioned in the instructions
        return {
            "status": "warning",
            "message": "User settings integration pending main.rs approval",
            "settings": {
                "username": "testuser",
                "role": "administrator",
                "permissions": {
                    "can_run_setup": True,
                    "can_view_logs": True,
                    "can_modify_network": True
                }
            }
        }
    
    @staticmethod
    def update_user_setting(setting_name, value):
        """Update a user setting (future integration with main.rs)"""
        # This is a placeholder that will be replaced with actual integration
        return {
            "status": "warning",
            "message": f"Setting '{setting_name}' update pending main.rs integration",
            "updated": False,
            "requires_approval": True
        }
    
    @staticmethod
    def request_user_change(change_type, details):
        """Request a user change (future integration with main.rs)"""
        # This is a placeholder that will be replaced with actual integration
        return {
            "status": "warning",
            "message": f"Change request of type '{change_type}' pending main.rs integration",
            "request_id": "pending-integration-12345",
            "requires_approval": True
        }

# Action mapping
SETUP_ACTIONS = {
    "get_system_status": SetupActions.get_system_status,
    "check_selinux": SetupActions.check_selinux,
    "check_firewall": SetupActions.check_firewall,
    "check_apparmor": SetupActions.check_apparmor,
    "check_permissions": SetupActions.check_permissions,
    "run_setup": SetupActions.run_setup,
    "run_packages": SetupActions.run_packages
}

# Add the user actions to our action mapping
USER_ACTIONS = {
    "get_user_settings": UserActions.get_user_settings,
    "update_user_setting": lambda req: UserActions.update_user_setting(
        req.get('setting_name', ''), 
        req.get('value')
    ),
    "request_user_change": lambda req: UserActions.request_user_change(
        req.get('change_type', ''),
        req.get('details', {})
    )
}

class SecureHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        rate_limit()  # Enforce rate limiting

        if self.path != '/api':
            self.send_error(404, 'Endpoint not found')
            return

        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length)

        try:
            request = json.loads(body)
            action = request.get('action', '')

            # Validate token
            token = self.headers.get('Authorization')
            if not self.validate_token(token):
                self.send_error(401, 'Unauthorized')
                return

            # Check if this is a setup-related action
            if action in SETUP_ACTIONS:
                response = SETUP_ACTIONS[action]()
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode())
                return
            
            # Check if this is a user-related action (future main.rs integration)
            if action in USER_ACTIONS:
                if callable(USER_ACTIONS[action]):
                    response = USER_ACTIONS[action](request) 
                else:
                    response = USER_ACTIONS[action]()
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode())
                return

            # Forward to Unix socket (backend)
            client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            try:
                client.connect(SOCKET_PATH)
                client.sendall(body + b'\n')
                response = b''
                while True:
                    chunk = client.recv(4096)
                    if not chunk:
                        break
                    response += chunk
                    if b'\n' in chunk:
                        break
                client.close()
                lines = [l for l in response.split(b'\n') if l.strip()]
                if not lines:
                    self.send_error(502, 'No response from backend')
                    return
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(lines[0])
            except (FileNotFoundError, ConnectionRefusedError):
                self.send_error(503, 'Backend not available')
            except Exception as e:
                logger.error(f'Error forwarding request: {e}')
                self.send_error(500, 'Internal server error')
        except json.JSONDecodeError:
            self.send_error(400, 'Invalid JSON')
        except Exception as e:
            logger.error(f'Unexpected error: {e}')
            self.send_error(500, 'Internal server error')

    def validate_token(self, token):
        """Validate the provided token."""
        # Replace with actual token validation logic
        valid_tokens = ['secure-token-123']
        return token in valid_tokens

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.end_headers()

    def do_GET(self):
        """Handle GET requests for various endpoints"""
        if self.path == '/status':
            self.handle_get_status()
        elif self.path == '/run-packages':
            self.handle_run_packages()
        elif self.path == '/vm-checks':
            self.handle_vm_checks()
        else:
            self.send_error(404)

    def send_json_response(self, data):
        """Helper method to send JSON responses"""
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def handle_get_status(self):
        """Handle GET /status endpoint to check backend status"""
        try:
            client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            client.connect(SOCKET_PATH)
            client.sendall(json.dumps({"action": "status"}).encode() + b'\n')
            response = b''
            while True:
                chunk = client.recv(4096)
                if not chunk:
                    break
                response += chunk
                if b'\n' in chunk:
                    break
            client.close()
            
            lines = [l for l in response.split(b'\n') if l.strip()]
            if not lines:
                status = {"status": "error", "message": "No response from backend"}
            else:
                try:
                    status = json.loads(lines[0])
                except json.JSONDecodeError:
                    status = {"status": "error", "message": "Invalid JSON response from backend"}
            self.send_json_response(status)
        except (FileNotFoundError, ConnectionRefusedError):
            self.send_json_response({
                "status": "offline",
                "message": f"Backend not available: {SOCKET_PATH} not found or connection refused"
            })
        except Exception as e:
            self.send_json_response({
                "status": "error",
                "message": str(e)
            })

    def handle_run_packages(self):
        """Handle GET /run-packages endpoint to get list of running packages"""
        try:
            # Sample implementation - this would need actual logic to detect running packages
            packages = []
            if os.path.exists("/usr/bin/ksh"):
                packages.append("securesetup")
            if os.path.exists("/usr/bin/bash"):
                packages.append("shellutils")
            
            self.send_json_response({
                "status": "success",
                "packages": packages
            })
        except Exception as e:
            self.send_json_response({
                "status": "error",
                "message": str(e)
            })

    def handle_vm_checks(self):
        """Handle GET /vm-checks endpoint to check if running in a VM"""
        setup = SetupActions()
        is_vm = is_running_in_vm()
        
        result = {
            "is_vm": is_vm,
            "detection_methods": {
                "cpuinfo": setup.check_cpuinfo_for_vm(),
                "dmesg": setup.check_dmesg_for_vm(),
                "directories": setup.check_directories_for_vm()
            }
        }
        
        self.send_json_response(result)

if __name__ == '__main__':
    logger.info('Starting HARDN Proxy Server')

    # Check SSL certificate and key
    if not Path(SSL_CERT_FILE).exists() or not Path(SSL_KEY_FILE).exists():
        logger.error('SSL certificate or key file not found. Exiting.')
        exit(1)

    # Start server with SSL
    httpd = socketserver.TCPServer(('127.0.0.1', PORT), SecureHandler)
    httpd.socket = ssl.wrap_socket(httpd.socket, certfile=SSL_CERT_FILE, keyfile=SSL_KEY_FILE, server_side=True)

    logger.info(f'Serving on https://127.0.0.1:{PORT}')
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info('Shutting down server')
        httpd.server_close()