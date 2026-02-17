# Stephen Graver - 2-16-26
#!/bin/bash

# CONFIG
# The existing password you provided
OLD_DB_PASS="WPDemo456\!"
# new pass
NEW_DB_PASS="SecureCompWordPress2026\!"
# Path to WordPress config
WP_CONFIG="/var/www/html/wp-config.php"
# The database user name (MAY NEED TO CHANGE)
DB_USER="wordpressuser" 
# The user to disable
TARGET_USER="cyberrange"

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try: sudo bash harden.sh"
   exit 1
fi

echo "[+] Starting Hardening Process"

# Update MySQL Password
echo "[*] Updating MySQL password for $DB_USER"
mysql -e "ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$NEW_DB_PASS'; FLUSH PRIVILEGES;"

# Update wp-config.php
if [ -f "$WP_CONFIG" ]; then
    echo "[*] Updating wp-config.php credentials"
    # Specifically finds the line with the old password and swaps it for the new one
    sed -i "s/define(\s*'DB_PASSWORD',\s*'$OLD_DB_PASS'\s*);/define( 'DB_PASSWORD', '$NEW_DB_PASS' );/" "$WP_CONFIG"
    
    # Set File Permissions (Root Read/Write Only)
    echo "[*] Securing wp-config.php permissions"
    chown root:root "$WP_CONFIG"
    chmod 600 "$WP_CONFIG"
    
    # Restart Apache Service
    echo "[*] Restarting Apache to refresh WordPress environment"
    systemctl restart apache2
else
    echo "[!] wp-config.php not found at $WP_CONFIG"
fi

# Disable the "cyberrange" user
if id "$TARGET_USER" &>/dev/null; then
    echo "[*] Disabling user: $TARGET_USER"
    # Lock the password and expire the account
    usermod -L -s /usr/sbin/nologin "$TARGET_USER"
    chage -E 0 "$TARGET_USER"
    # Force logout any active sessions for this user
    pkill -u "$TARGET_USER"
else
    echo "[!] User $TARGET_USER does not exist."
fi

echo "[+] Hardening complete. Deleting script"

# Self-Destruct
# This removes the script from the machine so the passwords aren't left in cleartext
rm -- "$0"