#!/bin/bash
#
# Fail2ban Daily Status Report (Telegram Version)
# Send notification with fail2ban status
#

# Load Telegram notification library
source /usr/local/lib/monitoring/telegram-notify.sh

# Get fail2ban status
FAIL2BAN_STATUS=$(fail2ban-client status 2>&1)

# Check if fail2ban is running
if [ $? -ne 0 ]; then
    MESSAGE="*Fail2ban NOT Running*

⚠️ FAIL2BAN IS NOT RUNNING!

Please check the service:
\`systemctl status fail2ban\`"

    telegram_send_alert "critical" "Fail2ban NOT Running" "$MESSAGE"
    exit 1
fi

# Get list of jails
JAIL_LIST=$(fail2ban-client status | grep "Jail list:" | cut -d: -f2 | tr -d '\t' | tr ',' ' ')

# Build detailed status for each jail
JAIL_DETAILS=""
TOTAL_BANNED=0
TOTAL_FAILED=0
HAS_BANNED_IPS=false

for jail in $JAIL_LIST; do
    JAIL_STATUS=$(fail2ban-client status "$jail" 2>/dev/null)

    if [ $? -eq 0 ]; then
        CURRENTLY_BANNED=$(echo "$JAIL_STATUS" | grep "Currently banned:" | awk '{print $NF}')
        TOTAL_BANNED_JAIL=$(echo "$JAIL_STATUS" | grep "Total banned:" | awk '{print $NF}')
        CURRENTLY_FAILED=$(echo "$JAIL_STATUS" | grep "Currently failed:" | awk '{print $NF}')
        TOTAL_FAILED_JAIL=$(echo "$JAIL_STATUS" | grep "Total failed:" | awk '{print $NF}')
        BANNED_IPS=$(echo "$JAIL_STATUS" | grep "Banned IP list:" | cut -d: -f2 | tr -d '\t')

        TOTAL_BANNED=$((TOTAL_BANNED + CURRENTLY_BANNED))
        TOTAL_FAILED=$((TOTAL_FAILED + CURRENTLY_FAILED))

        JAIL_DETAILS="${JAIL_DETAILS}
📊 *${jail}*
   Currently Banned: ${CURRENTLY_BANNED}
   Total Banned (24h): ${TOTAL_BANNED_JAIL}
   Currently Failed: ${CURRENTLY_FAILED}
   Total Failed: ${TOTAL_FAILED_JAIL}"

        if [ -n "$BANNED_IPS" ] && [ "$BANNED_IPS" != "" ]; then
            HAS_BANNED_IPS=true
            JAIL_DETAILS="${JAIL_DETAILS}
   🚫 Banned: ${BANNED_IPS}"
        fi

        JAIL_DETAILS="${JAIL_DETAILS}
"
    fi
done

# Determine priority and emoji based on activity
if [ $TOTAL_BANNED -gt 0 ]; then
    SEVERITY="warning"
    EMOJI="🛡️"
    STATUS="Active Protection"
else
    SEVERITY="info"
    EMOJI="✅"
    STATUS="All Clear"
fi

# Build the message
MESSAGE="${EMOJI} *Fail2ban Daily Status*

Status: ${STATUS}

Summary:
• Total Currently Banned: ${TOTAL_BANNED}
• Total Currently Failed: ${TOTAL_FAILED}

${JAIL_DETAILS}
---
Daily automated report"

# Send with or without buttons depending on if there are banned IPs
if [ "$HAS_BANNED_IPS" = true ]; then
    telegram_send_with_buttons "$MESSAGE" \
        "📋 View Full Status|fail2ban_status" \
        "❌ Dismiss|dismiss"
else
    telegram_send_alert "$SEVERITY" "Fail2ban Daily Status" "$MESSAGE"
fi

exit 0
