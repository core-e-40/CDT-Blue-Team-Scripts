#!/bin/bash

echo "[*] Scanning /var/www/ for Adminer..."

# 1. Dynamically find the path to any file containing "Adminer"
ADMINER_PATH=$(grep -rl "Adminer" /var/www/ 2>/dev/null | head -n 1)

if [ -z "$ADMINER_PATH" ]; then
    echo "[!] Adminer not found anywhere in /var/www/"
    exit 1
fi

# 2. Identify the directory and the new random name
DIR_NAME=$(dirname "$ADMINER_PATH")
NEW_NAME=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12).php

echo "[+] Found Adminer at: $ADMINER_PATH"
echo "[+] Target Directory: $DIR_NAME"

# 3. Perform the move
sudo mv "$ADMINER_PATH" "$DIR_NAME/$NEW_NAME"

echo "------------------------------------------------"
echo "SUCCESS: Adminer has been cloaked."
echo "New Filename: $NEW_NAME"
echo "Full Path:    $DIR_NAME/$NEW_NAME"
echo "------------------------------------------------"