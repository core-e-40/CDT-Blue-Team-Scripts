#!/bin/bash
#==============================
# Kill All Other User Sessions - FIXED
# Preserves YOUR session more reliably
# By: Cory Le
#==============================

LOG_FILE="/opt/blue_scripts/session_cleanup.log"

echo "$(date): Starting session cleanup..." | tee -a $LOG_FILE

# Get current session info BEFORE sudo
if [ -n "$SUDO_USER" ]; then
    REAL_USER="$SUDO_USER"
else
    REAL_USER="$(whoami)"
fi

CURRENT_PID=$$
CURRENT_PPID=$PPID
CURRENT_TTY=$(tty)

# Get full process tree to protect
PROTECTED_PIDS=$(pstree -p $CURRENT_PID | grep -o '([0-9]\+)' | grep -o '[0-9]\+')

echo "Protected user: $REAL_USER" | tee -a $LOG_FILE
echo "Protected TTY: $CURRENT_TTY" | tee -a $LOG_FILE
echo "Protected PID: $CURRENT_PID" | tee -a $LOG_FILE
echo "Protected process tree: $PROTECTED_PIDS" | tee -a $LOG_FILE

echo ""
echo "=========================================="
echo "⚠️  Session Cleanup"
echo "=========================================="
echo "This will kill all sessions EXCEPT yours."
echo ""
echo "Your protected session:"
echo "  User: $REAL_USER"
echo "  TTY: $CURRENT_TTY"
echo ""
echo "Press Enter to continue or Ctrl+C to cancel..."
read -r

# ============================================
# SECTION 1: KILL OTHER SSH SESSIONS
# ============================================

echo ""
echo "$(date): Terminating other SSH sessions..." | tee -a $LOG_FILE

# Get all SSH sessions
SSH_SESSIONS=$(ps aux | grep "sshd:" | grep -v grep | awk '{print $2,$11}')

while IFS= read -r line; do
    SSH_PID=$(echo $line | awk '{print $1}')
    SSH_TTY=$(echo $line | awk '{print $2}')
    
    # Skip if this is in our protected process tree
    if echo "$PROTECTED_PIDS" | grep -q "^${SSH_PID}$"; then
        echo "SKIP: SSH session $SSH_PID (your session)" | tee -a $LOG_FILE
        continue
    fi
    
    # Skip if same TTY
    if [ "$SSH_TTY" = "$CURRENT_TTY" ]; then
        echo "SKIP: SSH session $SSH_PID (your TTY)" | tee -a $LOG_FILE
        continue
    fi
    
    echo "KILL: SSH session $SSH_PID on $SSH_TTY" | tee -a $LOG_FILE
    kill -9 $SSH_PID 2>/dev/null
done <<< "$SSH_SESSIONS"

echo "SUCCESS: Other SSH sessions terminated" | tee -a $LOG_FILE

# ============================================
# SECTION 2: TERMINATE OTHER USER LOGIN SESSIONS
# ============================================

echo ""
echo "$(date): Terminating other user login sessions..." | tee -a $LOG_FILE

# Get all users except the real user
ALL_USERS=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd)

for user in $ALL_USERS; do
    # Don't touch the real user's sessions
    if [ "$user" = "$REAL_USER" ]; then
        echo "SKIP: User $user (that's you!)" | tee -a $LOG_FILE
        continue
    fi
    
    echo "KILL: All sessions for user $user" | tee -a $LOG_FILE
    
    # Kill all processes for this user
    pkill -9 -u $user 2>/dev/null
    
    # Terminate login sessions
    loginctl terminate-user $user 2>/dev/null
    
    # Lock the account
    passwd -l $user 2>/dev/null
    echo "LOCKED: User $user account" | tee -a $LOG_FILE
done

echo "SUCCESS: Other users terminated and locked" | tee -a $LOG_FILE

# ============================================
# SECTION 3: KILL SHELLS ON OTHER TTYS
# ============================================

echo ""
echo "$(date): Killing shells on other TTYs..." | tee -a $LOG_FILE

# Get all bash/sh processes
SHELL_PROCS=$(ps aux | grep -E "/bash|/sh" | grep -v grep | awk '{print $2,$7}')

while IFS= read -r line; do
    SHELL_PID=$(echo $line | awk '{print $1}')
    SHELL_TTY=$(echo $line | awk '{print $2}')
    
    # Skip if in protected process tree
    if echo "$PROTECTED_PIDS" | grep -q "^${SHELL_PID}$"; then
        echo "SKIP: Shell $SHELL_PID (in your process tree)" | tee -a $LOG_FILE
        continue
    fi
    
    # Skip if our TTY
    if [ "$SHELL_TTY" = "$CURRENT_TTY" ]; then
        echo "SKIP: Shell $SHELL_PID (your TTY)" | tee -a $LOG_FILE
        continue
    fi
    
    # Skip if no TTY (system processes)
    if [ "$SHELL_TTY" = "?" ]; then
        continue
    fi
    
    echo "KILL: Shell $SHELL_PID on $SHELL_TTY" | tee -a $LOG_FILE
    kill -9 $SHELL_PID 2>/dev/null
done <<< "$SHELL_PROCS"

echo "SUCCESS: Other shells terminated" | tee -a $LOG_FILE

# ============================================
# SECTION 4: KILL ORPHANED SUDO PROCESSES
# ============================================

echo ""
echo "$(date): Killing orphaned sudo processes..." | tee -a $LOG_FILE

# Get all sudo processes
SUDO_PROCS=$(ps aux | grep sudo | grep -v grep | awk '{print $2}')

for sudo_pid in $SUDO_PROCS; do
    # Skip if in protected process tree
    if echo "$PROTECTED_PIDS" | grep -q "^${sudo_pid}$"; then
        echo "SKIP: Sudo $sudo_pid (your sudo)" | tee -a $LOG_FILE
        continue
    fi
    
    echo "KILL: Sudo process $sudo_pid" | tee -a $LOG_FILE
    kill -9 $sudo_pid 2>/dev/null
done

echo "SUCCESS: Orphaned sudo processes terminated" | tee -a $LOG_FILE

# ============================================
# SECTION 5: VERIFY CLEANUP
# ============================================

echo ""
echo "$(date): Verifying cleanup..." | tee -a $LOG_FILE

# Show who's logged in
echo "Currently logged in:" | tee -a $LOG_FILE
w | tee -a $LOG_FILE

echo ""
echo "Active sessions:" | tee -a $LOG_FILE
loginctl list-sessions 2>/dev/null | tee -a $LOG_FILE

# ============================================
# FINAL SUMMARY
# ============================================

echo ""
echo "=========================================="
echo "Session Cleanup: COMPLETE"
echo "=========================================="
echo "Your session preserved:"
echo "  User: $REAL_USER"
echo "  TTY: $CURRENT_TTY"
echo "  PID: $CURRENT_PID"
echo ""
echo "Actions taken:"
echo "  ✓ Killed other SSH sessions"
echo "  ✓ Terminated other users' sessions"
echo "  ✓ Locked other user accounts"
echo "  ✓ Killed shells on other TTYs"
echo "  ✓ Killed orphaned sudo processes"
echo ""
echo "Log file: $LOG_FILE"
echo "=========================================="
echo "$(date): Session cleanup completed" | tee -a $LOG_FILE