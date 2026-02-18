#!/bin/bash
#==============================
# Setup Password Rotation systemd Timer
# By: Cory Le
#==============================

SCRIPT_PATH="/opt/blue_scripts/rotate_all_passwords.sh"
SERVICE_NAME="password-rotation"

echo "=========================================="
echo "Setting up Password Rotation Timer"
echo "=========================================="

# Check if script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "ERROR: Script not found at $SCRIPT_PATH"
    exit 1
fi

echo "✓ Found rotation script"

# ============================================
# CREATE SERVICE FILE
# ============================================

echo "Creating service file..."

cat > /tmp/${SERVICE_NAME}.service <<EOF
[Unit]
Description=Rotate User Passwords from GitHub Sheets
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
User=root
StandardOutput=journal
StandardError=journal

# Show output in terminal (wall command)
ExecStartPost=/bin/bash -c 'echo "🔄 Password rotation completed at \$(date)" | wall'

[Install]
WantedBy=multi-user.target
EOF

# Install service file
sudo cp /tmp/${SERVICE_NAME}.service /etc/systemd/system/
sudo chmod 644 /etc/systemd/system/${SERVICE_NAME}.service
rm /tmp/${SERVICE_NAME}.service

echo "✓ Service file created"

# ============================================
# CREATE TIMER FILE
# ============================================

echo "Creating timer file..."

cat > /tmp/${SERVICE_NAME}.timer <<EOF
[Unit]
Description=Run password rotation every 5 minutes
Requires=${SERVICE_NAME}.service

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF

# Install timer file
sudo cp /tmp/${SERVICE_NAME}.timer /etc/systemd/system/
sudo chmod 644 /etc/systemd/system/${SERVICE_NAME}.timer
rm /tmp/${SERVICE_NAME}.timer

echo "✓ Timer file created"

# ============================================
# ENABLE AND START
# ============================================

echo "Enabling timer..."

# Reload systemd
sudo systemctl daemon-reload

# Enable timer
sudo systemctl enable ${SERVICE_NAME}.timer

# Start timer
sudo systemctl start ${SERVICE_NAME}.timer

echo "✓ Timer enabled and started"

# ============================================
# VERIFY
# ============================================

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""

# Show timer status
echo "Timer status:"
sudo systemctl status ${SERVICE_NAME}.timer --no-pager | head -10

echo ""
echo "Next run times:"
systemctl list-timers --all | grep ${SERVICE_NAME}

echo ""
echo "=========================================="
echo "Commands:"
echo "  View logs:    sudo journalctl -u ${SERVICE_NAME}.service -f"
echo "  Stop timer:   sudo systemctl stop ${SERVICE_NAME}.timer"
echo "  Start timer:  sudo systemctl start ${SERVICE_NAME}.timer"
echo "  Check status: systemctl status ${SERVICE_NAME}.timer"
echo "=========================================="
echo ""
echo "✅ Password rotation will run every 5 minutes"
echo "✅ Terminal notifications enabled (wall command)"
echo ""