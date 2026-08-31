#!/bin/bash
#
# Disk Top Files Runbook
# Shows the largest files and directories
#

set -e

LOG_FILE="/var/log/disk-topfiles-runbook.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Disk Top Files Runbook Started ==="

# Get current disk usage
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}')
log "Current disk usage: ${DISK_USAGE}"

# Find top 10 largest directories in /
log "Finding top directories..."
TOP_DIRS=$(du -h --max-depth=1 / 2>/dev/null | sort -rh | head -10 | grep -v "^du:")

# Find top 10 largest files
log "Finding top files..."
TOP_FILES=$(find / -type f -size +100M 2>/dev/null -exec du -h {} \; | sort -rh | head -10)

# Output results
echo "=== DISK USAGE REPORT ==="
echo ""
echo "Current Usage: ${DISK_USAGE}"
echo ""
echo "Top Directories:"
echo "$TOP_DIRS"
echo ""
echo "Top Large Files (>100MB):"
if [ -n "$TOP_FILES" ]; then
    echo "$TOP_FILES"
else
    echo "No files larger than 100MB found"
fi
echo ""

log "=== Disk Top Files Runbook Completed ==="

exit 0
