#==============================
# Hardening Redis script
# By: Cory Le
#==============================


# section 1: global vars

# section 2: backup original config

# section 3: network hardening

# section 4: set credentials
#   write password to file, encrypt it
#   send password to FTP server for backup
#   wipe password file from system

# section 5: disable admin commands

# section 6: set resource limits

# section 7: disable persistence

# section 8: restart redis

echo "Redis Hardening: COMPLETE"
echo 