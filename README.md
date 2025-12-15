# Server Monitoring Package

Automated monitoring scripts for Linux servers with push notifications via ntfy.sh.

## What's Included

This package includes three monitoring scripts with systemd timers:

1. **Disk Space Monitor** - Alerts when disk usage exceeds threshold (default 80%)
   - Runs every 6 hours
   - Checks root filesystem usage

2. **SSL Certificate Monitor** - Alerts when SSL certificates are expiring
   - Runs daily at 06:00
   - Warning at 14 days, critical at 7 days
   - Works with certbot/Let's Encrypt

3. **Security Updates Monitor** - Alerts when security updates are available
   - Runs daily at 08:00
   - Critical alert at 5+ security updates
   - Ubuntu/Debian systems with apt

## Requirements

- Linux system with systemd
- Root access for installation
- Internet connection for notifications
- For certificate monitoring: certbot installed
- For security monitoring: Ubuntu/Debian with apt

## Installation

### 1. Extract the package

```bash
# If you received a tarball
tar -xzf monitoring-package.tar.gz
cd monitoring-package
```

### 2. Customize configuration

Edit `monitoring.conf` to customize settings:

```bash
nano monitoring.conf
```

Key settings:
- `NTFY_TOPIC` - Unique notification topic for this server
- `DISK_THRESHOLD` - Disk usage percentage to trigger alert
- `CERT_WARNING_DAYS` - Days before expiry for warning
- `CERT_CRITICAL_DAYS` - Days before expiry for critical alert
- Security update thresholds

**Important**: Each server should have a unique `NTFY_TOPIC` (e.g., `server-alerts-web01`, `server-alerts-db01`)

### 3. Run installation script

```bash
sudo ./install.sh
```

The installer will:
- Copy scripts to `/usr/local/bin/`
- Apply your configuration
- Install systemd timers and services
- Enable and start all monitors

### 4. Subscribe to notifications

**Mobile App** (iOS/Android):
1. Install the ntfy app from app store
2. Add subscription to your topic (from `monitoring.conf`)
3. Receive push notifications instantly

**Web Browser**:
- Visit: `https://ntfy.sh/YOUR_TOPIC_NAME`

**Desktop Notifications** (Linux/Mac):
```bash
# Install jq first: sudo apt install jq
curl -s ntfy.sh/YOUR_TOPIC_NAME/json | \
    while read msg; do
        notify-send "$(echo $msg | jq -r .title)" "$(echo $msg | jq -r .message)"
    done
```

## Testing

Test each monitor manually after installation:

```bash
# Test disk space monitor
/usr/local/bin/check-disk-space.sh

# Test certificate monitor (requires certbot)
/usr/local/bin/check-cert-expiry.sh

# Test security updates monitor
/usr/local/bin/check-security-updates.sh
```

Send a test notification:
```bash
curl -d "Test from $(hostname)" https://ntfy.sh/YOUR_TOPIC_NAME
```

## Verification

Check that timers are running:
```bash
systemctl list-timers
```

You should see:
- `disk-monitor.timer`
- `cert-expiry-check.timer`
- `security-updates-check.timer`

Check service logs:
```bash
journalctl -u disk-monitor.service -n 20
journalctl -u cert-expiry-check.service -n 20
journalctl -u security-updates-check.service -n 20
```

## Uninstallation

To completely remove all monitoring:

```bash
sudo ./uninstall.sh
```

This will:
- Stop and disable all timers
- Remove systemd units
- Remove scripts from `/usr/local/bin/`
- Clean up log files

## Notification Examples

**Disk Space Alert** (High Priority):
```
🚨 Disk Space Warning

Current Usage: 85%
Threshold: 80%

Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       100G   85G   15G  85% /

Please check and free up space soon!
```

**SSL Certificate Expiring** (Critical):
```
🚨 SSL Certificate Expiring Soon!

CRITICAL: SSL certificate for example.com expires in 5 days!

Expiry Date: 2025-12-20
Days Remaining: 5

⚠️ URGENT ACTION REQUIRED
```

**Security Updates** (Urgent):
```
🚨 Critical Security Updates!

Server: web01
Security Updates: 8
Total Updates: 15

Critical packages: openssl, nginx, kernel...

🔧 To update:
  sudo apt update
  sudo apt upgrade
```

## File Locations

After installation:

```
/usr/local/bin/
├── check-disk-space.sh
├── check-cert-expiry.sh
└── check-security-updates.sh

/etc/systemd/system/
├── disk-monitor.timer
├── disk-monitor.service
├── cert-expiry-check.timer
├── cert-expiry-check.service
├── security-updates-check.timer
└── security-updates-check.service

/var/log/
├── cert-expiry-check.log
└── security-updates-check.log
```

## Customization

### Change notification topic after installation

Edit each script in `/usr/local/bin/` and update the `NTFY_TOPIC` variable:

```bash
sudo nano /usr/local/bin/check-disk-space.sh
# Change: NTFY_TOPIC="new-topic-name"
```

### Change thresholds after installation

**Disk space threshold**:
```bash
sudo nano /usr/local/bin/check-disk-space.sh
# Change: THRESHOLD=90  # for 90% threshold
```

**Certificate expiry days**:
```bash
sudo nano /usr/local/bin/check-cert-expiry.sh
# Change: WARNING_DAYS=30
# Change: CRITICAL_DAYS=14
```

**Security update thresholds**:
```bash
sudo nano /usr/local/bin/check-security-updates.sh
# Change: CRITICAL_THRESHOLD=10
# Change: WARNING_THRESHOLD=20
```

### Change timer schedules

Edit the timer files and reload systemd:

```bash
sudo nano /etc/systemd/system/disk-monitor.timer
# Modify OnUnitActiveSec= for different interval

sudo systemctl daemon-reload
sudo systemctl restart disk-monitor.timer
```

## Troubleshooting

### No notifications received

1. Check internet connectivity:
   ```bash
   curl -d "Test" https://ntfy.sh/YOUR_TOPIC
   ```

2. Verify ntfy.sh is accessible:
   ```bash
   ping ntfy.sh
   ```

3. Check if topic name is correct in scripts

### Certificate monitor not working

1. Verify certbot is installed:
   ```bash
   certbot --version
   ```

2. Check if certificates exist:
   ```bash
   certbot certificates
   ```

3. View logs for errors:
   ```bash
   journalctl -u cert-expiry-check.service -n 50
   ```

### Timers not running

1. Check timer status:
   ```bash
   systemctl status disk-monitor.timer
   ```

2. If inactive, enable and start:
   ```bash
   systemctl enable disk-monitor.timer
   systemctl start disk-monitor.timer
   ```

3. Check for errors:
   ```bash
   systemctl status disk-monitor.service
   ```

## Multi-Server Deployment

To deploy to multiple servers:

1. Copy the package to each server:
   ```bash
   scp -r monitoring-package/ user@server:/tmp/
   ```

2. SSH into each server:
   ```bash
   ssh user@server
   ```

3. Customize `monitoring.conf` with unique topic:
   ```bash
   cd /tmp/monitoring-package
   nano monitoring.conf
   # Change NTFY_TOPIC to something unique per server
   ```

4. Run install:
   ```bash
   sudo ./install.sh
   ```

5. Subscribe to all server topics in your ntfy app

**Tip**: Use a consistent naming scheme:
- `alerts-web01`, `alerts-web02` for web servers
- `alerts-db01`, `alerts-db02` for database servers
- Or use: `alerts-$(hostname)` for automatic hostname-based topics

## Privacy & Security

- ntfy.sh is a public notification service
- Topics are not encrypted by default
- Anyone who knows your topic name can subscribe
- Don't include sensitive data in notifications
- Consider self-hosting ntfy.sh for sensitive environments

For private notifications:
- Use obscure topic names (e.g., UUID)
- Or self-host ntfy: https://docs.ntfy.sh/install/

## Support

- ntfy.sh documentation: https://docs.ntfy.sh/
- Report issues with the package: Contact your system administrator

## License

These scripts are provided as-is for system administration purposes.

---

**Version**: 1.0
**Last Updated**: 2025-12-15
**Compatible**: Ubuntu/Debian with systemd
