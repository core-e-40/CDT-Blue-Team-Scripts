#!/bin/bash
#==============================
# Kill All Other User Sessions
# Leaves only YOUR current session alive
# By: Cory Le
#==============================

LOG_FILE="/opt/blue_scripts/session_cleanup.log"

echo "$(date): Starting session cleanup..." | tee -a $LOG_FILE

# Get current user and session info
CURRENT_USER=$(whoami)
CURRENT_PID=$$
CURRENT_TTY=$(tty)
CURRENT_SESSION=$(loginctl list-sessions --no-legend | grep $(whoami) | awk '{print $1}')

echo "Current user: $CURRENT_USER" | tee -a $LOG_FILE
echo "Current TTY: $CURRENT_TTY" | tee -a $LOG_FILE
echo "Current PID: $CURRENT_PID" | tee -a $LOG_FILE
echo "Current session: $CURRENT_SESSION" | tee -a $LOG_FILE

echo ""
echo "=========================================="
echo "⚠️  WARNING: Session Cleanup"
echo "=========================================="
echo "This will:"
echo "  1. Kill all SSH sessions (except yours)"
echo "  2. Kill all GUI sessions (except yours)"
echo "  3. Terminate all other user logins"
echo "  4. Kill all sudo shells (except yours)"
echo ""
echo "Press Enter to continue or Ctrl+C to cancel..."
read -r

# ============================================
# SECTION 1: KILL OTHER SSH SESSIONS
# ============================================

echo ""
echo "$(date): Killing other SSH sessions..." | tee -a $LOG_FILE

# Find all sshd processes NOT associated with current session
SSH_PIDS=$(ps aux | grep "sshd:" | grep -v grep | awk '{print $2}')

for pid in $SSH_PIDS; do
    # Check if this is NOT our session
    if [ "$pid" != "$PPID" ] && [ "$pid" != "$$" ]; then
        # Get the TTY of this SSH session
        SSH_TTY=$(ps -p $pid -o tty= 2>/dev/null)
        
        # Only kill if it's not our TTY
        if [ "$SSH_TTY" != "$CURRENT_TTY" ] && [ -n "$SSH_TTY" ]; then
            echo "Killing SSH session on $SSH_TTY (PID: $pid)" | tee -a $LOG_FILE
            kill -9 $pid 2>/dev/null
        fi
    fi
done

echo "SUCCESS: Other SSH sessions terminated" | tee -a $LOG_FILE

# ============================================
# SECTION 2: TERMINATE OTHER LOGIN SESSIONS
# ============================================

echo ""
echo "$(date): Terminating other login sessions..." | tee -a $LOG_FILE

# Get all sessions
ALL_SESSIONS=$(loginctl list-sessions --no-legend | awk '{print $1}')

for session in $ALL_SESSIONS; do
    # Don't kill our own session
    if [ "$session" != "$CURRENT_SESSION" ]; then
        SESSION_USER=$(loginctl show-session $session -p Name --value 2>/dev/null)
        SESSION_TTY=$(loginctl show-session $session -p TTY --value 2>/dev/null)
        
        echo "Terminating session $session (User: $SESSION_USER, TTY: $SESSION_TTY)" | tee -a $LOG_FILE
        loginctl terminate-session $session 2>/dev/null
    fi
done

echo "SUCCESS: Other login sessions terminated" | tee -a $LOG_FILE

# ============================================
# SECTION 3: KILL ALL OTHER BASH/SH SHELLS
# ============================================

echo ""
echo "$(date): Killing other shell processes..." | tee -a $LOG_FILE

# Kill all bash shells except our own
BASH_PIDS=$(ps aux | grep -E "bash|sh" | grep -v grep | awk '{print $2}')

for pid in $BASH_PIDS; do
    # Don't kill our own process or parent processes
    if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
        # Check if this process is on a different TTY
        PROC_TTY=$(ps -p $pid -o tty= 2>/dev/null)
        
        if [ "$PROC_TTY" != "$CURRENT_TTY" ] && [ "$PROC_TTY" != "?" ]; then
            echo "Killing shell on $PROC_TTY (PID: $pid)" | tee -a $LOG_FILE
            kill -9 $pid 2>/dev/null
        fi
    fi
done

echo "SUCCESS: Other shell processes terminated" | tee -a $LOG_FILE

# ============================================
# SECTION 4: KILL ALL SUDO SHELLS
# ============================================

echo ""
echo "$(date): Killing active sudo shells..." | tee -a $LOG_FILE

# Kill all sudo processes except our own
SUDO_PIDS=$(ps aux | grep sudo | grep -v grep | awk '{print $2}')

for pid in $SUDO_PIDS; do
    # Don't kill our own sudo process
    if [ "$pid" != "$PPID" ] && [ "$pid" != "$$" ]; then
        # Check if this is not in our process tree
        if ! ps --ppid $$ | grep -q "^$pid"; then
            echo "Killing sudo process (PID: $pid)" | tee -a $LOG_FILE
            kill -9 $pid 2>/dev/null
        fi
    fi
done

echo "SUCCESS: Other sudo shells terminated" | tee -a $LOG_FILE

# ============================================
# SECTION 5: KILL ALL USER PROCESSES (EXCEPT CURRENT USER)
# ============================================

echo ""
echo "$(date): Killing processes from other users..." | tee -a $LOG_FILE

# Get all regular users (UID >= 1000)
ALL_USERS=$(awk -F: '$3 >= 1000 {print $1}' /etc/passwd)

for user in $ALL_USERS; do
    # Don't kill current user's processes
    if [ "$user" != "$CURRENT_USER" ]; then
        echo "Killing all processes for user: $user" | tee -a $LOG_FILE
        pkill -9 -u $user 2>/dev/null
        
        # Also terminate their login sessions
        loginctl terminate-user $user 2>/dev/null
    fi
done

echo "SUCCESS: Other user processes terminated" | tee -a $LOG_FILE

# ============================================
# SECTION 6: VERIFY CLEANUP
# ============================================

echo ""
echo "$(date): Verifying cleanup..." | tee -a $LOG_FILE

# Show who's still logged in
echo "Currently logged in users:" | tee -a $LOG_FILE
w | tee -a $LOG_FILE

# Show active sessions
echo "" | tee -a $LOG_FILE
echo "Active sessions:" | tee -a $LOG_FILE
loginctl list-sessions | tee -a $LOG_FILE

# ============================================
# SECTION 7: LOCK OTHER USER ACCOUNTS (OPTIONAL)
# ============================================

echo ""
echo "=========================================="
echo "Optional: Lock all other user accounts?"
echo "=========================================="
echo "This will prevent other users from logging in."
echo "Type 'yes' to lock accounts, or press Enter to skip..."
read -r LOCK_ACCOUNTS

if [ "$LOCK_ACCOUNTS" = "yes" ]; then
    echo ""
    echo "$(date): Locking other user accounts..." | tee -a $LOG_FILE
    
    for user in $ALL_USERS; do
        # Don't lock current user
        if [ "$user" != "$CURRENT_USER" ]; then
            passwd -l $user 2>/dev/null
            echo "Locked account: $user" | tee -a $LOG_FILE
        fi
    done
    
    echo "SUCCESS: Other user accounts locked" | tee -a $LOG_FILE
fi

# ============================================
# FINAL SUMMARY
# ============================================

echo ""
echo "=========================================="
echo "Session Cleanup: COMPLETE"
echo "=========================================="
echo "Your session: $CURRENT_TTY (preserved)"
echo "Log file: $LOG_FILE"
echo ""
echo "Actions taken:"
echo "  ✓ Killed all other SSH sessions"
echo "  ✓ Terminated other login sessions"
echo "  ✓ Killed other shell processes"
echo "  ✓ Killed other sudo shells"
echo "  ✓ Killed processes from other users"
if [ "$LOCK_ACCOUNTS" = "yes" ]; then
    echo "  ✓ Locked other user accounts"
fi
echo ""
echo "Only YOUR session remains active!"
echo "=========================================="
echo "$(date): Session cleanup completed" | tee -a $LOG_FILE