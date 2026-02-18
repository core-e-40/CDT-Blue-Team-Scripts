#!/bin/bash
# Team Delta - Svc-webdb-01 FINAL Hardening
# Fixed: MariaDB Authentication & Firewall Network Detection

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' 

echo -e "${GREEN}--- STARTING FINAL HARDENING ---${NC}"

# 1. USER SECURITY: System Root Password
echo "[*] Resetting System Root Password..."
read -sp "Enter NEW System Root Password: " SYS_PASS
echo
echo "root:$SYS_PASS" | sudo chpasswd
echo -e "${GREEN}[+] System Root Password Updated.${NC}"

# 2. SSH PURGE
echo "[*] Purging SSH Authorized Keys..."
sudo chattr -i /root/.ssh/authorized_keys 2>/dev/null
sudo chattr -i /root/.ssh 2>/dev/null
sudo rm -rf /root/.ssh/authorized_keys
sudo mkdir -p /root/.ssh
sudo chmod 700 /root/.ssh
echo -e "${GREEN}[+] SSH Backdoors Nuked.${NC}"

# 3. DATABASE: Smart-Login Hardening
echo "[*] Hardening MariaDB..."
read -sp "Enter CURRENT MariaDB Root Password (Press Enter if none): " OLD_DB_PASS
echo
read -sp "Enter NEW MariaDB Root Password: " NEW_DB_PASS
echo

# Using -p directly with the variable (no space) handles the 'Access Denied' error
sudo mariadb -u root -p"$OLD_DB_PASS" <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$NEW_DB_PASS';
DROP USER IF EXISTS 'root'@'%';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[+] MariaDB Secured Successfully.${NC}"
else
    echo -e "${RED}[!] MariaDB FAILED. Manual intervention required.${NC}"
fi

# 4. ADMINER: Search and Cloak
echo "[*] Hunting for Adminer..."
ADMINER_PATH=$(sudo grep -rl "Adminer" /var/www/ 2>/dev/null | head -n 1)
if [ -z "$ADMINER_PATH" ]; then
    echo -e "${RED}[!] Adminer not found.${NC}"
else
    DIR_NAME=$(dirname "$ADMINER_PATH")
    NEW_NAME="db_manage_$(tr -dc A-Za-z0-9 </dev/urandom | head -c 6).php"
    sudo mv "$ADMINER_PATH" "$DIR_NAME/$NEW_NAME"
    echo -e "${GREEN}[+] Adminer cloaked to: $NEW_NAME${NC}"
fi

# 5. FIREWALL: Fixed Scoring-Safe Shield
echo "[*] Configuring Firewall..."
sudo ufw --force reset

# Standard rules
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp
sudo ufw allow proto icmp

# FIXED: More robust way to find the local subnet to prevent "Need to/from clause" error
# This grabs the IP and masks it to /24 (the most common subnet size)
LOCAL_IP=$(hostname -I | awk '{print $1}')
SUBNET="${LOCAL_IP%.*}.0/24"

if [[ $SUBNET =~ ^[0-9]+\.[0-9]+\.[0-9]+\.0/24$ ]]; then
    sudo ufw allow from "$SUBNET"
    echo -e "${GREEN}[+] Trusted Local Subnet: $SUBNET${NC}"
else
    # Fallback to trusting the whole 10.0.0.0/8 range if detection fails
    sudo ufw allow from 10.0.0.0/8
    echo -e "${RED}[!] Subnet detection failed, defaulting to 10.0.0.0/8 trust.${NC}"
fi

sudo ufw default allow incoming
sudo ufw --force enable
echo -e "${GREEN}[+] Firewall Active.${NC}"

echo -e "${GREEN}--- HARDENING COMPLETE ---${NC}"
echo -e "Share this in Discord: http://[Your-IP]/$NEW_NAME"