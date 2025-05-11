#!/bin/bash
# STIG Login Banners
echo "You are accessing a fully secured SIG Information System (IS)..." > /etc/issue
echo "Use of this IS constitutes consent to monitoring..." > /etc/issue.net
chmod 644 /etc/issue /etc/issue.net
