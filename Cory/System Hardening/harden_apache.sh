#==============================
# Hardening Apache script
# By: Cory Le
#==============================

#==============================
# Section 1: global vars
#==============================

# Apache Configuration
APACHE_CONF="/etc/apache2/apache2.conf"           # Main config (Debian/Ubuntu)
APACHE_SECURITY_CONF="/etc/apache2/conf-available/security.conf"  # Security settings
APACHE_SERVICE=""                          # Service name (use "httpd" for RHEL/CentOS)
APACHE_SITES_AVAILABLE="/etc/apache2/sites-available"

# Web Application Paths
WEB_ROOT="/var/www/html"                          # Document root
APP_CONFIG="$WEB_ROOT/config.php"                 # App config file (adjust to your app)
HTPASSWD_FILE="/etc/apache2/.htpasswd"            # HTTP Basic Auth file

# Credentials
NEW_HTPASSWD_USER="admin"
NEW_HTPASSWD_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24)

# File Paths
SCRIPTS_DIR="/opt/blue_scripts"
CREDS_FILE="$SCRIPTS_DIR/apache_creds.txt"
LOG_FILE="$SCRIPTS_DIR/apache_log.log"

# FTP Configuration (for encrypted backup)
FTP_SERVER=""                                     # Fill in your FTP server
FTP_USER=""                                       # Fill in your FTP username
FTP_PASS=""                                       # Fill in your FTP password

# Backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
APACHE_BACKUP="$APACHE_CONF.backup.$TIMESTAMP"
SECURITY_BACKUP="$APACHE_SECURITY_CONF.backup.$TIMESTAMP"

echo "$(date): Starting Apache hardening..." | tee -a $LOG_FILE

#==============================
# Section 2: Backup original config
#==============================

echo "$(date): Backing up Apache configs..." | tee -a $LOG_FILE

# Create backup directory
mkdir -p $SCRIPTS_DIR

# Backup main Apache config
if [ -f "$APACHE_CONF" ]; then
    cp $APACHE_CONF $APACHE_BACKUP
    echo "SUCCESS: Backed up $APACHE_CONF" | tee -a $LOG_FILE
else
    echo "WARNING: $APACHE_CONF not found" | tee -a $LOG_FILE
fi

# Backup security config
if [ -f "$APACHE_SECURITY_CONF" ]; then
    cp $APACHE_SECURITY_CONF $SECURITY_BACKUP
    echo "SUCCESS: Backed up $APACHE_SECURITY_CONF" | tee -a $LOG_FILE
else
    echo "WARNING: $APACHE_SECURITY_CONF not found" | tee -a $LOG_FILE
fi

# ============================================
# SECTION 3: CHANGE CREDENTIALS
# ============================================

echo "$(date): Changing Apache credentials..." | tee -a $LOG_FILE

# Update .htpasswd (HTTP Basic Auth)
if command -v htpasswd &> /dev/null; then
    # Create/update .htpasswd file
    htpasswd -cb $HTPASSWD_FILE $NEW_HTPASSWD_USER "$NEW_HTPASSWD_PASS"
    chmod 640 $HTPASSWD_FILE
    chown root:www-data $HTPASSWD_FILE
    echo "SUCCESS: .htpasswd updated for user $NEW_HTPASSWD_USER" | tee -a $LOG_FILE
else
    echo "WARNING: htpasswd command not found, skipping .htpasswd update" | tee -a $LOG_FILE
fi

# Save credentials to file
cat > $CREDS_FILE <<EOF
Apache HTTP Basic Auth:
Username: $NEW_HTPASSWD_USER
Password: $NEW_HTPASSWD_PASS

Generated: $(date)
EOF

chmod 600 $CREDS_FILE
chown root:root $CREDS_FILE

echo "SUCCESS: Credentials saved to $CREDS_FILE" | tee -a $LOG_FILE
# Note: Skipping encryption/FTP for now (can add later if needed)

# ============================================
# SECTION 4: DISABLE DANGEROUS MODULES
# ============================================

echo "$(date): Disabling dangerous Apache modules..." | tee -a $LOG_FILE

# List of modules to disable
DANGEROUS_MODULES=(
    "userdir"      # Exposes user home directories
    "autoindex"    # Directory listing
    "status"       # Server status page
    "info"         # Server info page
)

# Disable each module
for mod in "${DANGEROUS_MODULES[@]}"; do
    if a2query -m $mod &> /dev/null; then
        a2dismod $mod &> /dev/null
        echo "  - Disabled module: $mod" | tee -a $LOG_FILE
    fi
done

echo "SUCCESS: Dangerous modules disabled" | tee -a $LOG_FILE

# ============================================
# SECTION 5: HIDE SERVER INFORMATION
# ============================================

echo "$(date): Hiding server information..." | tee -a $LOG_FILE

# Update security.conf
if [ -f "$APACHE_SECURITY_CONF" ]; then
    # ServerTokens Prod (hide version info)
    sed -i "s/^ServerTokens .*/ServerTokens Prod/" $APACHE_SECURITY_CONF
    grep -q "^ServerTokens" $APACHE_SECURITY_CONF || echo "ServerTokens Prod" >> $APACHE_SECURITY_CONF
    
    # ServerSignature Off (hide signature in error pages)
    sed -i "s/^ServerSignature .*/ServerSignature Off/" $APACHE_SECURITY_CONF
    grep -q "^ServerSignature" $APACHE_SECURITY_CONF || echo "ServerSignature Off" >> $APACHE_SECURITY_CONF
    
    echo "SUCCESS: Server information hidden" | tee -a $LOG_FILE
else
    echo "WARNING: Security config not found, manually set ServerTokens/ServerSignature" | tee -a $LOG_FILE
fi

# Remove X-Powered-By header (PHP version leak)
if [ -f "/etc/php/7.4/apache2/php.ini" ]; then
    sed -i "s/^expose_php = .*/expose_php = Off/" /etc/php/7.4/apache2/php.ini
fi
# Also check PHP 8.x paths
for php_ini in /etc/php/*/apache2/php.ini; do
    if [ -f "$php_ini" ]; then
        sed -i "s/^expose_php = .*/expose_php = Off/" $php_ini
    fi
done

# ============================================
# SECTION 6: RESTRICT FILE ACCESS
# ============================================

echo "$(date): Restricting file access..." | tee -a $LOG_FILE

# Create security rules file
cat > /etc/apache2/conf-available/file-restrictions.conf <<'EOF'
# Block access to sensitive files
<FilesMatch "^\.">
    Require all denied
</FilesMatch>

<FilesMatch "\.(git|env|htaccess|htpasswd|sql|bak|backup|old|swp|tmp)$">
    Require all denied
</FilesMatch>

<DirectoryMatch "/\.git">
    Require all denied
</DirectoryMatch>

# Disable directory browsing
<Directory /var/www/html>
    Options -Indexes
</Directory>
EOF

# Enable the configuration
a2enconf file-restrictions &> /dev/null

echo "SUCCESS: File access restrictions applied" | tee -a $LOG_FILE

# ============================================
# SECTION 7: LIMIT HTTP METHODS
# ============================================

echo "$(date): Limiting HTTP methods..." | tee -a $LOG_FILE

# Create HTTP methods restriction file
cat > /etc/apache2/conf-available/http-methods.conf <<'EOF'
# Only allow GET, POST, HEAD
<Directory /var/www/html>
    <LimitExcept GET POST HEAD>
        Require all denied
    </LimitExcept>
</Directory>

# Disable TRACE method (prevents XST attacks)
TraceEnable off
EOF

# Enable the configuration
a2enconf http-methods &> /dev/null

echo "SUCCESS: HTTP methods limited to GET, POST, HEAD" | tee -a $LOG_FILE

# ============================================
# SECTION 8: SET RESOURCE LIMITS
# ============================================

echo "$(date): Setting resource limits..." | tee -a $LOG_FILE

# Create resource limits file
cat > /etc/apache2/conf-available/resource-limits.conf <<'EOF'
# Prevent slowloris attacks
Timeout 60
KeepAliveTimeout 5

# Limit request body size (10MB)
LimitRequestBody 10485760

# Limit request fields
LimitRequestFields 100
LimitRequestFieldSize 8190

# Connection limits
MaxKeepAliveRequests 100
EOF

# Enable the configuration
a2enconf resource-limits &> /dev/null

echo "SUCCESS: Resource limits configured" | tee -a $LOG_FILE

# ============================================
# SECTION 9: ADD SECURITY HEADERS
# ============================================

echo "$(date): Adding security headers..." | tee -a $LOG_FILE

# Enable headers module
a2enmod headers &> /dev/null

# Create security headers file
cat > /etc/apache2/conf-available/security-headers.conf <<'EOF'
# Security Headers
<IfModule mod_headers.c>
    # Prevent clickjacking
    Header always set X-Frame-Options "DENY"
    
    # Prevent MIME sniffing
    Header always set X-Content-Type-Options "nosniff"
    
    # XSS Protection
    Header always set X-XSS-Protection "1; mode=block"
    
    # Content Security Policy (adjust as needed)
    Header always set Content-Security-Policy "default-src 'self'"
    
    # Referrer Policy
    Header always set Referrer-Policy "no-referrer-when-downgrade"
</IfModule>
EOF

# Enable the configuration
a2enconf security-headers &> /dev/null

echo "SUCCESS: Security headers added" | tee -a $LOG_FILE

# ============================================
# SECTION 10: SET FILE PERMISSIONS
# ============================================

echo "$(date): Setting file permissions..." | tee -a $LOG_FILE

# Set ownership
chown -R root:www-data $WEB_ROOT
find $WEB_ROOT -type d -exec chmod 755 {} \;
find $WEB_ROOT -type f -exec chmod 644 {} \;

# Remove world-writable permissions
find $WEB_ROOT -type d -perm /o+w -exec chmod o-w {} \;
find $WEB_ROOT -type f -perm /o+w -exec chmod o-w {} \;

echo "SUCCESS: File permissions hardened (755 dirs, 644 files)" | tee -a $LOG_FILE

# ============================================
# SECTION 11: RESTART APACHE
# ============================================

echo "$(date): Restarting Apache..." | tee -a $LOG_FILE

# Test Apache configuration
apache2ctl configtest 2>&1 | tee -a $LOG_FILE

if [ $? -eq 0 ]; then
    # Configuration is valid, restart
    systemctl restart $APACHE_SERVICE
    
    sleep 2
    
    # Verify Apache is running
    if systemctl is-active --quiet $APACHE_SERVICE; then
        echo "SUCCESS: Apache restarted successfully" | tee -a $LOG_FILE
    else
        echo "ERROR: Apache failed to start!" | tee -a $LOG_FILE
        exit 1
    fi
else
    echo "ERROR: Apache config test failed! Not restarting." | tee -a $LOG_FILE
    exit 1
fi

# ============================================
# FINAL OUTPUT
# ============================================

echo ""
echo "=========================================="
echo "Apache Hardening: COMPLETE"
echo "=========================================="
echo "Credentials saved to: $CREDS_FILE"
echo "Backup files: $SCRIPTS_DIR/*.backup.*"
echo "Log file: $LOG_FILE"
echo ""
echo "HTTP Basic Auth Credentials:"
cat $CREDS_FILE
echo ""
echo "=========================================="
echo "$(date): Apache hardening completed successfully" | tee -a $LOG_FILE
