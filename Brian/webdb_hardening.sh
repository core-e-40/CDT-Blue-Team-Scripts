#!/bin/bash
# Team Delta - Svc-webdb-01 SAFE Hardening (v3.0)
# Designed to prevent lockouts and maintain scoring uptime.

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' 

echo -e "${GREEN}--- STARTING SAFE HARDENING ---${NC}"

# 1. SSH & ACCESS SAFETY
echo "[*] Ensuring SSH access is open before we start..."
sudo ufw allow 22/tcp

# 2. USER SECURITY: Reset Root Password
echo "[*] Resetting Root Password..."
read -sp "Enter NEW System Root Password: " SYS_PASS
echo
echo "root:$SYS_PASS" | sudo chpasswd
echo -e "${GREEN}[+] System Root Password Updated.${NC}"

# 3. SSH PURGE: Kill backdoors but keep the door open
echo "[*] Purging SSH Authorized Keys..."
sudo chattr -i /root/.ssh/authorized_keys 2>/dev/null
sudo chattr -i /root/.ssh 2>/dev/null
sudo rm -rf /root/.ssh/authorized_keys
sudo mkdir -p /root/.ssh
sudo chmod 700 /root/.ssh
# We ARE NOT using chattr +i yet, just in case you need to fix something.
echo -e "${GREEN}[+] SSH Backdoors Nuked.${NC}"

# 4. DATABASE: Lockdown MariaDB
echo "[*] Hardening MariaDB..."
read -sp "Enter NEW MariaDB Root Password: " DB_PASS
echo
sudo mariadb -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_PASS';
DROP USER IF EXISTS 'root'@'%';
FLUSH PRIVILEGES;
EOF
echo -e "${GREEN}[+] MariaDB Secured.${NC}"

# 5. ADMINER: Search and Cloak
echo "[*] Hunting for Adminer..."
ADMINER_PATH=$(sudo grep -rl "Adminer" /var/www/ 2>/dev/null | head -n 1)
if [ -z "$ADMINER_PATH" ]; then
    echo -e "${RED}[!] Adminer not found. No action taken.${NC}"
else
    DIR_NAME=$(dirname "$ADMINER_PATH")
    NEW_NAME="db_manage_$(tr -dc A-Za-z0-9 </dev/urandom | head -c 6).php"
    sudo mv "$ADMINER_PATH" "$DIR_NAME/$NEW_NAME"
    echo -e "${GREEN}[+] Adminer moved to: $NEW_NAME${NC}"
fi

# 6. FIREWALL: THE "ULTRA-SAFE" METHOD
echo "[*] Configuring Firewall (Scoring-Safe Mode)..."
sudo ufw --force reset

# Rule A: Allow the local network (Trust your teammates and scorers)
# This detects your current network range (e.g., 10.x.x.x) and trusts it.
LOCAL_NET=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -n 1)
sudo ufw allow from $LOCAL_NET

# Rule B: Explicitly allow Scored Services
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow proto icmp # For Ping

# Rule C: Enable but set default to ALLOW (This is the safety net)
# If we messed up a rule, "default allow" means you aren't locked out.
sudo ufw default allow incoming
sudo ufw --force enable

echo -e "${GREEN}--- HARDENING COMPLETE ---${NC}"
echo -e "NEW ADMINER PATH: ${DIR_NAME}/${NEW_NAME}"