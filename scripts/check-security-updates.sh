#!/bin/bash
#
# Security Updates Monitor (Telegram Version)
# Alerts when critical security updates are available with action buttons
#

set -e

# Load Telegram notification library
source /usr/local/lib/monitoring/telegram-notify.sh

LOG_FILE="/var/log/security-updates-check.log"

# Thresholds
CRITICAL_THRESHOLD=5   # Alert if 5+ security updates available
WARNING_THRESHOLD=10   # Alert if 10+ total updates available

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Checking for Security Updates ==="

# Update package lists
apt-get update -qq 2>&1 | tee -a "$LOG_FILE" > /dev/null

# Get update counts
UPDATE_INFO=$(/usr/lib/update-notifier/apt-check 2>&1)
TOTAL_UPDATES=$(echo "$UPDATE_INFO" | cut -d';' -f1)
SECURITY_UPDATES=$(echo "$UPDATE_INFO" | cut -d';' -f2)

log "Total updates available: ${TOTAL_UPDATES}"
log "Security updates available: ${SECURITY_UPDATES}"

# Get list of security updates
SECURITY_PACKAGES=""
if [ "$SECURITY_UPDATES" -gt 0 ]; then
    SECURITY_PACKAGES=$(apt-get upgrade --dry-run 2>/dev/null | \
        grep -i security | \
        awk '{print $2}' | \
        grep -v '^$' | \
        sort -u | \
        head -10)

    log "Security packages: ${SECURITY_PACKAGES}"
fi

# Prepare package list for message
PKG_LIST=""
if [ -n "$SECURITY_PACKAGES" ]; then
    PKG_LIST=$(echo "$SECURITY_PACKAGES" | head -5 | sed 's/^/  • /' | tr '\n' '|' | sed 's/|$//' | tr '|' '\n')
    PKG_COUNT=$(echo "$SECURITY_PACKAGES" | wc -l)
    if [ "$PKG_COUNT" -gt 5 ]; then
        PKG_LIST="${PKG_LIST}
  • ...and $((PKG_COUNT - 5)) more"
    fi
fi

# Send appropriate alert
if [ "$SECURITY_UPDATES" -ge "$CRITICAL_THRESHOLD" ]; then
    log "CRITICAL: ${SECURITY_UPDATES} security updates available!"

    MESSAGE="*${SECURITY_UPDATES} SECURITY UPDATES AVAILABLE*

Security Updates: ${SECURITY_UPDATES}
Total Updates: ${TOTAL_UPDATES}

Critical packages:
${PKG_LIST}

🔧 What would you like to do?"

    telegram_send_with_buttons "$MESSAGE" \
        "🔄 Update Now|update_server" \
        "❌ Dismiss|dismiss"

elif [ "$SECURITY_UPDATES" -gt 0 ]; then
    log "WARNING: ${SECURITY_UPDATES} security updates available"

    MESSAGE="*Security Updates Available*

Security Updates: ${SECURITY_UPDATES}
Total Updates: ${TOTAL_UPDATES}

Packages:
${PKG_LIST}

Would you like to update now?"

    telegram_send_with_buttons "$MESSAGE" \
        "🔄 Update Now|update_server" \
        "❌ Dismiss|dismiss"

elif [ "$TOTAL_UPDATES" -ge "$WARNING_THRESHOLD" ]; then
    log "INFO: ${TOTAL_UPDATES} updates available (no security updates)"

    MESSAGE="*System Updates Available*

${TOTAL_UPDATES} regular updates available

No critical security updates at this time.

Update when convenient?"

    telegram_send_with_buttons "$MESSAGE" \
        "🔄 Update Now|update_server" \
        "❌ Dismiss|dismiss"

else
    log "System is up to date (${TOTAL_UPDATES} non-security updates available)"
fi

log "=== Security Update Check Complete ==="

exit 0
