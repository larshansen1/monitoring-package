#!/bin/bash
#
# Disk Cleanup Runbook
# Cleans apt cache and removes old packages
#

set -e

LOG_FILE="/var/log/disk-cleanup-runbook.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Disk Cleanup Runbook Started ==="

# Get disk usage before
BEFORE=$(df -h / | tail -1 | awk '{print $3}')
log "Disk used before: ${BEFORE}"

# Clean apt cache
log "Cleaning apt cache..."
apt-get clean 2>&1 | tee -a "$LOG_FILE"

# Remove old packages
log "Autoremoving old packages..."
apt-get autoremove -y 2>&1 | tee -a "$LOG_FILE"

# Clean old journal logs (keep last 3 days)
log "Cleaning old journal logs..."
journalctl --vacuum-time=3d 2>&1 | tee -a "$LOG_FILE"

# Clean Docker if installed
if command -v docker &> /dev/null; then
    log "Cleaning Docker system..."
    docker system prune -f 2>&1 | tee -a "$LOG_FILE"
fi

# Get disk usage after
AFTER=$(df -h / | tail -1 | awk '{print $3}')
USAGE_PERCENT=$(df -h / | tail -1 | awk '{print $5}')

log "Disk used after: ${AFTER}"
log "Current usage: ${USAGE_PERCENT}"

echo "=== CLEANUP COMPLETE ==="
echo "Before: ${BEFORE}"
echo "After: ${AFTER}"
echo "Current: ${USAGE_PERCENT}"

log "=== Disk Cleanup Runbook Completed ==="

exit 0
