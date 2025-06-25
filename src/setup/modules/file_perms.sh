########################### Set secure file permissions
HARDN_STATUS "info" "Setting secure file permissions..."
chmod 700 /root                    # root home directory - root
chmod 644 /etc/passwd              # user database - readable (required)
chmod 600 /etc/shadow              # password hashes - root only
chmod 644 /etc/group               # group database - readable
chmod 600 /etc/gshadow             # group passwords - root   
chmod 644 /etc/ssh/sshd_config     # SSH daemon config - readable
