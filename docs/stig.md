1. stig_configure_pam()
   - **Purpose**: Configures PAM (Pluggable Authentication Module) to enforce password complexity and account lockout policies.
  
     1. Ensures passwords meet STIG requirements for length, complexity, and character diversity.
     2. Locks accounts after repeated failed login attempts to prevent brute-force attacks.
     3. Enforces retry limits and applies rules even for root accounts, ensuring consistent security.
     4. Improves overall system security by reducing the likelihood of weak or easily guessable passwords.

2. stig_configure_ssh()
   - **Purpose**: Configures SSH to disable root login, enforce key-based authentication, and set session timeouts.
 
     1. Disabling root login prevents attackers from directly targeting the root account.
     2. Enforcing key-based authentication ensures stronger, more secure login methods.
     3. Session timeouts reduce the risk of unauthorized access from idle sessions.
     4. Aligns with STIG guidelines to secure remote access to the system.

3. stig_lock_inactive_accounts()
   - **Purpose**: Locks user accounts that have been inactive for 35 days.
  
     1. Prevents unauthorized access through unused or forgotten accounts.
     2. Ensures compliance with STIG account management policies for inactive accounts.
     3. Reduces the attack surface by deactivating accounts that are no longer in use.
     4. Helps administrators maintain better control over active user accounts.

4. stig_login_banners()
   - **Purpose**: Sets login banners for `/etc/issue` and `/etc/issue.net` labeling "SIG" as documented group. 
   
     1. Displays security warnings to users before login, ensuring they are aware of monitoring.
     2. Complies with STIG requirements for system access notifications.
     3. Acts as a legal disclaimer for monitoring and acceptable use policies.
     4. Provides a consistent security message across all login interfaces.

5. stig_secure_filesystem()
   - **Purpose**: Secures permissions for critical system files like `/etc/passwd`, `/etc/shadow`, and `/etc/group`.
  
     1. Prevents unauthorized access or modification of sensitive system files.
     2. Ensures system integrity by restricting access to critical configuration files.
     3. Protects user credentials stored in `/etc/shadow` from being exposed.
     4. Aligns with STIG guidelines for securing file permissions.

6. stig_audit_rules()
   - **Purpose**: Configures audit rules to monitor changes to critical files and directories.
   
     1. Tracks modifications to sensitive files like `/etc/passwd` and `/etc/shadow`.
     2. Ensures accountability by logging changes for auditing purposes.
     3. Helps detect unauthorized access or tampering with critical system files.
     4. Meets STIG requirements for system auditing and monitoring.

7. stig_disable_usb()
   - **Purpose**: Disables USB storage devices by blacklisting the `usb-storage` kernel module.
 
     1. Prevents unauthorized data exfiltration via USB devices.
     2. Reduces the risk of malware introduction through removable media.
     3. Aligns with STIG guidelines for securing physical access to the system.
     4. Helps enforce data protection policies in secure environments.

8. stig_enforce_partitioning()
   - **Purpose**: Configures secure partitioning for `/tmp`, `/home`, and `/boot` with appropriate mount options.
   
     1. Isolates temporary files in `/tmp` to prevent unauthorized code execution.
     2. Ensures `/home` is mounted with `nodev` to block device files in user directories.
     3. Protects `/boot` with `nosuid` and `nodev` to prevent privilege escalation.
     4. Aligns with STIG requirements for secure partitioning and data isolation.

9. stig_disable_core_dumps()
   - **Purpose**: Disables core dumps for setuid programs.
   
     1. Prevents sensitive information from being exposed in core dumps.
     2. Reduces the risk of attackers exploiting core dumps to analyze system memory.
     3. Aligns with STIG policies for securing system memory and debugging tools.
     4. Ensures compliance with best practices for system hardening.

10. stig_disable_ctrl_alt_del()
    - **Purpose**: Disables the `Ctrl+Alt+Del` key combination to prevent accidental or unauthorized reboots.
    
      1. Prevents unintended system reboots caused by keyboard shortcuts.
      2. Ensures system availability by reducing the risk of accidental downtime.
      3. Aligns with STIG guidelines for system availability and uptime.
      4. Helps maintain control over system reboots in secure environments.

11. stig_disable_icmp_redirects()
    - **Purpose**: Disables ICMP redirects for IPv4.
    
      1. Prevents attackers from redirecting network traffic to malicious destinations.
      2. Ensures secure network configurations by blocking unnecessary ICMP messages.
      3. Reduces the risk of man-in-the-middle (MITM) attacks.
      4. Aligns with STIG requirements for network hardening.

12. stig_disable_ipv6()
    - **Purpose**: Disables IPv6 if it is not required.
  
      1. Reduces the attack surface by disabling unused network protocols.
      2. Prevents potential misconfigurations or vulnerabilities in IPv6.
      3. Aligns with STIG guidelines for securing network protocols.
      4. Simplifies network management in environments that do not use IPv6.

13. stig_configure_ufw()
    - **Purpose**: Configures UFW (Uncomplicated Firewall) to enforce STIG-compliant firewall rules.
  
      1. Blocks unauthorized incoming traffic while allowing necessary outgoing traffic.
      2. Ensures secure communication for DNS and HTTPS.
      3. Aligns with STIG guidelines for network access control.
      4. Provides a simple and effective way to manage firewall rules.

14. stig_enforce_apparmor_whitelist()
    - **Purpose**: Enforces an AppArmor whitelist for specific applications.
  
      1. Restricts applications to predefined behaviors, reducing the risk of exploitation.
      2. Ensures only authorized applications can execute specific actions.
      3. Aligns with STIG guidelines for application whitelisting.
      4. Enhances system security by limiting the scope of application permissions.

15. stig_set_randomize_va_space()
    - **Purpose**: Configures `kernel.randomize_va_space` to enable Address Space Layout Randomization (ASLR).
  
      1. Mitigates memory-based attacks by randomizing memory addresses.
      2. Aligns with STIG kernel hardening requirements for system security.
      3. Reduces the predictability of memory layouts, making exploitation harder.
      4. Ensures compliance with modern security best practices.