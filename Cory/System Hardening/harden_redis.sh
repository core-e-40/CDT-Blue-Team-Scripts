#!/bin/bash
#==============================
# Hardening Redis script
# By: Cory Le
#==============================

# ============================================
# SECTION 1: GLOBAL VARS & PRE-FLIGHT CHECKS
# ============================================

NEW_PASWD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)

REDIS_CONFIG_DIR="/etc/redis/redis.conf"
CREDS_FILE="/opt/blue_scripts/redis_creds.txt" 
SCRIPTS_DIR="/opt/blue_scripts"

# Hidden backup directory
HIDDEN_BACKUP_DIR="/var/cache/.systemd-private"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="$REDIS_CONFIG_DIR.backup.$TIMESTAMP"
HIDDEN_CREDS_BACKUP="$HIDDEN_BACKUP_DIR/redis_creds_$TIMESTAMP.txt"

LOG_FILE="/opt/blue_scripts/redis_log.log"

# Create log directory
mkdir -p /opt/blue_scripts
touch $LOG_FILE

echo "$(date): Starting Redis hardening..." | tee -a $LOG_FILE

# ============================================
# SECTION 1.5: AUTO-DETECT REDIS SERVICE
# ============================================

echo "$(date): Detecting Redis service name..." | tee -a $LOG_FILE

if systemctl list-units --type=service 2>/dev/null | grep -q "redis-server.service"; then
    REDIS_SERVICE_NAME="redis-server"
    echo "SUCCESS: Detected service: redis-server" | tee -a $LOG_FILE
elif systemctl list-units --type=service 2>/dev/null | grep -q "redis.service"; then
    REDIS_SERVICE_NAME="redis"
    echo "SUCCESS: Detected service: redis" | tee -a $LOG_FILE
else
    echo "ERROR: Could not detect Redis service name" | tee -a $LOG_FILE
    echo "Manual check: systemctl list-units --type=service | grep redis" | tee -a $LOG_FILE
    exit 1
fi

# ============================================
# SECTION 1.6: CHECK REDIS IS INSTALLED
# ============================================

if ! command -v redis-server &> /dev/null; then
    echo "ERROR: redis-server command not found. Is Redis installed?" | tee -a $LOG_FILE
    exit 1
fi

if ! command -v redis-cli &> /dev/null; then
    echo "ERROR: redis-cli command not found. Is Redis installed?" | tee -a $LOG_FILE
    exit 1
fi

echo "SUCCESS: Redis binaries found" | tee -a $LOG_FILE

# ============================================
# SECTION 2: BACKUP ORIGINAL CONFIG
# ============================================

echo "$(date): Backing up original Redis config..." | tee -a $LOG_FILE

# Check if Redis config exists
if [ ! -f "$REDIS_CONFIG_DIR" ]; then
    echo "ERROR: Redis config not found at $REDIS_CONFIG_DIR" | tee -a $LOG_FILE
    # Try alternative location
    if [ -f "/etc/redis.conf" ]; then
        REDIS_CONFIG_DIR="/etc/redis.conf"
        echo "Found Redis config at /etc/redis.conf instead" | tee -a $LOG_FILE
    else
        echo "ERROR: Cannot find Redis config file" | tee -a $LOG_FILE
        exit 1
    fi
fi

# Create backup directories if they don't exist
mkdir -p $SCRIPTS_DIR
mkdir -p $HIDDEN_BACKUP_DIR
chmod 700 $HIDDEN_BACKUP_DIR
chown root:root $HIDDEN_BACKUP_DIR

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
# SECTION 2.5: CLEAN OLD HARDENING
# ============================================

echo "$(date): Removing any previous hardening configurations..." | tee -a $LOG_FILE

# Remove all old rename-command lines (prevents duplicates)
sed -i '/^rename-command/d' $REDIS_CONFIG_DIR

# Remove duplicate requirepass lines
REQUIREPASS_COUNT=$(grep -c "^requirepass" $REDIS_CONFIG_DIR)
if [ "$REQUIREPASS_COUNT" -gt 1 ]; then
    echo "Found $REQUIREPASS_COUNT requirepass lines, removing duplicates..." | tee -a $LOG_FILE
    awk '!seen["requirepass"]++ || !/^requirepass/' $REDIS_CONFIG_DIR > /tmp/redis_dedup.conf
    mv /tmp/redis_dedup.conf $REDIS_CONFIG_DIR
fi

# Remove duplicate bind lines
BIND_COUNT=$(grep -c "^bind" $REDIS_CONFIG_DIR)
if [ "$BIND_COUNT" -gt 1 ]; then
    echo "Found $BIND_COUNT bind lines, removing duplicates..." | tee -a $LOG_FILE
    awk '!seen["bind"]++ || !/^bind/' $REDIS_CONFIG_DIR > /tmp/redis_dedup.conf
    mv /tmp/redis_dedup.conf $REDIS_CONFIG_DIR
fi

# Remove duplicate port lines
PORT_COUNT=$(grep -c "^port" $REDIS_CONFIG_DIR)
if [ "$PORT_COUNT" -gt 1 ]; then
    echo "Found $PORT_COUNT port lines, removing duplicates..." | tee -a $LOG_FILE
    awk '!seen["port"]++ || !/^port/' $REDIS_CONFIG_DIR > /tmp/redis_dedup.conf
    mv /tmp/redis_dedup.conf $REDIS_CONFIG_DIR
fi

# Remove duplicate protected-mode lines
PROTECTED_COUNT=$(grep -c "^protected-mode" $REDIS_CONFIG_DIR)
if [ "$PROTECTED_COUNT" -gt 1 ]; then
    echo "Found $PROTECTED_COUNT protected-mode lines, removing duplicates..." | tee -a $LOG_FILE
    awk '!seen["protected-mode"]++ || !/^protected-mode/' $REDIS_CONFIG_DIR > /tmp/redis_dedup.conf
    mv /tmp/redis_dedup.conf $REDIS_CONFIG_DIR
fi

echo "SUCCESS: Cleaned old configurations" | tee -a $LOG_FILE

# ============================================
# SECTION 3: NETWORK HARDENING
# ============================================

echo "$(date): Applying network hardening..." | tee -a $LOG_FILE

# Remove existing bind lines, then add new one
sed -i '/^bind/d' $REDIS_CONFIG_DIR
echo "bind 127.0.0.1" >> $REDIS_CONFIG_DIR

# Remove existing port lines, then add new one
sed -i '/^port/d' $REDIS_CONFIG_DIR
echo "port 6379" >> $REDIS_CONFIG_DIR

# Remove existing protected-mode lines, then add new one
sed -i '/^protected-mode/d' $REDIS_CONFIG_DIR
echo "protected-mode yes" >> $REDIS_CONFIG_DIR

echo "SUCCESS: Network hardening applied (Redis bound to localhost)" | tee -a $LOG_FILE

# ============================================
# SECTION 4: SET CREDENTIALS
# ============================================

echo "$(date): Setting Redis password..." | tee -a $LOG_FILE

# Remove existing requirepass lines, then add new one
sed -i '/^requirepass/d' $REDIS_CONFIG_DIR
sed -i '/^# *requirepass/d' $REDIS_CONFIG_DIR
echo "requirepass $NEW_PASWD" >> $REDIS_CONFIG_DIR

# Write password to local file
echo "$NEW_PASWD" > $CREDS_FILE
chmod 600 $CREDS_FILE
chown root:root $CREDS_FILE

# Write to hidden backup
echo "$NEW_PASWD" > $HIDDEN_CREDS_BACKUP
chmod 600 $HIDDEN_CREDS_BACKUP
chown root:root $HIDDEN_CREDS_BACKUP

echo "SUCCESS: Password set and saved to $CREDS_FILE" | tee -a $LOG_FILE
echo "SUCCESS: Password backup saved to hidden location" | tee -a $LOG_FILE

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

# Add rename-command lines (already cleaned duplicates in Section 2.5)
for cmd in "${DANGEROUS_CMDS[@]}"; do
    echo "rename-command $cmd \"\"" >> $REDIS_CONFIG_DIR
done

echo "SUCCESS: ${#DANGEROUS_CMDS[@]} dangerous commands disabled" | tee -a $LOG_FILE

# ============================================
# SECTION 6: SET RESOURCE LIMITS
# ============================================

echo "$(date): Setting resource limits..." | tee -a $LOG_FILE

# Remove existing maxmemory lines, then add new one
sed -i '/^maxmemory/d' $REDIS_CONFIG_DIR
sed -i '/^# *maxmemory /d' $REDIS_CONFIG_DIR
echo "maxmemory 256mb" >> $REDIS_CONFIG_DIR

# Remove existing maxmemory-policy lines, then add new one
sed -i '/^maxmemory-policy/d' $REDIS_CONFIG_DIR
sed -i '/^# *maxmemory-policy/d' $REDIS_CONFIG_DIR
echo "maxmemory-policy allkeys-lru" >> $REDIS_CONFIG_DIR

# Remove existing timeout lines, then add new one
sed -i '/^timeout/d' $REDIS_CONFIG_DIR
echo "timeout 300" >> $REDIS_CONFIG_DIR

# Remove existing tcp-backlog lines, then add new one
sed -i '/^tcp-backlog/d' $REDIS_CONFIG_DIR
sed -i '/^# *tcp-backlog/d' $REDIS_CONFIG_DIR
echo "tcp-backlog 128" >> $REDIS_CONFIG_DIR

echo "SUCCESS: Resource limits configured" | tee -a $LOG_FILE

# ============================================
# SECTION 7: DISABLE PERSISTENCE
# ============================================

echo "$(date): Disabling persistence..." | tee -a $LOG_FILE

# Comment out all existing save lines
sed -i 's/^save /#save /' $REDIS_CONFIG_DIR

# Remove any existing 'save ""' lines to prevent duplicates
sed -i '/^save ""/d' $REDIS_CONFIG_DIR

# Add explicit save "" to disable
echo 'save ""' >> $REDIS_CONFIG_DIR

# Remove existing appendonly lines, then add new one
sed -i '/^appendonly/d' $REDIS_CONFIG_DIR
echo "appendonly no" >> $REDIS_CONFIG_DIR

echo "SUCCESS: Persistence disabled (faster, less attack surface)" | tee -a $LOG_FILE
echo "WARNING: If scoring requires persistent data, re-enable RDB/AOF" | tee -a $LOG_FILE

# ============================================
# SECTION 8: PRE-RESTART CHECKS
# ============================================

echo "$(date): Running pre-restart checks..." | tee -a $LOG_FILE

# Stop Redis service before restarting (clean slate)
echo "$(date): Stopping existing Redis service..." | tee -a $LOG_FILE
systemctl stop $REDIS_SERVICE_NAME 2>/dev/null

# Kill any orphaned Redis processes
REDIS_PIDS=$(pgrep redis-server)
if [ -n "$REDIS_PIDS" ]; then
    echo "WARNING: Found orphaned Redis processes: $REDIS_PIDS" | tee -a $LOG_FILE
    echo "Killing orphaned processes..." | tee -a $LOG_FILE
    pkill -9 redis-server
    sleep 1
fi

# Verify port is now free
if ss -tlnp 2>/dev/null | grep -q ":6379"; then
    echo "ERROR: Port 6379 is still in use after cleanup!" | tee -a $LOG_FILE
    ss -tlnp 2>/dev/null | grep ":6379" | tee -a $LOG_FILE
    echo "Cannot proceed with Redis restart" | tee -a $LOG_FILE
    exit 1
fi

echo "SUCCESS: Port 6379 is free" | tee -a $LOG_FILE

# ============================================
# SECTION 9: TEST CONFIG SYNTAX
# ============================================

echo "$(date): Testing Redis config syntax..." | tee -a $LOG_FILE

# Test config syntax - FIXED: Use a temporary test instead of --test-config flag
redis-server $REDIS_CONFIG_DIR > /tmp/redis_test.log 2>&1 &
REDIS_TEST_PID=$!
sleep 2

# Check if Redis started successfully
if ps -p $REDIS_TEST_PID > /dev/null; then
    kill $REDIS_TEST_PID 2>/dev/null
    wait $REDIS_TEST_PID 2>/dev/null
    echo "SUCCESS: Config syntax is valid" | tee -a $LOG_FILE
else
    echo "ERROR: Redis config has errors!" | tee -a $LOG_FILE
    cat /tmp/redis_test.log | tee -a $LOG_FILE
    echo "Restoring backup..." | tee -a $LOG_FILE
    cp $BACKUP_NAME $REDIS_CONFIG_DIR
    echo "ERROR: Hardening failed, original config restored" | tee -a $LOG_FILE
    exit 1
fi

rm -f /tmp/redis_test.log

# ============================================
# SECTION 10: RESTART REDIS
# ============================================

echo "$(date): Starting Redis service..." | tee -a $LOG_FILE

# Start Redis service
systemctl start $REDIS_SERVICE_NAME

# Wait for Redis to start
sleep 3

# Check if service is active
if ! systemctl is-active --quiet $REDIS_SERVICE_NAME; then
    echo "ERROR: Redis service failed to start!" | tee -a $LOG_FILE
    echo "Checking systemd status..." | tee -a $LOG_FILE
    systemctl status $REDIS_SERVICE_NAME --no-pager | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    echo "Checking Redis logs..." | tee -a $LOG_FILE
    journalctl -u $REDIS_SERVICE_NAME -n 30 --no-pager | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    echo "Restoring backup config..." | tee -a $LOG_FILE
    cp $BACKUP_NAME $REDIS_CONFIG_DIR
    systemctl start $REDIS_SERVICE_NAME
    echo "ERROR: Hardening failed, service restored to original state" | tee -a $LOG_FILE
    exit 1
fi

echo "SUCCESS: Redis service started" | tee -a $LOG_FILE

# ============================================
# SECTION 11: VERIFY REDIS IS WORKING
# ============================================

echo "$(date): Verifying Redis is responding..." | tee -a $LOG_FILE

# Test connection with new password
PING_RESULT=$(redis-cli -a "$NEW_PASWD" ping 2>/dev/null)

if [ "$PING_RESULT" = "PONG" ]; then
    echo "SUCCESS: Redis responding with new password (PONG received)" | tee -a $LOG_FILE
else
    echo "WARNING: Redis auth test failed (expected PONG, got: $PING_RESULT)" | tee -a $LOG_FILE
    echo "Checking if Redis is bound to localhost..." | tee -a $LOG_FILE
    
    # Try without password to see if auth is the issue
    NO_AUTH_TEST=$(redis-cli ping 2>&1)
    if echo "$NO_AUTH_TEST" | grep -q "NOAUTH"; then
        echo "INFO: Redis requires auth (this is correct)" | tee -a $LOG_FILE
    else
        echo "WARNING: Unexpected response: $NO_AUTH_TEST" | tee -a $LOG_FILE
    fi
fi

# Check Redis is listening on correct port
if ss -tlnp 2>/dev/null | grep -q "127.0.0.1:6379.*redis-server"; then
    echo "SUCCESS: Redis is listening on 127.0.0.1:6379" | tee -a $LOG_FILE
else
    echo "WARNING: Redis may not be bound to localhost correctly" | tee -a $LOG_FILE
    ss -tlnp 2>/dev/null | grep redis-server | tee -a $LOG_FILE
fi

# ============================================
# FINAL OUTPUT
# ============================================

echo ""
echo "=========================================="
echo "Redis Hardening: COMPLETE"
echo "=========================================="
echo "Password saved to: $CREDS_FILE"
echo "Hidden backup: $HIDDEN_BACKUP_DIR"
echo "Config backup: $BACKUP_NAME"
echo "Log file: $LOG_FILE"
echo ""
echo "Current Redis password:"
cat $CREDS_FILE
echo ""
echo "To retrieve hidden backup: cat $HIDDEN_CREDS_BACKUP"
echo ""
echo "Verification commands:"
echo "  Check service: systemctl status $REDIS_SERVICE_NAME"
echo "  Test connection: redis-cli -a \"\$(cat $CREDS_FILE)\" ping"
echo "  View logs: journalctl -u $REDIS_SERVICE_NAME -n 50"
echo ""
echo "=========================================="
echo "$(date): Redis hardening completed successfully" | tee -a $LOG_FILE