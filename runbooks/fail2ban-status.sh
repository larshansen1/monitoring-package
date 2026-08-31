#!/bin/bash
#
# Fail2ban Status Runbook
# Shows detailed fail2ban status for all jails
#

set -e

LOG_FILE="/var/log/fail2ban-status-runbook.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Fail2ban Status Runbook Started ==="

# Check if fail2ban is running
if ! systemctl is-active --quiet fail2ban; then
    echo "ERROR: Fail2ban is not running!"
    echo ""
    echo "Status:"
    systemctl status fail2ban --no-pager
    exit 1
fi

# Get general status
echo "=== FAIL2BAN GENERAL STATUS ==="
fail2ban-client status
echo ""

# Get list of jails
JAIL_LIST=$(fail2ban-client status | grep "Jail list:" | cut -d: -f2 | tr -d '\t' | tr ',' ' ')

# Show detailed status for each jail
for jail in $JAIL_LIST; do
    echo "=== JAIL: ${jail} ==="
    fail2ban-client status "$jail"
    echo ""
done

# Show service status
echo "=== FAIL2BAN SERVICE STATUS ==="
systemctl status fail2ban --no-pager | head -20

log "=== Fail2ban Status Runbook Completed ==="

exit 0
