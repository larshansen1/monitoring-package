# Telegram Bot Setup Guide

## Step 1: Create Your Telegram Bot

1. Open Telegram and search for **@BotFather**
2. Start a chat and send: `/newbot`
3. Follow the prompts:
   - Choose a name for your bot (e.g., "My Server Monitor")
   - Choose a username (must end in 'bot', e.g., "myserver_monitor_bot")
4. BotFather will give you a **BOT TOKEN** - save this!
   - Format: `1234567890:ABCdefGHIjklMNOpqrsTUVwxyz`

## Step 2: Get Your Chat ID

1. Start a chat with your new bot (click the link BotFather provides)
2. Send any message to your bot (e.g., "hello")
3. Run this command to get your chat ID:
   ```bash
   curl https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
   ```
4. Look for `"chat":{"id":123456789` - that number is your **CHAT_ID**

## Step 3: Configure the Bot

1. Create the configuration file:
   ```bash
   sudo mkdir -p /etc/monitoring
   sudo nano /etc/monitoring/telegram.conf
   ```

2. Add your credentials:
   ```bash
   TELEGRAM_BOT_TOKEN="your_bot_token_here"
   TELEGRAM_CHAT_ID="your_chat_id_here"
   ```

3. Set secure permissions:
   ```bash
   sudo chmod 600 /etc/monitoring/telegram.conf
   sudo chown root:root /etc/monitoring/telegram.conf
   ```

## Step 4: Install Dependencies

```bash
sudo apt update
sudo apt install -y python3 python3-pip
sudo pip3 install python-telegram-bot --upgrade
```

## Step 5: Install the Bot Handler

```bash
# Copy the bot handler to system location
sudo cp telegram-bot-handler.py /usr/local/bin/
sudo chmod +x /usr/local/bin/telegram-bot-handler.py

# Copy runbook scripts
sudo cp -r runbooks /etc/monitoring/
sudo chmod +x /etc/monitoring/runbooks/*.sh

# Install systemd service
sudo cp systemd/telegram-bot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable telegram-bot.service
sudo systemctl start telegram-bot.service
```

## Step 6: Test

Send a test notification:
```bash
./scripts/send-test-notification.sh
```

You should receive a message in Telegram!

## Verify Bot is Running

```bash
sudo systemctl status telegram-bot.service
sudo journalctl -u telegram-bot.service -f
```

## Security Notes

- The bot token is like a password - keep it secret!
- Only your CHAT_ID can interact with the bot
- The bot will reject commands from other users
- All config files are owned by root with 600 permissions
- Runbooks execute with limited sudo permissions
