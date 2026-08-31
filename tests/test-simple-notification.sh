#!/bin/bash
#
# Simple test - send a basic notification
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load config
# Credentials live in /etc/monitoring (mode 0600, root) - run these tests with sudo.
CONF=/etc/monitoring/telegram.conf
[ -f "$CONF" ] || CONF="${SCRIPT_DIR}/../telegram.conf"
if [ ! -r "$CONF" ]; then
    echo "ERROR: cannot read $CONF (try: sudo $0)" >&2
    exit 1
fi
source "$CONF"

echo "Sending simple test notification..."
echo "Bot Token: ${TELEGRAM_BOT_TOKEN:0:10}... (truncated)"
echo "Chat ID: ${TELEGRAM_CHAT_ID}"
echo ""

# Send simple message via curl
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": \"${TELEGRAM_CHAT_ID}\",
        \"text\": \"✅ Test Notification from $(hostname)\n\nThis is a simple test message!\n\nTime: $(date +'%Y-%m-%d %H:%M:%S')\"
    }")

echo "Response from Telegram:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
echo ""

# Check if successful
if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "✓ SUCCESS! Check your Telegram app for the message."
else
    echo "✗ FAILED! Check the error message above."
fi
