#!/bin/bash
#
# Certificate Renewal Runbook
# Attempts to renew SSL certificates
#

set -e

LOG_FILE="/var/log/cert-renew-runbook.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Certificate Renewal Runbook Started ==="

# Try dry run first
log "Testing certificate renewal (dry run)..."
DRYRUN_OUTPUT=$(certbot renew --dry-run 2>&1)
DRYRUN_RESULT=$?

if [ $DRYRUN_RESULT -ne 0 ]; then
    log "ERROR: Dry run failed!"
    echo "=== DRY RUN FAILED ==="
    echo "$DRYRUN_OUTPUT"
    echo ""
    echo "Please check certbot configuration manually:"
    echo "  sudo certbot certificates"
    echo "  sudo journalctl -u certbot.service"
    exit 1
fi

log "Dry run successful, proceeding with renewal..."

# Perform actual renewal
log "Renewing certificates..."
RENEW_OUTPUT=$(certbot renew --force-renewal 2>&1)
RENEW_RESULT=$?

if [ $RENEW_RESULT -eq 0 ]; then
    log "Certificate renewal successful!"
    echo "=== RENEWAL SUCCESSFUL ==="
    echo "$RENEW_OUTPUT"

    # Reload web server if running
    if systemctl is-active --quiet nginx; then
        log "Reloading nginx..."
        systemctl reload nginx
    fi

    if systemctl is-active --quiet apache2; then
        log "Reloading apache2..."
        systemctl reload apache2
    fi
else
    log "ERROR: Certificate renewal failed!"
    echo "=== RENEWAL FAILED ==="
    echo "$RENEW_OUTPUT"
    exit 1
fi

log "=== Certificate Renewal Runbook Completed ==="

exit 0
