#!/bin/bash
#
# Telegram Monitoring System Uninstallation Script
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Telegram Monitoring System Uninstallation ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: This script must be run as root${NC}"
    exit 1
fi

# Ask for confirmation
echo -e "${RED}WARNING: This will remove:${NC}"
echo "  - Telegram bot service"
echo "  - All monitoring scripts (/usr/local/bin/)"
echo "  - All runbooks (/etc/monitoring/)"
echo "  - Systemd timers and services"
echo "  - Configuration files"
echo "  - Log files"
echo ""
read -p "Are you sure you want to uninstall? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo ""
echo "[1/7] Stopping Telegram bot..."
systemctl stop telegram-bot.service 2>/dev/null || echo "  Bot service not running"
systemctl disable telegram-bot.service 2>/dev/null || echo "  Bot service not enabled"

echo "[2/7] Stopping and disabling monitoring timers..."
systemctl stop disk-monitor.timer 2>/dev/null || true
systemctl disable disk-monitor.timer 2>/dev/null || true

systemctl stop cert-expiry-check.timer 2>/dev/null || true
systemctl disable cert-expiry-check.timer 2>/dev/null || true

systemctl stop security-updates-check.timer 2>/dev/null || true
systemctl disable security-updates-check.timer 2>/dev/null || true

systemctl stop container-updates-check.timer 2>/dev/null || true
systemctl disable container-updates-check.timer 2>/dev/null || true

systemctl stop fail2ban-status.timer 2>/dev/null || true
systemctl disable fail2ban-status.timer 2>/dev/null || true

echo "[3/7] Removing systemd units..."
rm -f /etc/systemd/system/telegram-bot.service
rm -f /etc/systemd/system/disk-monitor.timer
rm -f /etc/systemd/system/disk-monitor.service
rm -f /etc/systemd/system/cert-expiry-check.timer
rm -f /etc/systemd/system/cert-expiry-check.service
rm -f /etc/systemd/system/security-updates-check.timer
rm -f /etc/systemd/system/security-updates-check.service
rm -f /etc/systemd/system/container-updates-check.timer
rm -f /etc/systemd/system/container-updates-check.service
rm -f /etc/systemd/system/fail2ban-status.timer
rm -f /etc/systemd/system/fail2ban-status.service

echo "[4/7] Reloading systemd..."
systemctl daemon-reload

echo "[5/7] Removing monitoring scripts..."
rm -f /usr/local/bin/check-disk-space.sh
rm -f /usr/local/bin/check-cert-expiry.sh
rm -f /usr/local/bin/check-security-updates.sh
rm -f /usr/local/bin/check-container-updates.sh
rm -f /usr/local/bin/fail2ban-daily-status.sh
rm -f /usr/local/bin/telegram-bot-handler.py

echo "[6/7] Removing configuration and runbooks..."
rm -rf /etc/monitoring
rm -rf /opt/telegram-bot
rm -f /etc/sudoers.d/monitoring-runbooks

echo "[7/7] Removing log files..."
rm -f /var/log/cert-expiry-check.log
rm -f /var/log/security-updates-check.log
rm -f /var/log/*-runbook.log

echo ""
echo -e "${GREEN}✓ Uninstallation complete!${NC}"
echo ""
echo "The monitoring-package directory with source files remains."
echo "Delete it manually if no longer needed:"
echo "  rm -rf $(pwd)"
echo ""
