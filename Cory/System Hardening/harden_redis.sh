#==============================
# Hardening Redis script
# By: Cory Le
#==============================

# ============================================
# SECTION 1: global vars
# ============================================

NEW_PASWD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)

REDIS_CONFIG_DIR="/etc/redis/redis.conf" # main config file
REDIS_SERVICE_NAME="redis-server" # service name

CREDS_FILE="/opt/blue_scripts/redis_creds.txt" 
SCRIPTS_DIR="/opt/blue_scripts"

FTP_SERVER="" # FTP server IP/host
FTP_USER="" # FTP username
FTP_PASS="" # FTP password
PUBLIC_KEY="" # Public key used for encrypting creds

TIMESTAMP=$(date +Y%m%d_%H%M%S)
BACKUP_NAME="$REDIS_CONFIG_DIR.backup.$TIMESTAMP"

LOG_FILE="/opt/blue_scripts/redis_log.log"


# ============================================
# SECTION 2: backup original config
# ============================================

echo "$(date): Backing up original Redis config..." | tee -a $LOG_FILE

# Check if Redis config exists
if [ ! -f "$REDIS_CONFIG_DIR" ]; then
    echo "ERROR: Redis config not found at $REDIS_CONFIG_DIR" | tee -a $LOG_FILE
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p $SCRIPTS_DIR

# Backup the original config
cp $REDIS_CONFIG_DIR $BACKUP_NAME

# Verify backup was created
if [ -f "$BACKUP_NAME" ]; then
    echo "SUCCESS: Config backed up to $BACKUP_NAME" | tee -a $LOG_FILE
else
    echo "ERROR: Failed to create backup" | tee -a $LOG_FILE
    exit 1
fi

# ============================================
# SECTION 3: NETWORK HARDENING
# ============================================

echo "$(date): Applying network hardening..." | tee -a $LOG_FILE

# Bind to all interfaces (0.0.0.0) for scoring compatibility
# Change to 127.0.0.1 if you want localhost-only
sed -i "s/^bind .*/bind 0.0.0.0/" $REDIS_CONFIG_DIR
grep -q "^bind" $REDIS_CONFIG_DIR || echo "bind 127.0.0.1" >> $REDIS_CONFIG_DIR

# Keep default port 6379 (don't change for scoring safety)
# sed -i "s/^port .*/port 6379/" $REDIS_CONFIG_DIR
# grep -q "^port" $REDIS_CONFIG_DIR || echo "port 6379" >> $REDIS_CONFIG_DIR

# Enable protected mode
sed -i "s/^protected-mode .*/protected-mode yes/" $REDIS_CONFIG_DIR
grep -q "^protected-mode" $REDIS_CONFIG_DIR || echo "protected-mode yes" >> $REDIS_CONFIG_DIR

echo "SUCCESS: Network hardening applied" | tee -a $LOG_FILE

# ============================================
# SECTION 4: SET CREDENTIALS
# ============================================

echo "$(date): Setting Redis password..." | tee -a $LOG_FILE

# Set requirepass in config file
sed -i "s/^# *requirepass .*/requirepass $NEW_PASWD/" $REDIS_CONFIG_DIR
grep -q "^requirepass" $REDIS_CONFIG_DIR || echo "requirepass $NEW_PASWD" >> $REDIS_CONFIG_DIR

# Write password to local file
echo "$NEW_PASWD" > $CREDS_FILE
chmod 600 $CREDS_FILE
chown root:root $CREDS_FILE

echo "SUCCESS: Password set and saved to $CREDS_FILE" | tee -a $LOG_FILE

# ============================================
# SECTION 5: DISABLE ADMIN COMMANDS
# ============================================

echo "$(date): Disabling dangerous Redis commands..." | tee -a $LOG_FILE

# List of dangerous commands to disable
DANGEROUS_CMDS=(
    "FLUSHDB"
    "FLUSHALL"
    "CONFIG"
    "SHUTDOWN"
    "BGREWRITEAOF"
    "BGSAVE"
    "SAVE"
    "DEBUG"
    "SLAVEOF"
    "REPLICAOF"
    "SYNC"
    "MODULE"
    "SCRIPT"
    "EVAL"
    "EVALSHA"
    "KEYS"
    "INFO"
    "SLOWLOG"
    "MONITOR"
)

# Rename each command to empty string (disables it)
for cmd in "${DANGEROUS_CMDS[@]}"; do
    # Remove existing rename-command lines for this command
    sed -i "/^rename-command $cmd/d" $REDIS_CONFIG_DIR
    # Add new rename-command (disable by renaming to "")
    echo "rename-command $cmd \"\"" >> $REDIS_CONFIG_DIR
done

echo "SUCCESS: ${#DANGEROUS_CMDS[@]} dangerous commands disabled" | tee -a $LOG_FILE

# ============================================
# SECTION 6: SET RESOURCE LIMITS
# ============================================

echo "$(date): Setting resource limits..." | tee -a $LOG_FILE

# Set maxmemory (256MB to prevent memory exhaustion)
sed -i "s/^# *maxmemory .*/maxmemory 256mb/" $REDIS_CONFIG_DIR
grep -q "^maxmemory" $REDIS_CONFIG_DIR || echo "maxmemory 256mb" >> $REDIS_CONFIG_DIR

# Set maxmemory policy (evict least recently used keys)
sed -i "s/^# *maxmemory-policy .*/maxmemory-policy allkeys-lru/" $REDIS_CONFIG_DIR
grep -q "^maxmemory-policy" $REDIS_CONFIG_DIR || echo "maxmemory-policy allkeys-lru" >> $REDIS_CONFIG_DIR

# Set client timeout (disconnect idle clients after 5 minutes)
sed -i "s/^timeout .*/timeout 300/" $REDIS_CONFIG_DIR
grep -q "^timeout" $REDIS_CONFIG_DIR || echo "timeout 300" >> $REDIS_CONFIG_DIR

# Set tcp-backlog (prevent connection floods)
sed -i "s/^# *tcp-backlog .*/tcp-backlog 128/" $REDIS_CONFIG_DIR
grep -q "^tcp-backlog" $REDIS_CONFIG_DIR || echo "tcp-backlog 128" >> $REDIS_CONFIG_DIR

echo "SUCCESS: Resource limits configured" | tee -a $LOG_FILE

# ============================================
# SECTION 7: DISABLE PERSISTENCE
# ============================================

echo "$(date): Disabling persistence..." | tee -a $LOG_FILE

# Disable RDB snapshots (comment out all save lines)
sed -i 's/^save /#save /' $REDIS_CONFIG_DIR
# Add explicit save "" to disable
grep -q '^save ""' $REDIS_CONFIG_DIR || echo 'save ""' >> $REDIS_CONFIG_DIR

# Disable AOF (Append Only File)
sed -i "s/^appendonly .*/appendonly no/" $REDIS_CONFIG_DIR
grep -q "^appendonly" $REDIS_CONFIG_DIR || echo "appendonly no" >> $REDIS_CONFIG_DIR

echo "SUCCESS: Persistence disabled (faster, less attack surface)" | tee -a $LOG_FILE
echo "WARNING: If scoring requires persistent data, re-enable RDB/AOF" | tee -a $LOG_FILE

# ============================================
# SECTION 8: RESTART REDIS
# ============================================

echo "$(date): Restarting Redis to apply changes..." | tee -a $LOG_FILE

# Test config syntax before restarting
redis-server $REDIS_CONFIG_DIR --test-config 2>/dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: Redis config syntax error! Restoring backup..." | tee -a $LOG_FILE
    cp $BACKUP_NAME $REDIS_CONFIG_DIR
    echo "ERROR: Hardening failed, original config restored" | tee -a $LOG_FILE
    exit 1
fi

# Restart Redis service
systemctl restart $REDIS_SERVICE_NAME

# Wait for Redis to come up
sleep 2

# Verify Redis is running
systemctl is-active --quiet $REDIS_SERVICE_NAME
if [ $? -eq 0 ]; then
    echo "SUCCESS: Redis restarted successfully" | tee -a $LOG_FILE
else
    echo "ERROR: Redis failed to start! Check logs: journalctl -u $REDIS_SERVICE_NAME" | tee -a $LOG_FILE
    exit 1
fi

# Test connection with new password
redis-cli -a "$NEW_PASWD" ping 2>/dev/null | grep -q "PONG"
if [ $? -eq 0 ]; then
    echo "SUCCESS: Redis responding with new password" | tee -a $LOG_FILE
else
    echo "WARNING: Redis auth test failed (check bind address)" | tee -a $LOG_FILE
fi


# FINAL OUTPUT

echo ""
echo "=========================================="
echo "Redis Hardening: COMPLETE"
echo "=========================================="
echo "Password saved to: $CREDS_FILE"
echo "Config backup: $BACKUP_NAME"
echo "Log file: $LOG_FILE"
echo ""
echo "Current Redis password:"
cat $CREDS_FILE
echo ""
echo "=========================================="
echo "$(date): Redis hardening completed successfully" | tee -a $LOG_FILE

