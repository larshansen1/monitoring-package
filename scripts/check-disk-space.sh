#!/bin/bash
#
# Disk Space Monitor - Send notification when disk usage exceeds threshold
#

# Configuration
THRESHOLD=80  # Alert when disk usage exceeds this percentage
NTFY_TOPIC="madmetal-server-alerts-$(hostname)"  # Unique topic for your server
NTFY_URL="https://ntfy.sh/${NTFY_TOPIC}"

# Get disk usage percentage (without the % sign)
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
DISK_INFO=$(df -h / | tail -1)

# Check if usage exceeds threshold
if [ "$DISK_USAGE" -ge "$THRESHOLD" ]; then
    MESSAGE="⚠️ Disk Space Alert on $(hostname)

Current Usage: ${DISK_USAGE}%
Threshold: ${THRESHOLD}%

${DISK_INFO}

Please check and free up space soon!"

    # Send notification via ntfy.sh
    curl -H "Title: 🚨 Disk Space Warning" \
         -H "Priority: high" \
         -H "Tags: warning,disk" \
         -d "$MESSAGE" \
         "$NTFY_URL"

    echo "Alert sent: Disk usage at ${DISK_USAGE}%"
else
    echo "Disk usage OK: ${DISK_USAGE}% (threshold: ${THRESHOLD}%)"
fi
