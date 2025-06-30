# Security Tools in HARDN-XDR

Below is a comprehensive list of security tools used in the HARDN-XDR project's `hardn-main.sh` script and `/modules`, along with brief descriptions and external resource links:

## System Security Tools

1. **auditd**
    - Description: Linux auditing system that tracks security-relevant events and records them in log files.
    - Purpose: Monitors system calls, file access, and user activities for security auditing.
    - Link: [Linux Audit Documentation](https://linux.die.net/man/8/auditd)

2. **audispd-plugins**
    - Description: Plugins for the audit event dispatcher that allow forwarding audit events to remote systems.
    - Purpose: Extends auditd functionality for distributed monitoring environments.
    - Link: [Audit Dispatcher Documentation](https://linux.die.net/man/8/audispd)

3. **Suricata**
    - Description: High-performance network IDS, IPS, and network security monitoring engine.
    - Purpose: Detects and prevents network-based threats in real-time.
    - Link: [Suricata Website](https://suricata.io/)

4. **Fail2ban**
    - Description: Intrusion prevention framework that protects against brute-force attacks.
    - Purpose: Monitors logs and bans IP addresses showing malicious behavior.
    - Link: [Fail2ban Website](https://www.fail2ban.org/)

5. **rkhunter** (Rootkit Hunter)
    - Description: Tool that scans for rootkits, backdoors, and local exploits.
    - Purpose: Detects hidden malware and unauthorized system modifications.
    - Link: [rkhunter GitHub](https://github.com/rootkitHunter/rkhunter)

6. **chkrootkit**
    - Description: Tool to locally check for signs of a rootkit infection.
    - Purpose: Alternative rootkit detection with different detection methods than rkhunter.
    - Link: [chkrootkit Website](http://www.chkrootkit.org/)

7. **unhide**
    - Description: Forensic tool to find hidden processes and ports.
    - Purpose: Detects processes and network connections hidden by rootkits.
    - Link: [Unhide on Kali Tools](https://www.kali.org/tools/unhide/)

8. **debsums**
    - Description: Tool for verification of installed Debian package files against MD5 checksums.
    - Purpose: Detects modified or corrupted system files.
    - Link: [Debsums Manual](https://manpages.debian.org/stretch/debsums/debsums.1.en.html)

9. **Lynis**
    - Description: Security auditing and hardening tool for Unix/Linux systems.
    - Purpose: Performs comprehensive system security scans and provides hardening advice.
    - Link: [Lynis Website](https://cisofy.com/lynis/)

## Malware Detection

10. **ClamAV** (clamav, clamav-daemon, clamav-freshclam)
    - Description: Open-source antivirus engine for detecting trojans, viruses, malware, and other threats.
    - Purpose: Scans files and directories for known malware signatures.
    - Link: [ClamAV Website](https://www.clamav.net/)

11. **YARA**
    - Description: Pattern matching tool designed for malware researchers.
    - Purpose: Creates custom rules to identify and classify malware samples.
    - Link: [YARA Documentation](https://yara.readthedocs.io/)

12. **AIDE** (aide, aide-common)
    - Description: Advanced Intrusion Detection Environment, a file integrity checker.
    - Purpose: Monitors file changes to detect unauthorized modifications.
    - Link: [AIDE Website](https://aide.github.io/)

## System Monitoring and Logging

13. **rsyslog**
    - Description: High-performance log processing system.
    - Purpose: Collects and forwards log messages for centralized monitoring.
    - Link: [Rsyslog Website](https://www.rsyslog.com/)

14. **logrotate**
    - Description: Log file rotation, compression, and removal utility.
    - Purpose: Manages log files to prevent disk space exhaustion.
    - Link: [Logrotate Documentation](https://linux.die.net/man/8/logrotate)

15. **needrestart**
    - Description: Checks which daemons need to be restarted after library upgrades.
    - Purpose: Ensures system services use updated libraries after security patches.
    - Link: [Needrestart Package](https://packages.debian.org/sid/needrestart)

## Package Management Security

16. **apt-listchanges**
    - Description: Shows changelog entries between installed and available package versions.
    - Purpose: Helps administrators review security implications before upgrades.
    - Link: [apt-listchanges Manual](https://manpages.debian.org/stretch/apt-listchanges/apt-listchanges.1.en.html)

17. **apt-listbugs**
    - Description: Lists critical bugs before each APT installation.
    - Purpose: Prevents installation of packages with known critical bugs.
    - Link: [apt-listbugs Package](https://packages.debian.org/sid/apt-listbugs)

18. **unattended-upgrades**
    - Description: Automatically installs security updates.
    - Purpose: Ensures timely application of security patches without manual intervention.
    - Link: [Unattended-Upgrades Documentation](https://wiki.debian.org/UnattendedUpgrades)

19. **apt-transport-https**
    - Description: APT transport for downloading packages over HTTPS.
    - Purpose: Provides encrypted package downloads to prevent MITM attacks.
    - Link: [APT HTTPS Transport](https://packages.debian.org/sid/apt-transport-https)

## Network Security

20. **UFW** (Uncomplicated Firewall)
    - Description: Simplified interface for managing iptables firewall rules.
    - Purpose: Controls network traffic to and from the system.
    - Link: [UFW Documentation](https://help.ubuntu.com/community/UFW)

21. **systemd-timesyncd**
    - Description: Simple NTP client for time synchronization.
    - Purpose: Ensures accurate system time for security logging and certificate validation.
    - Link: [systemd-timesyncd Documentation](https://www.freedesktop.org/software/systemd/man/systemd-timesyncd.service.html)

## Access Control and Confinement

22. **AppArmor** (apparmor, apparmor-profiles, apparmor-utils)
    - Description: Mandatory Access Control (MAC) system for confining programs.
    - Purpose: Restricts programs to a limited set of resources and capabilities.
    - Link: [AppArmor Wiki](https://gitlab.com/apparmor/apparmor/-/wikis/home)

23. **Firejail**
    - Description: SUID sandbox program that reduces the risk of security breaches.
    - Purpose: Restricts the running environment of untrusted applications.
    - Link: [Firejail Website](https://firejail.wordpress.com/)

## Authentication Security

24. **libpam-pwquality**
    - Description: PAM module for password quality checking.
    - Purpose: Enforces strong password policies.
    - Link: [pwquality Documentation](https://github.com/libpwquality/libpwquality)

25. **libpam-google-authenticator**
    - Description: PAM module implementing two-factor authentication.
    - Purpose: Adds an additional layer of authentication security.
    - Link: [Google Authenticator PAM](https://github.com/google/google-authenticator-libpam)

26. **libpam-tmpdir**
    - Description: PAM module that sets the TMPDIR environment variable.
    - Purpose: Prevents certain temp file-based attacks.
    - Link: [libpam-tmpdir Package](https://packages.debian.org/sid/libpam-tmpdir)

## Utility Tools

27. **curl** and **wget**
    - Description: Command-line tools for transferring data with URLs.
    - Purpose: Secure file downloads and API interactions.
    - Links: [curl Website](https://curl.se/), [GNU Wget](https://www.gnu.org/software/wget/)

28. **lsof**
    - Description: Lists open files and the processes that opened them.
    - Purpose: Identifies which processes are accessing which files and network connections.
    - Link: [lsof Documentation](https://linux.die.net/man/8/lsof)

29. **psmisc**
    - Description: Utilities for managing system processes.
    - Purpose: Includes tools like fuser, killall, and pstree for process management.
    - Link: [psmisc Package](https://packages.debian.org/sid/psmisc)

30. **procps**
    - Description: Utilities for monitoring processes and system statistics.
    - Purpose: Includes tools like ps, top, and vmstat for system monitoring.
    - Link: [procps-ng Project](https://gitlab.com/procps-ng/procps)

These security tools work together to create a comprehensive security posture for Debian-based systems, implementing defense-in-depth strategies across multiple security domains.
