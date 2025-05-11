#!/bin/bash
# STIG Disable Ctrl+Alt+Del
systemctl mask ctrl-alt-del.target
systemctl daemon-reexec
