#!/bin/bash
#==============================
# Ubuntu System Hardening - Competition Safe
# Generates random 6-digit sudo password (display only)
# FIXED: Proper sudo hardening without syntax errors
# By: Cory Le
#==============================

LOG_FILE="/opt/blue_scripts/system_hardening.log"
BACKUP_DIR="/opt/blue_scripts/backups/system_$(date +%Y%m%d_%H%M%S)"

echo "$(date): Starting competition-compliant system hardening..." | tee -a $LOG_FILE

# Create backup directory
mkdir -p $BACKUP_DIR
chmod 700 $BACKUP_DIR

# ============================================
# SECTION 0: GENERATE RANDOM SUDO PASSWORD
# ============================================

# Get the REAL user (the one who ran sudo, not root)
if [ -n "$SUDO_USER" ]; then
    TARGET_USER="$SUDO_USER"
else
    TARGET_USER="$(whoami)"
fi

echo "$(date): Changing password for: $TARGET_USER" | tee -a $LOG_FILE

# Generate random 6-digit number
SUDO_PASSWORD=$(shuf -i 100000-999999 -n 1)

echo ""
echo "=========================================="
echo "🔒 CRITICAL: WRITE THIS DOWN NOW!"
echo "=========================================="
echo ""
echo "New password for user: $TARGET_USER"
echo "Password: $SUDO_PASSWORD"
echo ""
echo "This will NOT be saved anywhere!"
echo "Write it down before continuing!"
echo ""
echo "Press Enter when you've written it down..."
read -r

echo ""
echo "Changing password for $TARGET_USER..."

# Change the target user's password
echo "$TARGET_USER:$SUDO_PASSWORD" | chpasswd

if [ $? -eq 0 ]; then
    echo "✓ Password changed successfully for $TARGET_USER"
else
    echo "✗ ERROR: Password change failed!"
    exit 1
fi

echo ""
echo "Waiting 5 seconds before clearing screen..."
sleep 5

# Clear the screen
clear

# Clear bash history of this command
history -c

echo "$(date): Password changed for $TARGET_USER (not logged)" | tee -a $LOG_FILE
echo "Screen cleared, password not saved anywhere" | tee -a $LOG_FILE

# ============================================
# SECTION 1: HARDEN SSH
# ============================================

echo "$(date): Hardening SSH configuration..." | tee -a $LOG_FILE

# Backup original SSH config
cp /etc/ssh/sshd_config $BACKUP_DIR/sshd_config.backup

# Disable root login
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
grep -q "^PermitRootLogin" /etc/ssh/sshd_config || echo "PermitRootLogin no" >> /etc/ssh/sshd_config

# Disable empty passwords
sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
grep -q "^PermitEmptyPasswords" /etc/ssh/sshd_config || echo "PermitEmptyPasswords no" >> /etc/ssh/sshd_config

# Disable X11 forwarding
sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
grep -q "^X11Forwarding" /etc/ssh/sshd_config || echo "X11Forwarding no" >> /etc/ssh/sshd_config

# Set max auth tries
sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
grep -q "^MaxAuthTries" /etc/ssh/sshd_config || echo "MaxAuthTries 3" >> /etc/ssh/sshd_config

# Set login grace time
sed -i 's/^#*LoginGraceTime.*/LoginGraceTime 30/' /etc/ssh/sshd_config
grep -q "^LoginGraceTime" /etc/ssh/sshd_config || echo "LoginGraceTime 30" >> /etc/ssh/sshd_config

# Disable unused authentication methods
grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config || echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
grep -q "^ChallengeResponseAuthentication" /etc/ssh/sshd_config || echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config
grep -q "^KerberosAuthentication" /etc/ssh/sshd_config || echo "KerberosAuthentication no" >> /etc/ssh/sshd_config
grep -q "^GSSAPIAuthentication" /etc/ssh/sshd_config || echo "GSSAPIAuthentication no" >> /etc/ssh/sshd_config

# Test SSH config
sshd -t
if [ $? -eq 0 ]; then
    systemctl restart sshd
    echo "SUCCESS: SSH hardened and restarted" | tee -a $LOG_FILE
else
    echo "ERROR: SSH config has errors, restoring backup" | tee -a $LOG_FILE
    cp $BACKUP_DIR/sshd_config.backup /etc/ssh/sshd_config
    exit 1
fi

# ============================================
# SECTION 2: HARDEN SUDO (FIXED)
# ============================================

echo "$(date): Hardening sudo configuration..." | tee -a $LOG_FILE

# Backup sudoers
cp /etc/sudoers $BACKUP_DIR/sudoers.backup

# Create a clean sudoers file without NOPASSWD
cat > /tmp/sudoers.new <<'EOF'
# This file MUST be edited with the 'visudo' command as root.
#
# See the man page for details on how to write a sudoers file.
#
Defaults        env_reset
Defaults        mail_badpass
Defaults        secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"

# Host alias specification

# User alias specification

# Cmnd alias specification

# User privilege specification
root    ALL=(ALL:ALL) ALL

# Members of the admin group may gain root privileges
%admin ALL=(ALL) ALL

# Allow members of group sudo to execute any command (PASSWORD REQUIRED)
%sudo   ALL=(ALL:ALL) ALL

# See sudoers(5) for more information on "@include" directives:
@includedir /etc/sudoers.d
EOF

# Test the new sudoers file syntax
visudo -c -f /tmp/sudoers.new >> $LOG_FILE 2>&1

if [ $? -eq 0 ]; then
    # Syntax is valid, install it
    cp /tmp/sudoers.new /etc/sudoers
    chmod 440 /etc/sudoers
    rm /tmp/sudoers.new
    echo "SUCCESS: Main sudoers file hardened (NOPASSWD removed)" | tee -a $LOG_FILE
else
    echo "ERROR: New sudoers file has syntax errors!" | tee -a $LOG_FILE
    cat /tmp/sudoers.new | tee -a $LOG_FILE
    rm /tmp/sudoers.new
    exit 1
fi

# Fix sudoers.d files
echo "$(date): Fixing sudoers.d files..." | tee -a $LOG_FILE

for file in /etc/sudoers.d/*; do
    # Skip if not a regular file
    if [ ! -f "$file" ] || [ -d "$file" ]; then
        continue
    fi
    
    # Skip README
    if [ "$(basename $file)" = "README" ]; then
        continue
    fi
    
    # Backup
    cp "$file" "$BACKUP_DIR/$(basename $file).backup"
    
    # Remove NOPASSWD carefully
    sed -i 's/NOPASSWD:[[:space:]]*//g' "$file"
    
    # Test syntax
    visudo -c -f "$file" >> $LOG_FILE 2>&1
    
    if [ $? -eq 0 ]; then
        echo "Fixed: $file" | tee -a $LOG_FILE
    else
        echo "ERROR in $file, restoring backup" | tee -a $LOG_FILE
        cp "$BACKUP_DIR/$(basename $file).backup" "$file"
    fi
done

echo "SUCCESS: sudo configuration fully hardened" | tee -a $LOG_FILE

# ============================================
# SECTION 3: CONFIGURE FIREWALL (UFW)
# ============================================

echo "$(date): Configuring firewall..." | tee -a $LOG_FILE

# Check if ufw is installed
if ! command -v ufw &> /dev/null; then
    echo "WARNING: UFW not installed, skipping firewall config" | tee -a $LOG_FILE
else
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing

    # Allow SSH (CRITICAL - don't lock yourself out!)
    ufw allow 22/tcp

    # Allow HTTP/HTTPS (for scored web services)
    ufw allow 80/tcp
    ufw allow 443/tcp

    # Allow FTP (vsftpd - scored service)
    ufw allow 21/tcp

    # Allow IRC (scored service)
    ufw allow 6667/tcp

    # Allow SMB (scored service - Windows file sharing)
    ufw allow 445/tcp
    ufw allow 139/tcp

    # Enable firewall
    echo "y" | ufw enable

    # Show status
    ufw status numbered | tee -a $LOG_FILE

    echo "SUCCESS: Firewall configured" | tee -a $LOG_FILE
fi

# ============================================
# SECTION 4: DISABLE UNNECESSARY SERVICES
# ============================================

echo "$(date): Disabling unnecessary services..." | tee -a $LOG_FILE

UNNECESSARY_SERVICES=(
    "bluetooth"
    "cups"
    "avahi-daemon"
)

for service in "${UNNECESSARY_SERVICES[@]}"; do
    if systemctl is-active --quiet $service 2>/dev/null; then
        systemctl stop $service
        systemctl disable $service
        echo "Disabled: $service" | tee -a $LOG_FILE
    fi
done

echo "SUCCESS: Unnecessary services disabled" | tee -a $LOG_FILE

# ============================================
# SECTION 5: KERNEL HARDENING (SYSCTL)
# ============================================

echo "$(date): Applying kernel hardening..." | tee -a $LOG_FILE

# Backup original sysctl
cp /etc/sysctl.conf $BACKUP_DIR/sysctl.conf.backup 2>/dev/null

# Create hardening config
cat > /etc/sysctl.d/99-hardening.conf <<'EOF'
# IP Forwarding (disable if not a router)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Enable IP spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Log Martians (packets with impossible addresses)
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore Broadcast pings
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Enable TCP SYN cookies (prevent SYN flood attacks)
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Protect against time-wait assassination
net.ipv4.tcp_rfc1337 = 1

# Kernel address space layout randomization
kernel.randomize_va_space = 2

# Restrict kernel pointers in /proc
kernel.kptr_restrict = 2

# Restrict dmesg access
kernel.dmesg_restrict = 1

# Disable core dumps
fs.suid_dumpable = 0
kernel.core_uses_pid = 1
EOF

# Apply sysctl settings
sysctl -p /etc/sysctl.d/99-hardening.conf >> $LOG_FILE 2>&1

echo "SUCCESS: Kernel hardening applied" | tee -a $LOG_FILE

# ============================================
# SECTION 6: SECURE SHARED MEMORY
# ============================================

echo "$(date): Securing shared memory..." | tee -a $LOG_FILE

# Backup fstab
cp /etc/fstab $BACKUP_DIR/fstab.backup

# Add secure shared memory mount
if ! grep -q "tmpfs /run/shm" /etc/fstab; then
    echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab
    echo "SUCCESS: Shared memory secured (will apply on reboot)" | tee -a $LOG_FILE
fi

# Remount with new options (may fail if not mounted)
mount -o remount /run/shm 2>/dev/null && echo "Shared memory remounted" | tee -a $LOG_FILE

# ============================================
# SECTION 7: SECURE FILE PERMISSIONS
# ============================================

echo "$(date): Setting secure file permissions..." | tee -a $LOG_FILE

# Critical system files
chmod 644 /etc/passwd 2>/dev/null
chmod 644 /etc/group 2>/dev/null
chmod 600 /etc/shadow 2>/dev/null
chmod 600 /etc/gshadow 2>/dev/null
chmod 644 /etc/hosts 2>/dev/null
chmod 644 /etc/hostname 2>/dev/null

# SSH keys
chmod 700 /root/.ssh 2>/dev/null || true
chmod 600 /root/.ssh/authorized_keys 2>/dev/null || true

# Cron
chmod 600 /etc/crontab 2>/dev/null
chmod 700 /etc/cron.d 2>/dev/null
chmod 700 /etc/cron.daily 2>/dev/null
chmod 700 /etc/cron.hourly 2>/dev/null
chmod 700 /etc/cron.monthly 2>/dev/null
chmod 700 /etc/cron.weekly 2>/dev/null

echo "SUCCESS: File permissions secured" | tee -a $LOG_FILE

# ============================================
# SECTION 8: DISABLE CORE DUMPS
# ============================================

echo "$(date): Disabling core dumps..." | tee -a $LOG_FILE

# Backup limits.conf
cp /etc/security/limits.conf $BACKUP_DIR/limits.conf.backup 2>/dev/null

# Disable core dumps
grep -q "* hard core 0" /etc/security/limits.conf || echo "* hard core 0" >> /etc/security/limits.conf

# Also disable via systemd
mkdir -p /etc/systemd/coredump.conf.d
cat > /etc/systemd/coredump.conf.d/disable.conf <<'EOF'
[Coredump]
Storage=none
EOF

echo "SUCCESS: Core dumps disabled" | tee -a $LOG_FILE

# ============================================
# SECTION 9: SET UMASK
# ============================================

echo "$(date): Setting secure umask..." | tee -a $LOG_FILE

# Backup login.defs
cp /etc/login.defs $BACKUP_DIR/login.defs.backup 2>/dev/null

# Set umask to 027 (more restrictive)
sed -i 's/^UMASK.*/UMASK 027/' /etc/login.defs
grep -q "^UMASK" /etc/login.defs || echo "UMASK 027" >> /etc/login.defs

# Set in profile files
grep -q "umask 027" /etc/profile || echo "umask 027" >> /etc/profile
grep -q "umask 027" /etc/bash.bashrc || echo "umask 027" >> /etc/bash.bashrc

echo "SUCCESS: Secure umask set" | tee -a $LOG_FILE

# ============================================
# SECTION 10: FIND SUSPICIOUS FILES
# ============================================

echo "$(date): Scanning for suspicious files..." | tee -a $LOG_FILE

# Find world-writable files (top 20)
echo "Checking for world-writable files..." | tee -a $LOG_FILE
find / -xdev -type f -perm -0002 2>/dev/null | head -20 >> $LOG_FILE

# Find SUID files
echo "Checking for SUID files..." | tee -a $LOG_FILE
find / -xdev -type f -perm -4000 2>/dev/null >> $LOG_FILE

# Find files in /tmp
echo "Checking /tmp directory..." | tee -a $LOG_FILE
ls -la /tmp/ 2>/dev/null >> $LOG_FILE

echo "SUCCESS: File scan complete (see log)" | tee -a $LOG_FILE

# ============================================
# SECTION 11: CHECK FOR BACKDOOR USERS
# ============================================

echo "$(date): Checking for unauthorized users..." | tee -a $LOG_FILE

# List all users with UID >= 1000 (regular users)
echo "Regular user accounts:" | tee -a $LOG_FILE
awk -F: '$3 >= 1000 {print $1}' /etc/passwd | tee -a $LOG_FILE

# Check for UID 0 accounts (should ONLY be root)
echo "UID 0 accounts (should only be root):" | tee -a $LOG_FILE
awk -F: '$3 == 0 {print $1}' /etc/passwd | tee -a $LOG_FILE

echo "SUCCESS: User audit complete" | tee -a $LOG_FILE

# ============================================
# SECTION 12: CHECK ACTIVE NETWORK CONNECTIONS
# ============================================

echo "$(date): Checking network connections..." | tee -a $LOG_FILE

# Show listening ports
echo "Listening ports:" | tee -a $LOG_FILE
ss -tlnp 2>/dev/null | tee -a $LOG_FILE

# Show established connections
echo "Established connections:" | tee -a $LOG_FILE
ss -tnp 2>/dev/null | grep ESTAB | tee -a $LOG_FILE

echo "SUCCESS: Network audit complete" | tee -a $LOG_FILE

# ============================================
# SECTION 13: LOCK OTHER USER ACCOUNTS
# ============================================

echo "$(date): Locking other user accounts..." | tee -a $LOG_FILE

# Get all regular users
ALL_USERS=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)

for user in $ALL_USERS; do
    # Don't lock the target user
    if [ "$user" = "$TARGET_USER" ]; then
        echo "SKIP: User $user (that's you!)" | tee -a $LOG_FILE
        continue
    fi
    
    # Lock the account
    passwd -l $user 2>/dev/null
    echo "LOCKED: User $user" | tee -a $LOG_FILE
done

echo "SUCCESS: Other user accounts locked" | tee -a $LOG_FILE

# ============================================
# FINAL SUMMARY
# ============================================

echo ""
echo "=========================================="
echo "System Hardening: COMPLETE"
echo "=========================================="
echo "Backup directory: $BACKUP_DIR"
echo "Log file: $LOG_FILE"
echo ""
echo "Hardening applied:"
echo "  ✓ Password changed for $TARGET_USER (6-digit, not saved)"
echo "  ✓ SSH hardened (no root login, limited auth)"
echo "  ✓ sudo hardened (passwords required, FIXED)"
echo "  ✓ Firewall configured (if UFW available)"
echo "  ✓ Unnecessary services disabled"
echo "  ✓ Kernel hardened (IP spoofing, SYN protection)"
echo "  ✓ Shared memory secured"
echo "  ✓ File permissions secured"
echo "  ✓ Core dumps disabled"
echo "  ✓ Secure umask set"
echo "  ✓ Suspicious files scanned"
echo "  ✓ User accounts audited"
echo "  ✓ Network connections audited"
echo "  ✓ Other user accounts locked"
echo ""
echo "COMPETITION COMPLIANT:"
echo "  ✓ No apt operations"
echo "  ✓ No service version changes"
echo "  ✓ No system reimaging"
echo "  ✓ No network architecture changes"
echo ""
echo "⚠️  REMEMBER: Your new sudo password is the 6-digit number"
echo "    you wrote down at the beginning!"
echo ""
echo "Test sudo now:"
echo "  sudo -k  # Clear sudo cache"
echo "  sudo whoami  # Should prompt for 6-digit password"
echo ""
echo "=========================================="
echo "$(date): System hardening completed" | tee -a $LOG_FILE