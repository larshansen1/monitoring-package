#!/bin/bash
#
# Security Updates Monitor
# Alerts when critical security updates are available
#

set -e

# Configuration
NTFY_TOPIC="madmetal-server-alerts-$(hostname)"
NTFY_URL="https://ntfy.sh/${NTFY_TOPIC}"
LOG_FILE="/var/log/security-updates-check.log"

# Thresholds
CRITICAL_THRESHOLD=5   # Alert if 5+ security updates available
WARNING_THRESHOLD=10   # Alert if 10+ total updates available

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Alert functions
send_critical_alert() {
    local security=$1
    local total=$2
    local packages=$3

    log "CRITICAL: ${security} security updates available!"

    # Truncate package list if too long
    local pkg_list=$(echo "$packages" | head -10 | tr '\n' ', ' | sed 's/,$//')
    if [ $(echo "$packages" | wc -l) -gt 10 ]; then
        pkg_list="${pkg_list}... and more"
    fi

    curl -H "Title: 🚨 Critical Security Updates!" \
         -H "Priority: urgent" \
         -H "Tags: security,updates,critical" \
         -d "⚠️ ${security} SECURITY UPDATES AVAILABLE

Server: $(hostname)
Security Updates: ${security}
Total Updates: ${total}

Critical packages:
${pkg_list}

🔧 To update:
  sudo apt update
  sudo apt upgrade

Or auto-update security only:
  sudo unattended-upgrade" \
         "$NTFY_URL"
}

send_warning_alert() {
    local security=$1
    local total=$2
    local packages=$3

    log "WARNING: ${security} security updates available"

    local pkg_list=$(echo "$packages" | head -5 | tr '\n' ', ' | sed 's/,$//')

    curl -H "Title: ⚠️ Security Updates Available" \
         -H "Priority: high" \
         -H "Tags: security,updates,warning" \
         -d "Security updates available for $(hostname)

Security Updates: ${security}
Total Updates: ${total}

Packages: ${pkg_list}

Update when convenient:
  sudo apt update && sudo apt upgrade" \
         "$NTFY_URL"
}

send_info_alert() {
    local total=$1

    log "INFO: ${total} updates available (no security updates)"

    curl -H "Title: 📦 System Updates Available" \
         -H "Priority: low" \
         -H "Tags: updates,info" \
         -d "${total} regular updates available on $(hostname)

No security updates at this time.

Update when convenient:
  sudo apt update && sudo apt upgrade" \
         "$NTFY_URL"
}

# Update package lists
log "=== Checking for Security Updates ==="
apt-get update -qq 2>&1 | tee -a "$LOG_FILE" > /dev/null

# Get update counts
# apt-check returns: <regular_updates>;<security_updates>
UPDATE_INFO=$(/usr/lib/update-notifier/apt-check 2>&1)
TOTAL_UPDATES=$(echo "$UPDATE_INFO" | cut -d';' -f1)
SECURITY_UPDATES=$(echo "$UPDATE_INFO" | cut -d';' -f2)

log "Total updates available: ${TOTAL_UPDATES}"
log "Security updates available: ${SECURITY_UPDATES}"

# Get list of security updates
if [ "$SECURITY_UPDATES" -gt 0 ]; then
    SECURITY_PACKAGES=$(apt-get upgrade --dry-run 2>/dev/null | \
        grep -i security | \
        awk '{print $2}' | \
        grep -v '^$' | \
        sort -u | \
        head -20)

    log "Security packages: ${SECURITY_PACKAGES}"
fi

# Check if there are critical security updates
if [ "$SECURITY_UPDATES" -ge "$CRITICAL_THRESHOLD" ]; then
    send_critical_alert "$SECURITY_UPDATES" "$TOTAL_UPDATES" "$SECURITY_PACKAGES"
elif [ "$SECURITY_UPDATES" -gt 0 ]; then
    send_warning_alert "$SECURITY_UPDATES" "$TOTAL_UPDATES" "$SECURITY_PACKAGES"
elif [ "$TOTAL_UPDATES" -ge "$WARNING_THRESHOLD" ]; then
    send_info_alert "$TOTAL_UPDATES"
else
    log "System is up to date (${TOTAL_UPDATES} non-security updates available)"
fi

log "=== Security Update Check Complete ==="

exit 0
