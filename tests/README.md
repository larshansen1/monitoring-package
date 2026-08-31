# Test Scripts

These scripts help you test your Telegram bot and notification system.

## Available Tests

### send-test-notification.sh

**Purpose:** Send a simple test notification to verify the Telegram library works.

**Usage:**
```bash
./tests/send-test-notification.sh
```

**What it does:**
- Loads the Telegram notification library
- Sends a basic alert message
- Confirms delivery

**Use when:**
- First time setup verification
- Testing after configuration changes
- Troubleshooting notification issues

---

### test-simple-notification.sh

**Purpose:** Test basic Telegram API connectivity with a plain message.

**Usage:**
```bash
./tests/test-simple-notification.sh
```

**What it does:**
- Sends a simple text message via Telegram API
- Shows API response (success/failure)
- No buttons, just basic connectivity test

**Use when:**
- Verifying bot token is valid
- Testing API connectivity
- Debugging connection issues

**Example output:**
```json
{
    "ok": true,
    "result": {
        "message_id": 3,
        "text": "✅ Test Notification from $(hostname)..."
    }
}
✓ SUCCESS! Check your Telegram app for the message.
```

---

### test-buttons-notification.sh

**Purpose:** Test interactive buttons functionality.

**Usage:**
```bash
./tests/test-buttons-notification.sh
```

**What it does:**
- Sends a notification with interactive buttons
- Tests button rendering in Telegram
- Simulates a real monitoring alert

**Includes buttons:**
- 🔄 Update Now
- 📅 Schedule Update
- ❌ Dismiss

**Use when:**
- Testing button functionality
- Verifying bot handler is running
- Demonstrating interactive features

**Note:** The bot handler must be running for buttons to work!

---

## Testing Workflow

### 1. Initial Setup Test

After installation, run these in order:

```bash
# Test 1: Basic API connectivity
./tests/test-simple-notification.sh

# Test 2: Notification library
./tests/send-test-notification.sh

# Test 3: Interactive buttons
./tests/test-buttons-notification.sh
```

### 2. Verify Bot Handler

Before testing buttons:
```bash
# Check bot is running
sudo systemctl status telegram-bot

# If not running, start it
sudo systemctl start telegram-bot
```

### 3. Test Button Clicks

1. Run `./tests/test-buttons-notification.sh`
2. Check your Telegram app
3. Click one of the buttons
4. Verify the message updates with the result

---

## Troubleshooting

### No messages received

**Check configuration:**
```bash
source telegram.conf
echo "Token: ${TELEGRAM_BOT_TOKEN:0:10}..."
echo "Chat ID: $TELEGRAM_CHAT_ID"
```

**Test API manually:**
```bash
source telegram.conf
curl "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe"
```

### Buttons don't work

**Check bot handler:**
```bash
sudo systemctl status telegram-bot
sudo journalctl -u telegram-bot -n 50
```

**Restart bot:**
```bash
sudo systemctl restart telegram-bot
```

### Wrong chat receiving messages

**Verify chat ID:**
```bash
# Get your actual chat ID
curl "https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates"
```

Look for your message and find the chat ID. Update `telegram.conf` if needed.

---

## Integration Testing

After verifying test scripts work, test the full monitoring workflow:

```bash
# Test each monitoring script
sudo ./scripts/check-security-updates.sh
sudo ./scripts/check-container-updates.sh
sudo ./scripts/check-disk-space.sh
sudo ./scripts/check-cert-expiry.sh
sudo ./scripts/fail2ban-daily-status.sh
```

Check Telegram for messages and try clicking the action buttons!

---

## Clean Up

Test scripts don't create any persistent files except for:
- Temporary messages in Telegram (can be deleted)
- Log entries in bot logs

No cleanup required.
