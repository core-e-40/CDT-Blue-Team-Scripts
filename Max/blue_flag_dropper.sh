#!/bin/bash

# ==============================
# Blue Team Flag Dropper
# ==============================

# Explicit target directories
TARGET_DIRS=(
    "/etc/apache2"
    "/etc/nginx"
    "/etc/krb5kdc"
    "/etc/inspircd"
    "/usr/bin"
    "/var/www"
    "/var/www/html"
    "/var/www/wordpress"
    "/home"
    "/etc/redis"
    "/usr/local/bin"
)

FLAG_COUNT=25
LOG_FILE="/var/log/blue_flag_dropper.log"

MESSAGES=(
    "Blue_got_you_again"
    "Defense_in_depth_wins"
    "The_SIEM_saw_that"
    "Logs_tell_all"
    "Patched_before_exploit"
    "Blue_team_dominates"
    "Threat_hunted_successfully"
    "Monitoring_never_sleeps"
    "Least_privilege_enforced"
    "Incident_response_complete"
)

generate_flag() {
    RAND=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 6)
    MSG=${MESSAGES[$RANDOM % ${#MESSAGES[@]}]}
    echo "flag{${MSG}_${RAND}}"
}

# Choose safe web/config file types
get_random_file() {
    find "${TARGET_DIRS[@]}" -type f \
        \( -name "*.conf" -o -name "*.cfg" -o -name "*.ini" \
           -o -name "*.cnf" -o -name "*.php" -o -name "*.html" \
           -o -name "*.htaccess" \) \
        -writable 2>/dev/null | shuf -n 1
}

append_flag() {
    FILE="$1"
    FLAG="$2"

    case "$FILE" in
        *.php)
            echo -e "\n<?php /* $FLAG */ ?>" >> "$FILE"
            ;;
        *.html)
            echo -e "\n<!-- $FLAG -->" >> "$FILE"
            ;;
        *.htaccess)
            echo -e "\n# $FLAG" >> "$FILE"
            ;;
        *)
            echo -e "\n# $FLAG" >> "$FILE"
            ;;
    esac
}

echo "==== Blue Flag Dropper Run $(date) ====" >> "$LOG_FILE"

for ((i=1; i<=FLAG_COUNT; i++)); do
    TARGET_FILE=$(get_random_file)

    if [[ -n "$TARGET_FILE" ]]; then
        FLAG=$(generate_flag)
        append_flag "$TARGET_FILE" "$FLAG"
        echo "Dropped $FLAG in $TARGET_FILE" >> "$LOG_FILE"
    fi
done

echo "Completed run." >> "$LOG_FILE"
echo "Flags deployed successfully."
