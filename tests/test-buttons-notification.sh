#!/bin/bash
#
# Test notification with interactive buttons
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

echo "Sending notification with interactive buttons..."
echo ""

# Build the message with buttons
MESSAGE="🚨 *Security Updates Available*

Server: $(hostname)
Security Updates: 5
Total Updates: 12

Critical packages:
  • linux-image-generic
  • openssl
  • curl

What would you like to do?"

# Create inline keyboard with buttons
KEYBOARD='[
    [{"text":"🔄 Update Now","callback_data":"update_server"}],
    [{"text":"📅 Schedule Update","callback_data":"schedule_update"}],
    [{"text":"❌ Dismiss","callback_data":"dismiss"}]
]'

# Send message with buttons
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": \"${TELEGRAM_CHAT_ID}\",
        \"text\": \"${MESSAGE}\",
        \"parse_mode\": \"Markdown\",
        \"reply_markup\": {
            \"inline_keyboard\": ${KEYBOARD}
        }
    }")

echo "Response from Telegram:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
echo ""

# Check if successful
if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "✓ SUCCESS! Check your Telegram app for the message with buttons."
    echo ""
    echo "NOTE: The buttons won't work yet because the bot handler isn't running."
    echo "But you should see the buttons displayed in the message!"
else
    echo "✗ FAILED! Check the error message above."
fi
