#!/bin/bash
#==============================
# Automated Password Rotation with Sheet Cycling
# By: Cory Le
#==============================

LOG_FILE="/opt/blue_scripts/password_rotation.log"
GITHUB_REPO="https://raw.githubusercontent.com/core-e-40/blue-team-file-share/main/password_sheets"
ENV_FILE="/var/lib/.system-cache/.sheet-state"  # Hidden location for sheet tracker
TEMP_DIR="/tmp/.pw_rotation_$$"  # Temporary directory for downloaded sheet

echo "$(date): Starting automated password rotation..." | tee -a $LOG_FILE

# ============================================
# SECTION 1: INITIALIZE SHEET TRACKER
# ============================================

echo "$(date): Checking sheet tracker..." | tee -a $LOG_FILE

# Create hidden directory for env file if it doesn't exist
mkdir -p $(dirname $ENV_FILE)
chmod 700 $(dirname $ENV_FILE)

# Check if sheet tracker exists
if [ ! -f "$ENV_FILE" ]; then
    echo "CURRENT_SHEET=sheet_1" > $ENV_FILE
    chmod 600 $ENV_FILE
    echo "Initialized sheet tracker: sheet_1" | tee -a $LOG_FILE
else
    echo "Sheet tracker exists" | tee -a $LOG_FILE
fi

# Load current sheet number
source $ENV_FILE
echo "$(date): Using $CURRENT_SHEET" | tee -a $LOG_FILE

# ============================================
# SECTION 2: DOWNLOAD PASSWORD SHEET
# ============================================

echo "$(date): Downloading password sheet from GitHub..." | tee -a $LOG_FILE

# Create temp directory
mkdir -p $TEMP_DIR
chmod 700 $TEMP_DIR

# Construct download URL
SHEET_URL="$GITHUB_REPO/${CURRENT_SHEET}.csv"
CSV_FILE="$TEMP_DIR/${CURRENT_SHEET}.csv"

# Download the sheet
curl -s -f -o "$CSV_FILE" "$SHEET_URL"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to download $CURRENT_SHEET from GitHub" | tee -a $LOG_FILE
    echo "URL attempted: $SHEET_URL" | tee -a $LOG_FILE
    rm -rf $TEMP_DIR
    exit 1
fi

echo "SUCCESS: Downloaded $CURRENT_SHEET" | tee -a $LOG_FILE

# Verify file is not empty
if [ ! -s "$CSV_FILE" ]; then
    echo "ERROR: Downloaded sheet is empty" | tee -a $LOG_FILE
    rm -rf $TEMP_DIR
    exit 1
fi

# ============================================
# SECTION 3: LOAD PASSWORD MAP FROM CSV
# ============================================

echo "$(date): Loading password mappings..." | tee -a $LOG_FILE

declare -A PASSWORD_MAP
OTHER_PASSWORD=""

while IFS=',' read -r username password; do
    # Trim whitespace
    username=$(echo "$username" | xargs)
    password=$(echo "$password" | xargs)
    
    # Skip empty lines
    [ -z "$username" ] && continue
    
    if [ "$username" = "other" ]; then
        OTHER_PASSWORD="$password"
        echo "Loaded fallback password for unlisted users" | tee -a $LOG_FILE
    else
        PASSWORD_MAP["$username"]="$password"
        echo "Loaded password for user: $username" | tee -a $LOG_FILE
    fi
done < "$CSV_FILE"

# Verify we have passwords
if [ ${#PASSWORD_MAP[@]} -eq 0 ] && [ -z "$OTHER_PASSWORD" ]; then
    echo "ERROR: No passwords loaded from CSV" | tee -a $LOG_FILE
    rm -rf $TEMP_DIR
    exit 1
fi

# ============================================
# SECTION 4: GET ALL SYSTEM USERS
# ============================================

echo "$(date): Getting list of system users..." | tee -a $LOG_FILE

# Get all regular users (UID >= 1000) + root (UID 0)
# Exclude: nobody, systemd users, service accounts
ALL_USERS=$(awk -F: '($3 >= 1000 || $3 == 0) && $1 != "nobody" && $7 !~ /nologin|false/ {print $1}' /etc/passwd)

echo "Users to rotate:" | tee -a $LOG_FILE
echo "$ALL_USERS" | tee -a $LOG_FILE

# ============================================
# SECTION 5: ROTATE PASSWORDS
# ============================================

echo "$(date): Rotating passwords for all users..." | tee -a $LOG_FILE

SUCCESS_COUNT=0
FAIL_COUNT=0
FALLBACK_COUNT=0

for user in $ALL_USERS; do
    # Check if user has specific password in CSV
    if [ -n "${PASSWORD_MAP[$user]}" ]; then
        # User has specific password
        NEW_PASSWORD="${PASSWORD_MAP[$user]}"
        echo "$(date): Changing password for $user (specific)" | tee -a $LOG_FILE
    elif [ -n "$OTHER_PASSWORD" ]; then
        # User not in CSV, use "other" password
        NEW_PASSWORD="$OTHER_PASSWORD"
        echo "$(date): Changing password for $user (fallback)" | tee -a $LOG_FILE
        ((FALLBACK_COUNT++))
    else
        echo "$(date): WARNING: No password for $user and no fallback defined" | tee -a $LOG_FILE
        ((FAIL_COUNT++))
        continue
    fi
    
    # Change the password
    echo "$user:$NEW_PASSWORD" | chpasswd
    
    if [ $? -eq 0 ]; then
        echo "$(date): ✓ SUCCESS: Password changed for $user" | tee -a $LOG_FILE
        ((SUCCESS_COUNT++))
    else
        echo "$(date): ✗ ERROR: Failed to change password for $user" | tee -a $LOG_FILE
        ((FAIL_COUNT++))
    fi
done

# ============================================
# SECTION 6: INCREMENT SHEET COUNTER
# ============================================

echo "$(date): Updating sheet tracker..." | tee -a $LOG_FILE

# Extract current sheet number
CURRENT_NUM=$(echo $CURRENT_SHEET | grep -o '[0-9]\+')

# Increment
NEXT_NUM=$((CURRENT_NUM + 1))
NEXT_SHEET="sheet_${NEXT_NUM}"

# Update env file
echo "CURRENT_SHEET=$NEXT_SHEET" > $ENV_FILE
chmod 600 $ENV_FILE

echo "Updated sheet tracker: $CURRENT_SHEET → $NEXT_SHEET" | tee -a $LOG_FILE

# ============================================
# SECTION 7: CLEANUP
# ============================================

echo "$(date): Cleaning up..." | tee -a $LOG_FILE

# Securely delete the CSV file
shred -u -z "$CSV_FILE" 2>/dev/null || rm -f "$CSV_FILE"

# Remove temp directory
rm -rf $TEMP_DIR

echo "Deleted password sheet from disk" | tee -a $LOG_FILE

# ============================================
# FINAL SUMMARY
# ============================================

echo ""
echo "=========================================="
echo "Password Rotation Complete"
echo "=========================================="
echo "Sheet used: $CURRENT_SHEET"
echo "Next sheet: $NEXT_SHEET"
echo ""
echo "Results:"
echo "  ✓ Successfully rotated: $SUCCESS_COUNT"
echo "  ⚠ Used fallback password: $FALLBACK_COUNT"
echo "  ✗ Failed: $FAIL_COUNT"
echo ""
echo "Log file: $LOG_FILE"
echo "=========================================="
echo "$(date): Password rotation completed" | tee -a $LOG_FILE

# Exit with error if any failures
if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
fi

exit 0