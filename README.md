# Server Monitoring with Telegram

Interactive server monitoring system with Telegram bot integration. Get alerts about your server's health and take action directly from your phone.

## 🚀 Quick Start

**New Installation:**
```bash
# 1. Set up your Telegram bot (get token from @BotFather)
# 2. Create your local config from the template (telegram.conf is gitignored)
cp telegram.conf.example telegram.conf
nano telegram.conf

# 3. Run installer
sudo ./install.sh

# 4. Start the bot
sudo systemctl start telegram-bot
sudo systemctl enable telegram-bot

# 5. Test it
./tests/send-test-notification.sh
```

👉 **See [docs/QUICKSTART.md](docs/QUICKSTART.md) for detailed setup**

---

## ✨ Features

### Monitoring Scripts
- 🔒 **Security Updates** - Alerts when critical updates are available
- 🐳 **Container Updates** - Tracks Docker container image updates
- 💾 **Disk Space** - Monitors disk usage
- 🔐 **SSL Certificates** - Checks certificate expiration
- 🛡️ **Fail2ban Status** - Daily security reports

### Interactive Actions
All alerts include **action buttons** to:
- Update server packages
- Update and restart containers
- Renew SSL certificates
- Clean up disk space
- View detailed status

### Automated Runbooks
Click a button → Bot executes the action → Returns results
- No SSH needed
- Secure (only your chat ID can interact)
- Full audit trail in logs

---

## 📁 Project Structure

```
monitoring-package/
├── README.md                     # ← You are here
│
├── docs/                         # Documentation
│   ├── QUICKSTART.md            # 5-minute setup guide
│   ├── TELEGRAM_SETUP.md        # Telegram bot configuration
│   ├── RUNBOOKS.md              # All runbooks explained
│   └── TELEGRAM_MIGRATION.md    # Migrating from ntfy
│
├── scripts/                      # Monitoring scripts (Telegram)
│   ├── check-security-updates.sh
│   ├── check-container-updates.sh
│   ├── check-disk-space.sh
│   ├── check-cert-expiry.sh
│   └── fail2ban-daily-status.sh
│
├── runbooks/                    # Automated action scripts
│   ├── update-server.sh         # System updates
│   ├── update-containers.sh     # Container updates
│   ├── cert-renew.sh           # Certificate renewal
│   ├── cert-status.sh          # Certificate status
│   ├── disk-cleanup.sh         # Disk cleanup
│   ├── disk-topfiles.sh        # Disk analysis
│   └── fail2ban-status.sh      # Fail2ban details
│
├── lib/
│   └── telegram-notify.sh       # Notification library
│
├── systemd/                     # Bot service + one service/timer per check
│   ├── telegram-bot.service
│   ├── disk-monitor.{service,timer}
│   ├── cert-expiry-check.{service,timer}
│   ├── security-updates-check.{service,timer}
│   ├── container-updates-check.{service,timer}
│   └── fail2ban-status.{service,timer}
│
├── sudoers.d/
│   └── monitoring-runbooks      # NOPASSWD entries for runbook execution
│
├── tests/                       # Test scripts
│   ├── send-test-notification.sh
│   ├── test-buttons-notification.sh
│   └── test-simple-notification.sh
│
├── telegram-bot-handler.py      # Main bot application
├── telegram.conf.example        # Credential template (copy to telegram.conf)
├── install.sh                   # Installation script
└── uninstall.sh                 # Uninstallation script
```

---

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| **[QUICKSTART.md](docs/QUICKSTART.md)** | Get started in 5 minutes |
| **[TELEGRAM_SETUP.md](docs/TELEGRAM_SETUP.md)** | How to create and configure your bot |
| **[RUNBOOKS.md](docs/RUNBOOKS.md)** | All automated actions explained |
| **[TELEGRAM_MIGRATION.md](docs/TELEGRAM_MIGRATION.md)** | Migrating from ntfy.sh |

---

## 🖥️ Deploying to an additional server

The package is host-agnostic: everything installs to fixed system paths
(`/etc/monitoring`, `/usr/local/bin`, `/usr/local/lib/monitoring`,
`/etc/systemd/system`), so the clone location does not matter.

```bash
git clone git@github.com:larshansen1/monitoring-package.git
cd monitoring-package
cp telegram.conf.example telegram.conf
nano telegram.conf                     # new bot token + your chat ID
sudo ./install.sh
sudo systemctl enable --now telegram-bot
sudo ./tests/send-test-notification.sh
```

**Use a separate bot token per server.** The chat ID stays the same (it is your
account), so all servers report into the same Telegram chat, but a distinct bot
per host means you can tell who is talking and revoke one without silencing the
rest. Every alert is footed with `Server: $(hostname)`.

Checks degrade gracefully — `install.sh` warns rather than fails if `docker`,
`certbot` or `fail2ban` are absent, but the matching timer will then report an
error each run. Disable the ones that do not apply:

```bash
sudo systemctl disable --now container-updates-check.timer   # no docker
sudo systemctl disable --now cert-expiry-check.timer         # no certbot
sudo systemctl disable --now fail2ban-status.timer           # no fail2ban
```

Thresholds (disk %, cert warning days, update counts) are currently constants at
the top of each script in `scripts/` — edit them there before installing.

---

## 🎯 How It Works

1. **Monitoring scripts** run on schedule (via systemd timers)
2. Scripts detect issues (updates available, low disk, etc.)
3. **Telegram message** sent with interactive buttons
4. You **click a button** (e.g., "Update Server")
5. **Bot executes** the corresponding runbook
6. **Results** shown in Telegram immediately

---

## 🔧 Common Commands

### Bot Management
```bash
# Check bot status
sudo systemctl status telegram-bot

# View bot logs
sudo journalctl -u telegram-bot -f

# Restart bot
sudo systemctl restart telegram-bot
```

### Testing
```bash
# Send test notification
./tests/send-test-notification.sh

# Run monitoring scripts manually
sudo ./scripts/check-security-updates.sh
sudo ./scripts/check-container-updates.sh
sudo ./scripts/check-disk-space.sh
```

### View Logs
```bash
# Runbook logs
sudo tail -f /var/log/*-runbook.log

# Monitoring logs
sudo tail -f /var/log/security-updates-check.log
sudo tail -f /var/log/cert-expiry-check.log
```

---

## 🛡️ Security

- ✅ **Private bot** - Only you have the token
- ✅ **Authenticated** - Only your chat ID can interact
- ✅ **Encrypted** - Telegram end-to-end encryption
- ✅ **Audited** - All actions logged
- ✅ **No public exposure** - Bot only responds to you

**vs. ntfy.sh:**
- ❌ Public topics (anyone can subscribe if they guess the name)
- ❌ No authentication
- ❌ One-way only

---

## 📋 Requirements

- Linux system with systemd
- Docker (for container monitoring)
- Python 3 with venv support
- Certbot (for SSL monitoring)
- Telegram account

---

## 🆘 Troubleshooting

**Bot not responding?**
```bash
sudo systemctl status telegram-bot
sudo journalctl -u telegram-bot -n 50
```

**Buttons not working?**
```bash
# Check runbook logs
sudo ls -lh /var/log/*-runbook.log
sudo tail -f /var/log/*-runbook.log
```

**Test configuration:**
```bash
source /etc/monitoring/telegram.conf
curl "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe"
```

---

## 📝 System Timers

Active monitoring schedules:

| Monitor | Schedule | Purpose |
|---------|----------|---------|
| Security Updates | Daily at 08:00 | Check for security patches |
| Containers | Daily at 00:00 | Check for image updates |
| Disk Space | Every 6 hours | Monitor disk usage |
| Certificates | Daily at 06:00 | Check SSL expiration |
| Fail2ban | Daily at 06:00 | Security status report |

View schedules:
```bash
systemctl list-timers --all
```

---

## 🔄 Updating

To update scripts or runbooks:

```bash
# Update monitoring scripts
sudo cp scripts/*.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/*.sh

# Update runbooks
sudo cp runbooks/*.sh /etc/monitoring/runbooks/
sudo chmod +x /etc/monitoring/runbooks/*.sh

# Update bot handler
sudo cp telegram-bot-handler.py /usr/local/bin/
sudo systemctl restart telegram-bot
```

---

## 🗑️ Uninstallation

```bash
sudo ./uninstall.sh
```

This will remove:
- Telegram bot service and handler
- All monitoring scripts from `/usr/local/bin/`
- All runbooks from `/etc/monitoring/`
- All systemd timers and services
- Configuration files and logs

The source directory (`monitoring-package/`) will remain - delete manually if desired.

---

## 📦 What's Included

- **5 monitoring scripts** with interactive buttons
- **7 automated runbooks** for common tasks
- **Telegram bot handler** with Python
- **Notification library** for easy integration
- **Complete documentation**
- **Systemd integration**

---

## 🎓 Learn More

- **Telegram Bot API:** https://core.telegram.org/bots
- **Docker Compose:** https://docs.docker.com/compose/
- **Systemd Timers:** https://wiki.archlinux.org/title/Systemd/Timers

---

## 📄 License

MIT License - Free to use and modify

---

**Version:** 2.0 (Telegram)
**Last Updated:** 2025-12-23
**Platform:** Ubuntu/Debian with systemd
