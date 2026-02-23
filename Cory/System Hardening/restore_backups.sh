#!/bin/bash
#==============================
# Restore Apache/Redis from Backup
# By: Cory Le
#==============================

BACKUP_DIR="/var/cache/.systemd-private"

echo "========================================"
echo "Available Backups"
echo "========================================"
echo ""
echo "Apache backups:"
ls -lht $BACKUP_DIR/apache2_backup_*.tar.gz 2>/dev/null | head -5
echo ""
echo "Redis backups:"
ls -lht $BACKUP_DIR/redis_backup_*.tar.gz 2>/dev/null | head -5
echo ""

# ============================================
# RESTORE APACHE
# ============================================

echo "========================================"
echo "Restore Apache?"
echo "========================================"
read -p "Enter 'yes' to restore Apache from latest backup: " RESTORE_APACHE

if [ "$RESTORE_APACHE" = "yes" ]; then
    # Get latest Apache backup
    LATEST_APACHE=$(ls -t $BACKUP_DIR/apache2_backup_*.tar.gz 2>/dev/null | head -1)
    
    if [ -z "$LATEST_APACHE" ]; then
        echo "[✗] No Apache backup found!"
    else
        echo "[*] Restoring from: $LATEST_APACHE"
        
        # Stop Apache
        systemctl stop apache2 2>/dev/null
        
        # Restore backup
        tar -xzf "$LATEST_APACHE" -C /
        
        if [ $? -eq 0 ]; then
            echo "[✓] Apache config restored"
            
            # Restart Apache
            systemctl start apache2
            systemctl status apache2 --no-pager
        else
            echo "[✗] Apache restore failed!"
        fi
    fi
else
    echo "[*] Skipping Apache restore"
fi

# ============================================
# RESTORE REDIS
# ============================================

echo ""
echo "========================================"
echo "Restore Redis?"
echo "========================================"
read -p "Enter 'yes' to restore Redis from latest backup: " RESTORE_REDIS

if [ "$RESTORE_REDIS" = "yes" ]; then
    # Get latest Redis backup
    LATEST_REDIS=$(ls -t $BACKUP_DIR/redis_backup_*.tar.gz 2>/dev/null | head -1)
    
    if [ -z "$LATEST_REDIS" ]; then
        echo "[✗] No Redis backup found!"
    else
        echo "[*] Restoring from: $LATEST_REDIS"
        
        # Detect Redis service name
        if systemctl list-units --type=service 2>/dev/null | grep -q "redis-server.service"; then
            REDIS_SERVICE="redis-server"
        else
            REDIS_SERVICE="redis"
        fi
        
        # Stop Redis
        systemctl stop $REDIS_SERVICE 2>/dev/null
        pkill -9 redis-server 2>/dev/null
        sleep 1
        
        # Restore backup
        tar -xzf "$LATEST_REDIS" -C /
        
        if [ $? -eq 0 ]; then
            echo "[✓] Redis config and data restored"
            
            # Restore credentials if they exist
            LATEST_CREDS=$(ls -t $BACKUP_DIR/redis_creds_*.txt 2>/dev/null | head -1)
            if [ -n "$LATEST_CREDS" ]; then
                mkdir -p /opt/blue_scripts
                cp "$LATEST_CREDS" /opt/blue_scripts/redis_creds.txt
                chmod 600 /opt/blue_scripts/redis_creds.txt
                echo "[✓] Redis credentials restored"
            fi
            
            # Restart Redis
            systemctl start $REDIS_SERVICE
            systemctl status $REDIS_SERVICE --no-pager
        else
            echo "[✗] Redis restore failed!"
        fi
    fi
else
    echo "[*] Skipping Redis restore"
fi

echo ""
echo "========================================"
echo "Restore complete!"
echo "========================================"