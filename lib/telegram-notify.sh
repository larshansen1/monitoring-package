#!/bin/bash
#
# Telegram Notification Library
# Source this file in your monitoring scripts to send Telegram notifications
#
# Usage:
#   source /path/to/telegram-notify.sh
#   telegram_send "Message title" "Message body" "priority" "tag1,tag2"
#   telegram_send_with_buttons "Title" "Body" "button1_label|button1_callback" "button2_label|button2_callback"
#

# Load configuration
TELEGRAM_CONFIG="/etc/monitoring/telegram.conf"

if [ -f "$TELEGRAM_CONFIG" ]; then
    source "$TELEGRAM_CONFIG"
else
    echo "ERROR: Telegram config not found: $TELEGRAM_CONFIG" >&2
    exit 1
fi

# Validate configuration
if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "ERROR: TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID must be set in $TELEGRAM_CONFIG" >&2
    exit 1
fi

TELEGRAM_API_URL="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"

#
# Send a simple text message
#
# Args:
#   $1 - Message text
#
telegram_send() {
    local message="$1"

    curl -s -X POST "${TELEGRAM_API_URL}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"${TELEGRAM_CHAT_ID}\",
            \"text\": \"${message}\",
            \"parse_mode\": \"Markdown\"
        }" > /dev/null
}

#
# Send a message with inline keyboard buttons
#
# Args:
#   $1 - Message text
#   $2+ - Button definitions in format "Label|callback_data" (one per argument)
#
# Example:
#   telegram_send_with_buttons "Security updates available" \
#       "Update Now|update_server" \
#       "Dismiss|dismiss"
#
telegram_send_with_buttons() {
    local message="$1"
    shift

    # Build inline keyboard JSON
    local buttons="["
    local first=true

    for button in "$@"; do
        IFS='|' read -r label callback <<< "$button"

        if [ "$first" = true ]; then
            first=false
        else
            buttons+=","
        fi

        # Each button on its own row
        buttons+="[{\"text\":\"${label}\",\"callback_data\":\"${callback}\"}]"
    done

    buttons+="]"

    # Escape message for JSON (basic escaping)
    local escaped_message=$(echo "$message" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

    curl -s -X POST "${TELEGRAM_API_URL}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"${TELEGRAM_CHAT_ID}\",
            \"text\": \"${escaped_message}\",
            \"parse_mode\": \"Markdown\",
            \"reply_markup\": {
                \"inline_keyboard\": ${buttons}
            }
        }" > /dev/null
}

#
# Send a formatted alert with severity
#
# Args:
#   $1 - Severity (info, warning, critical)
#   $2 - Title
#   $3 - Message body
#   $4+ - Optional button definitions
#
telegram_send_alert() {
    local severity="$1"
    local title="$2"
    local body="$3"
    shift 3

    # Choose emoji based on severity
    case "$severity" in
        critical)
            emoji="🚨"
            ;;
        warning)
            emoji="⚠️"
            ;;
        info)
            emoji="ℹ️"
            ;;
        success)
            emoji="✅"
            ;;
        *)
            emoji="📢"
            ;;
    esac

    local message="${emoji} *${title}*

${body}

_Server: $(hostname)_
_Time: $(date +'%Y-%m-%d %H:%M:%S')_"

    if [ $# -gt 0 ]; then
        telegram_send_with_buttons "$message" "$@"
    else
        telegram_send "$message"
    fi
}

# Export functions if being sourced
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    export -f telegram_send
    export -f telegram_send_with_buttons
    export -f telegram_send_alert
fi
