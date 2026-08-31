#!/bin/bash
#
# Certificate Status Runbook
# Shows status of all SSL certificates
#

set -e

LOG_FILE="/var/log/cert-status-runbook.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Certificate Status Runbook Started ==="

# Get certbot certificates
log "Checking certificate status..."
CERT_OUTPUT=$(certbot certificates 2>&1)

echo "=== CERTIFICATE STATUS ==="
echo "$CERT_OUTPUT"
echo ""

# Check certbot timer status
echo "=== CERTBOT TIMER STATUS ==="
if systemctl is-active --quiet certbot.timer; then
    echo "Status: Active"
    systemctl status certbot.timer --no-pager | grep -A 5 "Active:"
else
    echo "Status: Inactive or not installed"
fi
echo ""

# Show next run time
echo "=== NEXT SCHEDULED RENEWAL ==="
systemctl list-timers certbot.timer --no-pager | grep certbot || echo "No timer scheduled"

log "=== Certificate Status Runbook Completed ==="

exit 0
