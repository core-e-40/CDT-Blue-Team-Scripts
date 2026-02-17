#!/bin/bash

USER="$1"

if [ -z "$USER" ]; then
  echo "Usage: sudo ./disable_user.sh username"
  exit 1
fi

echo "Restricting user: $USER"

# -------------------------------------------------
# 1. Disable Login
# -------------------------------------------------
passwd -l "$USER"

# -------------------------------------------------
# 2. Disable Shell
# -------------------------------------------------
usermod -s /usr/sbin/nologin "$USER"

# -------------------------------------------------
# 3. Disable SSH Access
# -------------------------------------------------
echo "DenyUsers $USER" >> /etc/ssh/sshd_config

# Disable SSH tunneling explicitly
echo "
Match User $USER
    AllowTcpForwarding no
    X11Forwarding no
    PermitTunnel no
" >> /etc/ssh/sshd_config

systemctl restart ssh

echo "User $USER restricted."
