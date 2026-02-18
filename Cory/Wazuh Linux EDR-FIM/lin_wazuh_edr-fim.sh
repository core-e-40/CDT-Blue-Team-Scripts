#!/bin/bash
#==============================
# Configure Wazuh FIM - Linux Agents
# By: Cory Le
# MINIMAL CONFIG - Low risk, easy to test
#==============================

LOG_FILE="/opt/blue_scripts/wazuh_config.log"
WAZUH_SHARED_CONFIG="/var/ossec/etc/shared/default/agent.conf"

echo "$(date): Configuring Wazuh FIM for Linux agents..." | tee -a $LOG_FILE

# ============================================
# SECTION 1: Backup existing config
# ============================================

if [ -f "$WAZUH_SHARED_CONFIG" ]; then
    cp $WAZUH_SHARED_CONFIG ${WAZUH_SHARED_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)
    echo "SUCCESS: Backed up agent config" | tee -a $LOG_FILE
fi

# ============================================
# SECTION 2: Add minimal FIM configuration
# ============================================

# Check if syscheck already configured
if grep -q "<syscheck>" $WAZUH_SHARED_CONFIG 2>/dev/null; then
    echo "WARNING: FIM config already exists, skipping" | tee -a $LOG_FILE
else
    # Add minimal FIM configuration
    cat >> $WAZUH_SHARED_CONFIG <<'EOF'

<!-- Blue Team FIM Configuration - Linux -->
<agent_config os="Linux">
  <syscheck>
    <disabled>no</disabled>
    <frequency>300</frequency>
    
    <!-- Monitor critical directories -->
    <directories check_all="yes">/etc</directories>
    <directories check_all="yes">/usr/bin</directories>
    <directories check_all="yes">/home</directories>
    
    <!-- Ignore noisy files -->
    <ignore>/etc/mtab</ignore>
    <ignore>/etc/hosts.deny</ignore>
    <ignore>/etc/mail/statistics</ignore>
    <ignore>/etc/random-seed</ignore>
    <ignore>/etc/random.seed</ignore>
    <ignore>/etc/adjtime</ignore>
    <ignore>/etc/httpd/logs</ignore>
  </syscheck>
</agent_config>

EOF
    
    echo "SUCCESS: Added FIM configuration" | tee -a $LOG_FILE
fi

# ============================================
# SECTION 3: Restart Wazuh manager
# ============================================

echo "$(date): Restarting Wazuh manager to push config..." | tee -a $LOG_FILE

systemctl restart wazuh-manager

if [ $? -eq 0 ]; then
    echo "SUCCESS: Wazuh manager restarted" | tee -a $LOG_FILE
else
    echo "ERROR: Wazuh manager restart failed!" | tee -a $LOG_FILE
    exit 1
fi

# ============================================
# SECTION 4: Verify (optional)
# ============================================

sleep 5

# Check if manager is running
if systemctl is-active --quiet wazuh-manager; then
    echo "✅ Wazuh manager is running" | tee -a $LOG_FILE
else
    echo "❌ Wazuh manager is NOT running!" | tee -a $LOG_FILE
    exit 1
fi

echo ""
echo "=========================================="
echo "Wazuh FIM Configuration: COMPLETE"
echo "=========================================="
echo "Agents will update their config in ~10 minutes"
echo "Or manually restart agents: systemctl restart wazuh-agent"
echo ""
echo "$(date): Wazuh FIM configuration completed" | tee -a $LOG_FILE