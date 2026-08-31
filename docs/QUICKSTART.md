# Telegram Monitoring - Quick Start Guide

## What You Have Now

A complete interactive monitoring system using Telegram with:
- ✅ **Secure** - Your bot token and chat ID are private
- ✅ **Interactive** - Click buttons to run actions
- ✅ **Automated runbooks** - Update server/containers with one click

## Quick Setup (5 minutes)

Run these from wherever you cloned the repo.

### 1. Create the bot and get your chat ID

1. In Telegram, message **@BotFather** → `/newbot` → copy the token.
   Use a **separate bot per server** so alerts are distinguishable.
2. Send any message to your new bot, then:
   ```bash
   curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" \
     | jq '.result[].message.chat.id'
   ```

### 2. Configure

```bash
cp telegram.conf.example telegram.conf
nano telegram.conf          # fill in TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID
```

`telegram.conf` is gitignored — it never gets committed.

### 3. Install

```bash
sudo ./install.sh
```

This installs dependencies, copies files to their system locations, installs
the systemd units, and enables the monitoring timers. It refuses to finish
while the config still has placeholder values.

### 4. Start the bot

```bash
sudo systemctl enable --now telegram-bot
sudo systemctl status telegram-bot
```

### 5. Test it

In Telegram send your bot `/start`, `/status`, then `/test` to get a message
with live buttons. From the shell:

```bash
sudo ./tests/send-test-notification.sh
```

## Using the Interactive Features

### Security Updates Alert

When your monitoring script detects security updates, you'll get a message with buttons:
- **🔄 Update Now** - Runs `apt update && apt upgrade` immediately
- **❌ Dismiss** - Ignore for now

Example usage in your scripts:
```bash
source /usr/local/lib/monitoring/telegram-notify.sh

telegram_send_with_buttons "Security updates available!" \
    "Update Now|update_server" \
    "Dismiss|dismiss"
```

### Available Runbooks

Located in `/etc/monitoring/runbooks/`:

| Runbook | What it does |
|---|---|
| `update-server.sh` | apt update + upgrade; reboots if `/var/run/reboot-required` |
| `update-containers.sh` | compose pull + recreate (targeted list, else all projects) |
| `cert-renew.sh` | certbot dry-run, then force renewal; reloads nginx/apache |
| `cert-status.sh` | certbot certificates + renewal timer status |
| `disk-cleanup.sh` | apt clean/autoremove, journal vacuum 3d, `docker system prune -f` |
| `disk-topfiles.sh` | largest dirs and files >100MB |
| `fail2ban-status.sh` | per-jail status for every jail |

> `disk-cleanup.sh` runs `docker system prune -f`. That removes stopped
> containers, unused networks, dangling images and build cache. It does **not**
> touch named volumes (no `--volumes`) or bind mounts, but any container you
> keep around in a stopped state will be removed.

### Adding More Runbooks

1. Create a new script in `runbooks/`:
```bash
sudo nano /etc/monitoring/runbooks/my-custom-action.sh
sudo chmod +x /etc/monitoring/runbooks/my-custom-action.sh
```

2. Add the callback handler in `telegram-bot-handler.py`:
```python
elif action == "myaction":
    await handle_my_action(query, param)
```

3. Use it in your notifications:
```bash
telegram_send_with_buttons "Something happened!" \
    "Do Action|myaction_param"
```

## Updating Your Existing Scripts

See the example: `scripts/check-security-updates.sh`

Basic pattern:
```bash
#!/bin/bash
source /usr/local/lib/monitoring/telegram-notify.sh

# Do your monitoring check...

# Send interactive alert
telegram_send_with_buttons "Alert message" \
    "Button 1|callback1" \
    "Button 2|callback2"
```

## Security Notes

- Bot token is stored in `/etc/monitoring/telegram.conf` (root only, 600 permissions)
- Only your chat ID can interact with the bot
- Runbooks execute as root (be careful what you add!)
- All actions are logged to systemd journal

## Troubleshooting

**Bot not responding:**
```bash
sudo systemctl status telegram-bot
sudo journalctl -u telegram-bot -f
```

**Test the config:**
```bash
source /etc/monitoring/telegram.conf
curl "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe"
```

**Check logs:**
```bash
sudo journalctl -u telegram-bot -n 50
```

## Next Steps

1. Update your existing monitoring scripts to use Telegram
2. Set up cron jobs or systemd timers for your scripts
3. Add more custom runbooks for common tasks
4. Consider adding scheduling features for non-urgent updates

## File Structure

```
/etc/monitoring/
├── telegram.conf                    # Your bot credentials
└── runbooks/
    ├── update-server.sh            # Server update runbook
    └── update-containers.sh        # Container update runbook

/usr/local/bin/
└── telegram-bot-handler.py         # Main bot process

/usr/local/lib/monitoring/
└── telegram-notify.sh              # Notification library

/etc/systemd/system/
└── telegram-bot.service            # Systemd service
```

## Help

- Check bot status: `/status` in Telegram
- Test notifications: `sudo ./tests/send-test-notification.sh`
- View logs: `sudo journalctl -u telegram-bot -f`
- Full setup guide: `docs/TELEGRAM_SETUP.md`
