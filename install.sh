#!/bin/bash
#
# Installation script for Telegram Monitoring System
#

set -e

echo "=== Telegram Monitoring System Installation ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Step 0: Check for required commands
echo "[0/8] Checking prerequisites..."
if ! command -v fail2ban-client >/dev/null 2>&1; then
    echo "  ⚠️  Warning: fail2ban not installed (fail2ban monitoring will not work)"
fi
if ! command -v docker >/dev/null 2>&1; then
    echo "  ⚠️  Warning: docker not installed (container monitoring will not work)"
fi
if ! command -v certbot >/dev/null 2>&1; then
    echo "  ⚠️  Warning: certbot not installed (certificate monitoring will not work)"
fi
echo "  ✓ Prerequisites checked"

# Step 1: Install dependencies
echo "[1/8] Installing Python dependencies..."
apt-get update -qq
apt-get install -y python3 python3-venv python3-pip jq >/dev/null 2>&1
echo "  ✓ System dependencies installed"

# Create virtual environment for the bot
echo "[1.5/8] Creating Python virtual environment..."
mkdir -p /opt/telegram-bot
python3 -m venv /opt/telegram-bot/venv
/opt/telegram-bot/venv/bin/pip install --upgrade pip >/dev/null 2>&1
/opt/telegram-bot/venv/bin/pip install python-telegram-bot >/dev/null 2>&1
echo "  ✓ Virtual environment created and dependencies installed"

# Step 2: Create directories
echo "[2/8] Creating system directories..."
mkdir -p /etc/monitoring/runbooks
mkdir -p /var/log
echo "  ✓ Directories created"

# Step 3: Copy configuration
echo "[3/8] Setting up configuration..."
if [ -f /etc/monitoring/telegram.conf ]; then
    echo "  ✓ Keeping existing /etc/monitoring/telegram.conf (not overwritten)"
else
    if [ -f "${SCRIPT_DIR}/telegram.conf" ]; then
        SRC="${SCRIPT_DIR}/telegram.conf"
    else
        SRC="${SCRIPT_DIR}/telegram.conf.example"
        echo "  ⚠️  No telegram.conf found - installing the template."
    fi
    install -m 600 "$SRC" /etc/monitoring/telegram.conf
    echo "  ✓ Configuration installed to /etc/monitoring/telegram.conf (mode 0600)"
fi

# Refuse to continue with placeholder credentials - the bot would crash-loop.
if grep -qE 'your_bot_token_here|your_chat_id_here' /etc/monitoring/telegram.conf; then
    echo ""
    echo "  ACTION REQUIRED: /etc/monitoring/telegram.conf still has placeholders."
    echo "  Edit it with your bot token and chat ID, then re-run this installer:"
    echo "    sudo nano /etc/monitoring/telegram.conf"
    echo "    sudo ./install.sh"
    exit 1
fi

# Step 4: Install bot handler
echo "[4/8] Installing bot handler..."
cp "${SCRIPT_DIR}/telegram-bot-handler.py" /usr/local/bin/
chmod +x /usr/local/bin/telegram-bot-handler.py
echo "  ✓ Bot handler installed"

# Step 5: Install runbooks
echo "[5/8] Installing runbook scripts..."
cp "${SCRIPT_DIR}/runbooks/"*.sh /etc/monitoring/runbooks/
chmod +x /etc/monitoring/runbooks/*.sh
echo "  ✓ Runbooks installed"

# Step 6: Install library
echo "[6/8] Installing notification library..."
mkdir -p /usr/local/lib/monitoring
cp "${SCRIPT_DIR}/lib/telegram-notify.sh" /usr/local/lib/monitoring/
chmod +x /usr/local/lib/monitoring/telegram-notify.sh
echo "  ✓ Library installed"

# Step 7: Install monitoring scripts
echo "[7/8] Installing monitoring scripts..."
cp "${SCRIPT_DIR}/scripts/"*.sh /usr/local/bin/
chmod +x /usr/local/bin/check-*.sh /usr/local/bin/fail2ban-*.sh
echo "  ✓ Monitoring scripts installed"

# Step 8: Install systemd units
echo "[8/8] Installing systemd units..."
# Install telegram bot service
cp "${SCRIPT_DIR}/systemd/telegram-bot.service" /etc/systemd/system/

# Install all monitoring timers and services
cp "${SCRIPT_DIR}/systemd/"*.timer /etc/systemd/system/ 2>/dev/null || true
cp "${SCRIPT_DIR}/systemd/"*.service /etc/systemd/system/ 2>/dev/null || true

systemctl daemon-reload
echo "  ✓ Systemd units installed"

# Enable and start monitoring timers
echo "  Enabling monitoring timers..."
for timer in disk-monitor cert-expiry-check security-updates-check container-updates-check fail2ban-status; do
    if [ -f "/etc/systemd/system/${timer}.timer" ]; then
        systemctl enable "${timer}.timer" >/dev/null 2>&1 || true
        systemctl restart "${timer}.timer" >/dev/null 2>&1 || true
        echo "    ✓ ${timer}.timer enabled"
    fi
done

# Optional: Install sudoers
if [ -f "${SCRIPT_DIR}/sudoers.d/monitoring-runbooks" ]; then
    cp "${SCRIPT_DIR}/sudoers.d/monitoring-runbooks" /etc/sudoers.d/
    chmod 0440 /etc/sudoers.d/monitoring-runbooks
    # Validate sudoers file
    if visudo -c -f /etc/sudoers.d/monitoring-runbooks >/dev/null 2>&1; then
        echo "  ✓ Sudoers configuration installed"
    else
        echo "  ⚠️  Sudoers validation failed, removing file"
        rm /etc/sudoers.d/monitoring-runbooks
    fi
fi

echo ""
echo "=== Installation Complete! ==="
echo ""
echo "Next steps:"
echo "  1. Edit /etc/monitoring/telegram.conf with your bot token and chat ID"
echo "     nano /etc/monitoring/telegram.conf"
echo ""
echo "  2. Start the bot:"
echo "     sudo systemctl start telegram-bot"
echo "     sudo systemctl enable telegram-bot"
echo ""
echo "  3. Check status:"
echo "     sudo systemctl status telegram-bot"
echo ""
echo "  4. Test it:"
echo "     Send /test command to your bot in Telegram"
echo ""
echo "Monitoring timers installed and enabled:"
echo "  • disk-monitor (every 6 hours)"
echo "  • cert-expiry-check (daily at 06:00)"
echo "  • security-updates-check (daily at 08:00)"
echo "  • container-updates-check (daily at 00:00)"
echo "  • fail2ban-status (daily at 06:00)"
echo ""
echo "View timer schedules:"
echo "  systemctl list-timers"
echo ""
echo "Test monitoring scripts manually:"
echo "  sudo /usr/local/bin/check-security-updates.sh"
echo "  sudo /usr/local/bin/check-container-updates.sh"
echo "  sudo /usr/local/bin/fail2ban-daily-status.sh"
echo ""
