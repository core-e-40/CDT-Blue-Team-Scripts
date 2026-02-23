#!/bin/bash
#==============================
# Backup All Critical Services
# By: Cory Le
#==============================

BACKUP_DIR="/var/cache/.systemd-private"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "========================================"
echo "Starting backup: $(date)"
echo "========================================"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR
chmod 700 $BACKUP_DIR
chown root:root $BACKUP_DIR

# ============================================
# BACKUP APACHE
# ============================================

echo ""
echo "[*] Backing up Apache configuration..."

APACHE_CONFIG_DIR="/etc/apache2"
APACHE_BACKUP_NAME="apache2_backup_$TIMESTAMP.tar.gz"

tar -czf "$BACKUP_DIR/$APACHE_BACKUP_NAME" $APACHE_CONFIG_DIR 2>/dev/null

if [ -f "$BACKUP_DIR/$APACHE_BACKUP_NAME" ]; then
    echo "[✓] Apache backup successful: $BACKUP_DIR/$APACHE_BACKUP_NAME"
    echo "[*] Backup size: $(du -h "$BACKUP_DIR/$APACHE_BACKUP_NAME" | cut -f1)"
    chmod 600 "$BACKUP_DIR/$APACHE_BACKUP_NAME"
else
    echo "[✗] Apache backup failed!"
fi

# ============================================
# BACKUP REDIS
# ============================================

echo ""
echo "[*] Backing up Redis configuration and data..."

REDIS_CONFIG="/etc/redis/redis.conf"
REDIS_DATA_DIR="/var/lib/redis"
REDIS_BACKUP_NAME="redis_backup_$TIMESTAMP.tar.gz"

tar -czf "$BACKUP_DIR/$REDIS_BACKUP_NAME" $REDIS_CONFIG $REDIS_DATA_DIR 2>/dev/null

if [ -f "$BACKUP_DIR/$REDIS_BACKUP_NAME" ]; then
    echo "[✓] Redis backup successful: $BACKUP_DIR/$REDIS_BACKUP_NAME"
    echo "[*] Backup size: $(du -h "$BACKUP_DIR/$REDIS_BACKUP_NAME" | cut -f1)"
    chmod 600 "$BACKUP_DIR/$REDIS_BACKUP_NAME"
else
    echo "[✗] Redis backup failed!"
fi

# Also save Redis password if it exists
REDIS_CREDS="/opt/blue_scripts/redis_creds.txt"
if [ -f "$REDIS_CREDS" ]; then
    cp $REDIS_CREDS "$BACKUP_DIR/redis_creds_$TIMESTAMP.txt"
    chmod 600 "$BACKUP_DIR/redis_creds_$TIMESTAMP.txt"
    echo "[✓] Redis credentials backed up"
fi

# ============================================
# SUMMARY
# ============================================

echo ""
echo "========================================"
echo "All backups complete!"
echo "========================================"
echo "Backup location: $BACKUP_DIR"
echo ""
echo "Files created:"
ls -lh $BACKUP_DIR/*$TIMESTAMP* 2>/dev/null
echo ""
echo "To restore Apache:"
echo "  tar -xzf $BACKUP_DIR/$APACHE_BACKUP_NAME -C /"
echo ""
echo "To restore Redis:"
echo "  tar -xzf $BACKUP_DIR/$REDIS_BACKUP_NAME -C /"
echo ""