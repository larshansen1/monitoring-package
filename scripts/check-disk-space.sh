#!/bin/bash
#
# Disk Space Monitor (Telegram Version)
# Send notification when disk usage exceeds threshold
#

# Load Telegram notification library
source /usr/local/lib/monitoring/telegram-notify.sh

# Configuration
THRESHOLD=80  # Alert when disk usage exceeds this percentage

# Get disk usage percentage (without the % sign)
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
DISK_INFO=$(df -h / | tail -1)

# Parse disk info
FILESYSTEM=$(echo "$DISK_INFO" | awk '{print $1}')
SIZE=$(echo "$DISK_INFO" | awk '{print $2}')
USED=$(echo "$DISK_INFO" | awk '{print $3}')
AVAIL=$(echo "$DISK_INFO" | awk '{print $4}')
MOUNT=$(echo "$DISK_INFO" | awk '{print $6}')

# Check if usage exceeds threshold
if [ "$DISK_USAGE" -ge "$THRESHOLD" ]; then
    # Determine severity
    if [ "$DISK_USAGE" -ge 90 ]; then
        SEVERITY="critical"
        EMOJI="🚨"
    else
        SEVERITY="warning"
        EMOJI="⚠️"
    fi

    MESSAGE="${EMOJI} *Disk Space Alert*

Current Usage: *${DISK_USAGE}%*
Threshold: ${THRESHOLD}%

Details:
• Filesystem: ${FILESYSTEM}
• Size: ${SIZE}
• Used: ${USED}
• Available: ${AVAIL}
• Mount: ${MOUNT}

Action needed to free up space!"

    telegram_send_with_buttons "$MESSAGE" \
        "📊 Show Top Files|disk_topfiles" \
        "🗑️ Clean Apt Cache|disk_cleanup" \
        "❌ Dismiss|dismiss"

    echo "Alert sent: Disk usage at ${DISK_USAGE}%"
else
    echo "Disk usage OK: ${DISK_USAGE}% (threshold: ${THRESHOLD}%)"
fi

exit 0
