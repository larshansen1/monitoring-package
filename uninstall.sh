#!/bin/bash
#
# Server Monitoring Uninstallation Script
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Server Monitoring Uninstallation ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: This script must be run as root${NC}"
    exit 1
fi

# Ask for confirmation
echo -e "${RED}WARNING: This will remove all monitoring scripts and timers${NC}"
read -p "Are you sure you want to uninstall? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo ""
echo "Stopping and disabling timers..."
systemctl stop disk-monitor.timer || true
systemctl disable disk-monitor.timer || true

systemctl stop cert-expiry-check.timer || true
systemctl disable cert-expiry-check.timer || true

systemctl stop security-updates-check.timer || true
systemctl disable security-updates-check.timer || true

echo "Removing systemd units..."
rm -f /etc/systemd/system/disk-monitor.timer
rm -f /etc/systemd/system/disk-monitor.service
rm -f /etc/systemd/system/cert-expiry-check.timer
rm -f /etc/systemd/system/cert-expiry-check.service
rm -f /etc/systemd/system/security-updates-check.timer
rm -f /etc/systemd/system/security-updates-check.service

echo "Reloading systemd..."
systemctl daemon-reload

echo "Removing scripts..."
rm -f /usr/local/bin/check-disk-space.sh
rm -f /usr/local/bin/check-cert-expiry.sh
rm -f /usr/local/bin/check-security-updates.sh

echo "Removing log files..."
rm -f /var/log/cert-expiry-check.log
rm -f /var/log/security-updates-check.log

echo ""
echo -e "${GREEN}Uninstallation complete${NC}"
