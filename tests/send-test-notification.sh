#!/bin/bash
#
# Send a test Telegram notification
#

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load Telegram notification library
# Prefer the installed library; fall back to the repo copy (run before install.sh).
if [ -f /usr/local/lib/monitoring/telegram-notify.sh ]; then
    source /usr/local/lib/monitoring/telegram-notify.sh
else
    source "${SCRIPT_DIR}/../lib/telegram-notify.sh"
fi

echo "Sending test notification to Telegram..."

# Send a simple test
telegram_send_alert "info" "Test Notification" \
    "This is a test message from your monitoring system!

Everything is working correctly.

Time: $(date +'%Y-%m-%d %H:%M:%S')"

echo "✓ Test notification sent!"
echo ""
echo "Check your Telegram to see if you received it."
