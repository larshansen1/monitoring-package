#!/bin/bash
#
# Server Monitoring Installation Script
# Installs disk space, SSL certificate, and security update monitors
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Server Monitoring Installation ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: This script must be run as root${NC}"
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if configuration file exists
if [ ! -f "$SCRIPT_DIR/monitoring.conf" ]; then
    echo -e "${RED}ERROR: Configuration file monitoring.conf not found${NC}"
    exit 1
fi

# Load configuration
source "$SCRIPT_DIR/monitoring.conf"

echo "Configuration:"
echo "  NTFY Topic: $NTFY_TOPIC"
echo "  Disk Threshold: ${DISK_THRESHOLD}%"
echo "  Cert Warning: ${CERT_WARNING_DAYS} days"
echo "  Cert Critical: ${CERT_CRITICAL_DAYS} days"
echo ""

# Ask for confirmation
read -p "Install monitoring scripts with these settings? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo -e "${GREEN}Step 1: Installing scripts...${NC}"

# Copy scripts to /usr/local/bin
cp "$SCRIPT_DIR/scripts/check-disk-space.sh" /usr/local/bin/
cp "$SCRIPT_DIR/scripts/check-cert-expiry.sh" /usr/local/bin/
cp "$SCRIPT_DIR/scripts/check-security-updates.sh" /usr/local/bin/

# Set permissions
chmod 711 /usr/local/bin/check-disk-space.sh
chmod 711 /usr/local/bin/check-cert-expiry.sh
chmod 711 /usr/local/bin/check-security-updates.sh

echo -e "${GREEN}✓ Scripts installed${NC}"

echo ""
echo -e "${GREEN}Step 2: Applying configuration...${NC}"

# Update scripts with configuration values
sed -i "s/^THRESHOLD=.*/THRESHOLD=${DISK_THRESHOLD}/" /usr/local/bin/check-disk-space.sh
sed -i "s/^NTFY_TOPIC=.*/NTFY_TOPIC=\"${NTFY_TOPIC}\"/" /usr/local/bin/check-disk-space.sh

sed -i "s/^WARNING_DAYS=.*/WARNING_DAYS=${CERT_WARNING_DAYS}/" /usr/local/bin/check-cert-expiry.sh
sed -i "s/^CRITICAL_DAYS=.*/CRITICAL_DAYS=${CERT_CRITICAL_DAYS}/" /usr/local/bin/check-cert-expiry.sh
sed -i "s/^NTFY_TOPIC=.*/NTFY_TOPIC=\"${NTFY_TOPIC}\"/" /usr/local/bin/check-cert-expiry.sh

sed -i "s/^NTFY_TOPIC=.*/NTFY_TOPIC=\"${NTFY_TOPIC}\"/" /usr/local/bin/check-security-updates.sh
sed -i "s/^CRITICAL_THRESHOLD=.*/CRITICAL_THRESHOLD=${SECURITY_CRITICAL_THRESHOLD}/" /usr/local/bin/check-security-updates.sh
sed -i "s/^WARNING_THRESHOLD=.*/WARNING_THRESHOLD=${SECURITY_WARNING_THRESHOLD}/" /usr/local/bin/check-security-updates.sh

echo -e "${GREEN}✓ Configuration applied${NC}"

echo ""
echo -e "${GREEN}Step 3: Installing systemd units...${NC}"

# Copy systemd files
cp "$SCRIPT_DIR/systemd/"*.service /etc/systemd/system/
cp "$SCRIPT_DIR/systemd/"*.timer /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

echo -e "${GREEN}✓ Systemd units installed${NC}"

echo ""
echo -e "${GREEN}Step 4: Enabling and starting timers...${NC}"

# Enable and start timers
systemctl enable disk-monitor.timer
systemctl start disk-monitor.timer

systemctl enable cert-expiry-check.timer
systemctl start cert-expiry-check.timer

systemctl enable security-updates-check.timer
systemctl start security-updates-check.timer

echo -e "${GREEN}✓ Timers enabled and started${NC}"

echo ""
echo -e "${GREEN}Step 5: Verifying installation...${NC}"

# Check timer status
echo ""
systemctl list-timers --no-pager | grep -E "disk-monitor|cert-expiry|security-updates" || true

echo ""
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo ""
echo "Monitoring scripts installed:"
echo "  • Disk Space Monitor (every 6 hours)"
echo "  • SSL Certificate Monitor (daily at 06:00)"
echo "  • Security Updates Monitor (daily at 08:00)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Subscribe to ntfy.sh notifications:"
echo "   Topic: ${NTFY_TOPIC}"
echo "   Mobile: Install ntfy app and subscribe to the topic"
echo "   Web: https://ntfy.sh/${NTFY_TOPIC}"
echo ""
echo "2. Test the monitors manually:"
echo "   /usr/local/bin/check-disk-space.sh"
echo "   /usr/local/bin/check-cert-expiry.sh"
echo "   /usr/local/bin/check-security-updates.sh"
echo ""
echo "3. Check timer status:"
echo "   systemctl list-timers"
echo ""
echo "4. View logs:"
echo "   journalctl -u disk-monitor.service"
echo "   journalctl -u cert-expiry-check.service"
echo "   journalctl -u security-updates-check.service"
echo ""
