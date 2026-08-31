# Runbooks Documentation

This document describes all the automated runbooks available in your Telegram monitoring system. Runbooks are scripts that execute automated responses to monitoring alerts.

## Table of Contents

1. [System Update Runbooks](#system-update-runbooks)
2. [Container Management Runbooks](#container-management-runbooks)
3. [Disk Management Runbooks](#disk-management-runbooks)
4. [Certificate Management Runbooks](#certificate-management-runbooks)
5. [Security Management Runbooks](#security-management-runbooks)
6. [How to Add New Runbooks](#how-to-add-new-runbooks)

---

## System Update Runbooks

### update-server.sh

**Purpose:** Updates all system packages and reboots if necessary.

**Triggered by:**
- Security Updates alerts
- Manual trigger via `/update_server` callback

**What it does:**
1. Updates package lists (`apt-get update`)
2. Upgrades all packages (`apt-get upgrade -y`)
3. Checks if reboot is required
4. Schedules reboot if needed (1 minute delay)
5. Logs all actions to `/var/log/server-update-runbook.log`

**Execution time:** 2-10 minutes (depending on updates)

**Requires reboot:** Sometimes (kernel updates, systemd updates)

**Location:** `/etc/monitoring/runbooks/update-server.sh`

**Example output:**
```
=== Server Update Runbook Started ===
Updating package lists...
Upgrading packages...
Reboot required after updates
Packages requiring reboot:
  linux-image-generic
  systemd
System will reboot in 1 minute...
=== Server Update Runbook Completed ===
```

**Safety notes:**
- Non-interactive mode (assumes yes to prompts)
- Schedules reboot with 1-minute delay for graceful shutdown
- All output logged for audit trail

---

## Container Management Runbooks

### update-containers.sh

**Purpose:** Updates and restarts Docker containers managed by docker-compose.

**Triggered by:**
- Container update alerts
- Manual trigger via `/update_containers` callback

**What it does:**
1. Finds all docker-compose projects (by labels or common locations)
2. For each project:
   - Pulls latest images (`docker-compose pull`)
   - Rebuilds local images if needed (`docker-compose build`)
   - Recreates containers (`docker-compose up -d --force-recreate`)
   - Checks container health
3. Logs all actions to `/var/log/container-update-runbook.log`

**Execution time:** 1-5 minutes per project

**Causes downtime:** Yes, brief (usually < 10 seconds per container)

**Location:** `/etc/monitoring/runbooks/update-containers.sh`

**Example output:**
```
=== Container Update Runbook Started ===
Updating project in: /opt/myapp
Pulling latest images...
Building local images...
Recreating containers...
Checking container status...
  myapp_web_1: running
  myapp_db_1: running
=== Container Update Runbook Completed ===
All containers have been updated and restarted
```

**Safety notes:**
- Uses `--force-recreate` to ensure clean restart
- Waits 3 seconds after restart before checking status
- Preserves data volumes

---

## Disk Management Runbooks

### disk-topfiles.sh

**Purpose:** Analyzes disk usage and identifies largest files/directories.

**Triggered by:**
- Disk space alerts (via "Show Top Files" button)
- Manual trigger via `/disk_topfiles` callback

**What it does:**
1. Reports current disk usage
2. Finds top 10 largest directories in `/`
3. Finds top 10 files over 100MB
4. Logs to `/var/log/disk-topfiles-runbook.log`

**Execution time:** 30-60 seconds

**Modifies system:** No (read-only)

**Location:** `/etc/monitoring/runbooks/disk-topfiles.sh`

**Example output:**
```
=== DISK USAGE REPORT ===

Current Usage: 78%

Top Directories:
50G     /var
20G     /home
15G     /usr
...

Top Large Files (>100MB):
5.2G    /var/lib/docker/overlay2/...
2.1G    /var/log/old-archive.log
500M    /home/user/backup.tar.gz
```

**Use cases:**
- Identify what's consuming disk space
- Find candidates for cleanup
- Quick triage before cleanup

---

### disk-cleanup.sh

**Purpose:** Automatically cleans up disk space using safe methods.

**Triggered by:**
- Disk space alerts (via "Clean Apt Cache" button)
- Manual trigger via `/disk_cleanup` callback

**What it does:**
1. Cleans apt package cache (`apt-get clean`)
2. Removes old/unused packages (`apt-get autoremove`)
3. Cleans old systemd journal logs (keeps last 3 days)
4. Prunes unused Docker resources (`docker system prune -f`)
5. Reports before/after disk usage
6. Logs to `/var/log/disk-cleanup-runbook.log`

**Execution time:** 1-3 minutes

**Modifies system:** Yes (removes files)

**Space recovered:** Typically 500MB - 5GB

**Location:** `/etc/monitoring/runbooks/disk-cleanup.sh`

**Example output:**
```
=== CLEANUP COMPLETE ===
Before: 45G
After: 41G
Current: 72%

Freed: 4GB
```

**Safety notes:**
- Only removes cache and unused files
- Does not delete user data
- Docker prune only removes unused images/containers
- Reversible via package manager (can re-download)

---

## Certificate Management Runbooks

### cert-status.sh

**Purpose:** Checks status of all SSL certificates and certbot configuration.

**Triggered by:**
- Certificate expiry warnings (via "Check Status" button)
- Manual trigger via `/cert_status` callback

**What it does:**
1. Lists all certificates via `certbot certificates`
2. Shows certbot timer status
3. Displays next scheduled renewal time
4. Logs to `/var/log/cert-status-runbook.log`

**Execution time:** < 5 seconds

**Modifies system:** No (read-only)

**Location:** `/etc/monitoring/runbooks/cert-status.sh`

**Example output:**
```
=== CERTIFICATE STATUS ===
Found the following certs:
  Certificate Name: example.com
    Domains: example.com www.example.com
    Expiry Date: 2025-03-23
    Valid: 45 days

=== CERTBOT TIMER STATUS ===
Status: Active
Next run: Tue 2025-12-24 06:00:00 UTC

=== NEXT SCHEDULED RENEWAL ===
Tue 2025-12-24 06:00:00 UTC
```

**Use cases:**
- Verify auto-renewal is working
- Check certificate details
- Troubleshoot renewal issues

---

### cert-renew.sh

**Purpose:** Manually renews SSL certificates.

**Triggered by:**
- Critical certificate expiry alerts (via "Renew Certificate" button)
- Manual trigger via `/cert_renew` callback

**What it does:**
1. Performs dry-run test first
2. If dry-run passes, forces certificate renewal
3. Reloads web server (nginx/apache2) if running
4. Logs to `/var/log/cert-renew-runbook.log`

**Execution time:** 10-30 seconds

**Modifies system:** Yes (renews certificates)

**Causes downtime:** No (graceful reload)

**Location:** `/etc/monitoring/runbooks/cert-renew.sh`

**Example output:**
```
=== RENEWAL SUCCESSFUL ===
Saving debug log to /var/log/letsencrypt/letsencrypt.log

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Processing /etc/letsencrypt/renewal/example.com.conf
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Cert not yet due for renewal

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
The following certs were renewed:
  /etc/letsencrypt/live/example.com/fullchain.pem (success)
```

**Safety notes:**
- Tests with dry-run before actual renewal
- Uses `--force-renewal` to bypass time checks
- Automatically reloads web server
- Fails safely if renewal issues occur

---

## Security Management Runbooks

### fail2ban-status.sh

**Purpose:** Shows detailed status of fail2ban jails and banned IPs.

**Triggered by:**
- Fail2ban daily status reports (via "View Full Status" button)
- Manual trigger via `/fail2ban_status` callback

**What it does:**
1. Checks if fail2ban service is running
2. Lists all active jails
3. Shows detailed status for each jail
4. Displays currently banned IPs
5. Shows fail2ban service status
6. Logs to `/var/log/fail2ban-status-runbook.log`

**Execution time:** < 5 seconds

**Modifies system:** No (read-only)

**Location:** `/etc/monitoring/runbooks/fail2ban-status.sh`

**Example output:**
```
=== FAIL2BAN GENERAL STATUS ===
Status
|- Number of jail:      3
`- Jail list:   sshd, nginx-http-auth, nginx-limit-req

=== JAIL: sshd ===
Status for the jail: sshd
|- Filter
|  |- Currently failed: 2
|  |- Total failed:     15
|  `- File list:        /var/log/auth.log
`- Actions
   |- Currently banned: 1
   |- Total banned:     3
   `- Banned IP list:   192.168.1.100

=== FAIL2BAN SERVICE STATUS ===
● fail2ban.service - Fail2Ban Service
     Active: active (running) since...
```

**Use cases:**
- Monitor attack attempts
- Verify fail2ban is protecting your server
- Identify patterns in attacks

---

## How to Add New Runbooks

### 1. Create the Runbook Script

Create a new bash script in `/etc/monitoring/runbooks/`:

```bash
#!/bin/bash
#
# My Custom Runbook
# Description of what it does
#

set -e

LOG_FILE="/var/log/my-runbook.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== My Runbook Started ==="

# Your logic here
# ...

log "=== My Runbook Completed ==="

exit 0
```

Make it executable:
```bash
sudo chmod +x /etc/monitoring/runbooks/my-runbook.sh
```

### 2. Add Handler to Bot

Edit `/usr/local/bin/telegram-bot-handler.py` and add your action handler:

```python
async def handle_mycategory_action(query, param):
    """Handle my category actions"""
    original_text = query.message.text

    if param == "myaction":
        await query.edit_message_text(
            f"{original_text}\n\n"
            f"⏳ Running my action..."
        )

        try:
            result = subprocess.run(
                [f"{RUNBOOKS_DIR}/my-runbook.sh"],
                capture_output=True,
                text=True,
                timeout=60
            )

            if result.returncode == 0:
                await query.edit_message_text(
                    f"{original_text}\n\n"
                    f"✅ Action completed!\n\n"
                    f"```\n{result.stdout[-500:]}\n```",
                    parse_mode='Markdown'
                )
            else:
                await query.edit_message_text(
                    f"{original_text}\n\n"
                    f"❌ Action failed!\n\n"
                    f"Error:\n```\n{result.stderr[-500:]}\n```",
                    parse_mode='Markdown'
                )
        except Exception as e:
            await query.edit_message_text(
                f"{original_text}\n\n"
                f"❌ Error: {str(e)}"
            )
```

Add to button_callback function:
```python
elif action == "mycategory":
    await handle_mycategory_action(query, param)
```

### 3. Add Button to Monitoring Script

In your monitoring script, use the Telegram library:

```bash
source /usr/local/lib/monitoring/telegram-notify.sh

telegram_send_with_buttons "Alert message" \
    "My Action Button|mycategory_myaction" \
    "Dismiss|dismiss"
```

### 4. Restart the Bot

```bash
sudo systemctl restart telegram-bot
```

### 5. Test It

Send yourself a test notification with the new button and verify it works!

---

## Runbook Best Practices

1. **Always log:** Use a LOG_FILE and the `log()` function
2. **Be idempotent:** Running twice should be safe
3. **Handle errors:** Use `set -e` and proper error handling
4. **Show progress:** Output clear status messages
5. **Time limits:** Consider adding timeouts for long operations
6. **Test safely:** Test runbooks manually before deploying
7. **Document:** Add clear comments explaining what each section does
8. **Security:** Only allow necessary sudo permissions

---

## Sudoers Configuration

All runbooks run as root via the bot service. To add sudo permissions for specific commands:

Edit `/etc/sudoers.d/monitoring-runbooks`:
```bash
root ALL=(ALL) NOPASSWD: /etc/monitoring/runbooks/my-runbook.sh
```

Validate:
```bash
sudo visudo -c -f /etc/sudoers.d/monitoring-runbooks
```

---

## Monitoring Runbook Execution

View logs for a specific runbook:
```bash
sudo tail -f /var/log/server-update-runbook.log
```

View all bot activity:
```bash
sudo journalctl -u telegram-bot -f
```

View runbook execution history:
```bash
sudo ls -lht /var/log/*-runbook.log
```

---

## Troubleshooting

**Runbook not executing:**
- Check bot logs: `sudo journalctl -u telegram-bot -n 50`
- Verify runbook is executable: `ls -l /etc/monitoring/runbooks/`
- Test manually: `sudo /etc/monitoring/runbooks/script-name.sh`

**Timeout errors:**
- Increase timeout in bot handler
- Check if runbook is hanging
- Review runbook logs

**Permission denied:**
- Verify sudoers configuration
- Check file permissions
- Ensure bot runs as root

---

## Summary Table

| Runbook | Purpose | Execution Time | Modifies System | Causes Downtime |
|---------|---------|----------------|-----------------|-----------------|
| update-server.sh | System updates | 2-10 min | Yes | Sometimes (reboot) |
| update-containers.sh | Update Docker containers | 1-5 min | Yes | Brief |
| disk-topfiles.sh | Analyze disk usage | 30-60 sec | No | No |
| disk-cleanup.sh | Clean disk space | 1-3 min | Yes | No |
| cert-status.sh | Check certificate status | < 5 sec | No | No |
| cert-renew.sh | Renew SSL certificates | 10-30 sec | Yes | No |
| fail2ban-status.sh | Check fail2ban status | < 5 sec | No | No |

---

## Quick Reference

**View all runbooks:**
```bash
ls -lh /etc/monitoring/runbooks/
```

**Test a runbook manually:**
```bash
sudo /etc/monitoring/runbooks/runbook-name.sh
```

**View runbook logs:**
```bash
sudo tail -f /var/log/*-runbook.log
```

**Restart bot after changes:**
```bash
sudo systemctl restart telegram-bot
```
