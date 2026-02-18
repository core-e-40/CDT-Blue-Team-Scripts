#!/bin/bash
# MariaDB Initial Hardening

read -sp "Enter New Secure DB Password: " DB_PASS
echo

echo "[*] Applying Root Password and Restricting to Localhost..."
sudo mariadb -u root <<EOF
-- Set the root password
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_PASS';
-- Delete the 'anywhere' root if it exists
DROP USER IF EXISTS 'root'@'%';
-- Create a fresh local root just in case
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

echo "[+] Database Secured."