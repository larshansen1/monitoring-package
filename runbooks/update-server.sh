#!/bin/bash
#
# Server Update Runbook
# Updates system packages and reboots if necessary
#

set -e

LOG_FILE="/var/log/server-update-runbook.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Server Update Runbook Started ==="

# Update package lists
log "Updating package lists..."
apt-get update -qq

# Perform upgrade
log "Upgrading packages..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq 2>&1 | tee -a "$LOG_FILE"

# Check if reboot is required
if [ -f /var/run/reboot-required ]; then
    log "Reboot required after updates"
    echo "REBOOT_REQUIRED=1"

    # Read which packages require reboot
    if [ -f /var/run/reboot-required.pkgs ]; then
        log "Packages requiring reboot:"
        cat /var/run/reboot-required.pkgs | tee -a "$LOG_FILE"
    fi

    log "System will reboot in 1 minute..."
    shutdown -r +1 "System reboot required after package updates"
else
    log "No reboot required"
    echo "REBOOT_REQUIRED=0"
fi

log "=== Server Update Runbook Completed ==="

exit 0
