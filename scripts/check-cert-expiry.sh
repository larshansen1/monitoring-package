#!/bin/bash
#
# SSL Certificate Expiry Monitor (Telegram Version)
# Alerts when certificates are close to expiring
#

set -e

# Load Telegram notification library
source /usr/local/lib/monitoring/telegram-notify.sh

# Configuration
WARNING_DAYS=14  # Alert when cert expires in less than this many days
CRITICAL_DAYS=7  # Critical alert when cert expires in less than this many days

# Logging
LOG_FILE="/var/log/cert-expiry-check.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check certificate expiry
check_cert() {
    local domain=$1
    local cert_path="/etc/letsencrypt/live/${domain}/cert.pem"

    if [ ! -f "$cert_path" ]; then
        log "WARNING: Certificate not found for ${domain}"
        return
    fi

    # Get expiry date
    expiry_date=$(openssl x509 -enddate -noout -in "$cert_path" | cut -d= -f2)
    expiry_epoch=$(date -d "$expiry_date" +%s)
    current_epoch=$(date +%s)
    days_until_expiry=$(( ($expiry_epoch - $current_epoch) / 86400 ))

    log "${domain}: ${days_until_expiry} days until expiry"

    # Check if critical
    if [ $days_until_expiry -le $CRITICAL_DAYS ]; then
        send_critical_alert "$domain" "$days_until_expiry" "$expiry_date"
    # Check if warning
    elif [ $days_until_expiry -le $WARNING_DAYS ]; then
        send_warning_alert "$domain" "$days_until_expiry" "$expiry_date"
    fi
}

send_critical_alert() {
    local domain=$1
    local days=$2
    local expiry=$3

    log "CRITICAL: ${domain} expires in ${days} days!"

    MESSAGE="🚨 *SSL Certificate Expiring Soon!*

*CRITICAL: Certificate expires in ${days} days!*

Domain: ${domain}
Expiry Date: ${expiry}
Days Remaining: ${days}

⚠️ URGENT ACTION REQUIRED
The certificate should have renewed automatically but hasn't!

What would you like to do?"

    telegram_send_with_buttons "$MESSAGE" \
        "🔄 Renew Certificate|cert_renew_${domain}" \
        "🔍 Check Status|cert_status" \
        "❌ Dismiss|dismiss"
}

send_warning_alert() {
    local domain=$1
    local days=$2
    local expiry=$3

    log "WARNING: ${domain} expires in ${days} days"

    MESSAGE="⚠️ *SSL Certificate Expiring*

Certificate expires in ${days} days

Domain: ${domain}
Expiry Date: ${expiry}
Days Remaining: ${days}

The certificate should renew automatically, but monitor it closely.

Would you like to check the status?"

    telegram_send_with_buttons "$MESSAGE" \
        "🔍 Check Certbot Status|cert_status" \
        "❌ Dismiss|dismiss"
}

log "=== Starting Certificate Expiry Check ==="

# Get all certificates from certbot
DOMAINS=$(certbot certificates 2>/dev/null | grep "Certificate Name:" | awk '{print $3}')

if [ -z "$DOMAINS" ]; then
    log "ERROR: No certificates found"
    exit 1
fi

# Check each certificate
for domain in $DOMAINS; do
    check_cert "$domain"
done

log "=== Certificate Check Complete ==="

exit 0
