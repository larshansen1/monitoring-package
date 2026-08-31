#!/usr/bin/env python3
"""
Telegram Bot Handler for Server Monitoring
Handles interactive callbacks and executes runbooks
"""

import os
import sys
import logging
import subprocess
import asyncio
from datetime import datetime
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CallbackQueryHandler, CommandHandler, ContextTypes

# Configuration
CONFIG_FILE = "/etc/monitoring/telegram.conf"
RUNBOOKS_DIR = "/etc/monitoring/runbooks"

# Logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)


def load_config():
    """Load Telegram configuration from file"""
    config = {}

    if not os.path.exists(CONFIG_FILE):
        logger.error(f"Config file not found: {CONFIG_FILE}")
        sys.exit(1)

    with open(CONFIG_FILE, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                # Remove quotes if present
                value = value.strip('"').strip("'")
                config[key] = value

    required = ['TELEGRAM_BOT_TOKEN', 'TELEGRAM_CHAT_ID']
    for key in required:
        if key not in config:
            logger.error(f"Missing required config: {key}")
            sys.exit(1)

    return config


config = load_config()
BOT_TOKEN = config['TELEGRAM_BOT_TOKEN']
AUTHORIZED_CHAT_ID = int(config['TELEGRAM_CHAT_ID'])


async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command"""
    if update.effective_chat.id != AUTHORIZED_CHAT_ID:
        await update.message.reply_text("Unauthorized access denied.")
        logger.warning(f"Unauthorized access attempt from chat_id: {update.effective_chat.id}")
        return

    await update.message.reply_text(
        "🤖 Server Monitoring Bot Active\n\n"
        "I'll send you alerts about your server and you can respond with actions.\n\n"
        "Commands:\n"
        "/status - Check bot status\n"
        "/test - Send test notification"
    )


async def status_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /status command"""
    if update.effective_chat.id != AUTHORIZED_CHAT_ID:
        await update.message.reply_text("Unauthorized access denied.")
        return

    hostname = subprocess.check_output(['hostname']).decode().strip()
    uptime = subprocess.check_output(['uptime', '-p']).decode().strip()

    await update.message.reply_text(
        f"✅ Bot Status: Running\n\n"
        f"Server: {hostname}\n"
        f"Uptime: {uptime}\n"
        f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    )


async def test_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Send test notification with action buttons"""
    if update.effective_chat.id != AUTHORIZED_CHAT_ID:
        await update.message.reply_text("Unauthorized access denied.")
        return

    keyboard = [
        [InlineKeyboardButton("✅ Acknowledge", callback_data="test_ack")],
        [InlineKeyboardButton("ℹ️ More Info", callback_data="test_info")]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)

    await update.message.reply_text(
        "🧪 Test Notification\n\n"
        "This is a test alert with interactive buttons.\n"
        "Try clicking one!",
        reply_markup=reply_markup
    )


async def button_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle button presses"""
    query = update.callback_query

    # Verify authorized user
    if query.message.chat.id != AUTHORIZED_CHAT_ID:
        await query.answer("Unauthorized", show_alert=True)
        logger.warning(f"Unauthorized callback from chat_id: {query.message.chat.id}")
        return

    await query.answer()  # Acknowledge the button press

    callback_data = query.data
    logger.info(f"Received callback: {callback_data}")

    # Parse callback data (format: action_param or action)
    parts = callback_data.split('_', 1)
    action = parts[0]
    param = parts[1] if len(parts) > 1 else None

    # Handle different actions
    if action == "test":
        await handle_test_action(query, param)
    elif action == "update":
        await handle_update_action(query, param)
    elif action == "restart":
        await handle_restart_action(query, param)
    elif action == "disk":
        await handle_disk_action(query, param)
    elif action == "cert":
        await handle_cert_action(query, param)
    elif action == "fail2ban":
        await handle_fail2ban_action(query, param)
    elif action == "dismiss":
        await handle_dismiss_action(query)
    elif action == "schedule":
        await handle_schedule_action(query, param)
    else:
        await query.edit_message_text(f"Unknown action: {action}")


async def handle_test_action(query, param):
    """Handle test button callbacks"""
    if param == "ack":
        await query.edit_message_text(
            f"{query.message.text}\n\n✅ Acknowledged at {datetime.now().strftime('%H:%M:%S')}"
        )
    elif param == "info":
        await query.edit_message_text(
            f"{query.message.text}\n\n"
            f"ℹ️ Additional Information:\n"
            f"Bot is working correctly!\n"
            f"All systems operational."
        )


async def handle_update_action(query, param):
    """Handle system update actions"""
    original_text = query.message.text

    if param == "server":
        # Execute server update runbook
        await query.edit_message_text(
            f"{original_text}\n\n"
            f"⏳ Starting server update..."
        )

        try:
            result = subprocess.run(
                [f"{RUNBOOKS_DIR}/update-server.sh"],
                capture_output=True,
                text=True,
                timeout=600  # 10 minute timeout
            )

            if result.returncode == 0:
                await query.edit_message_text(
                    f"{original_text}\n\n"
                    f"✅ Server updated successfully!\n\n"
                    f"Output:\n```\n{result.stdout[-500:]}\n```",  # Last 500 chars
                    parse_mode='Markdown'
                )
            else:
                await query.edit_message_text(
                    f"{original_text}\n\n"
                    f"❌ Update failed!\n\n"
                    f"Error:\n```\n{result.stderr[-500:]}\n```",
                    parse_mode='Markdown'
                )

        except subprocess.TimeoutExpired:
            await query.edit_message_text(
                f"{original_text}\n\n"
                f"⚠️ Update timed out (10 min limit)\n"
                f"Check server manually."
            )
        except Exception as e:
            await query.edit_message_text(
                f"{original_text}\n\n"
                f"❌ Error executing update: {str(e)}"
            )

    elif param == "containers":
        # Execute container update runbook
        await query.edit_message_text(
            f"{original_text}\n\n"
            f"⏳ Updating containers..."
        )

        try:
            result = subprocess.run(
                [f"{RUNBOOKS_DIR}/update-containers.sh"],
                capture_output=True,
                text=True,
                timeout=600
            )

            if result.returncode == 0:
                await query.edit_message_text(
                    f"{original_text}\n\n"
                    f"✅ Containers updated and restarted!\n\n"
                    f"Output:\n```\n{result.stdout[-500:]}\n```",
                    parse_mode='Markdown'
                )
            else:
                await query.edit_message_text(
                    f"{original_text}\n\n"
                    f"❌ Container update failed!\n\n"
                    f"Error:\n```\n{result.stderr[-500:]}\n```",
                    parse_mode='Markdown'
                )

        except Exception as e:
            await query.edit_message_text(
                f"{original_text}\n\n"
                f"❌ Error updating containers: {str(e)}"
            )


async def handle_restart_action(query, param):
    """Handle restart actions"""
    original_text = query.message.text

    if param and param.startswith("confirm"):
        await query.edit_message_text(
            f"{original_text}\n\n"
            f"🔄 Restarting server in 1 minute...\n"
            f"Bot will be offline briefly."
        )

        # Schedule restart
        subprocess.Popen(['sudo', 'shutdown', '-r', '+1', 'Reboot requested via monitoring bot'])
    else:
        keyboard = [
            [InlineKeyboardButton("✅ Yes, restart now", callback_data="restart_confirm")],
            [InlineKeyboardButton("❌ Cancel", callback_data="dismiss")]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)

        await query.edit_message_text(
            f"{original_text}\n\n"
            f"⚠️ Confirm server restart?\n"
            f"This will cause brief downtime.",
            reply_markup=reply_markup
        )


async def handle_dismiss_action(query):
    """Handle dismiss action"""
    await query.edit_message_text(
        f"{query.message.text}\n\n"
        f"ℹ️ Dismissed at {datetime.now().strftime('%H:%M:%S')}"
    )


async def handle_schedule_action(query, param):
    """Handle scheduling actions"""
    # This is a placeholder for future scheduling functionality
    # Would integrate with systemd timers or at/cron

    await query.edit_message_text(
        f"{query.message.text}\n\n"
        f"📅 Scheduling feature coming soon!\n"
        f"For now, updates execute immediately."
    )


async def handle_disk_action(query, param):
    """Handle disk-related actions"""
    original_text = query.message.text

    if param == "topfiles":
        await query.edit_message_text(
            f"{original_text}\n\n"
            f"⏳ Analyzing disk usage..."
        )

        try:
            result = subprocess.run(
                [f"{RUNBOOKS_DIR}/disk-topfiles.sh"],
                capture_output=True,
                text=True,
                timeout=60
            )

            if result.returncode == 0:
                await query.edit_message_text(
                    f"{original_text}\n\n"
                    f"📊 *Disk Usage Analysis*\n\n"
                    f"```\n{result.stdout[-1000:]}\n```",
                    parse_mode='Markdown'
                )
            else:
                await query.edit_message_text(
                    f"{original_text}\n\n"
                    f"❌ Analysis failed!\n\n"
                    f"Error:\n```\n{result.stderr[-500:]}\n```",
                    parse_mode='Markdown'
                )
        except Exception as e:
            await query.edit_message_text(
                f"{original_text}\n\n"
                f"❌ Error: {str(e)}"
            )

    elif param == "cleanup":
        await query.edit_message_text(
            f"{original_text}\n\n"
            f"⏳ Cleaning up disk space..."
        )

        try:
            result = subprocess.run(
                [f"{RUNBOOKS_DIR}/disk-cleanup.sh"],
                capture_output=True,
                text=True,
                timeout=300
            )

            if result.returncode == 0:
                await query.edit_message_text(
                    f"{original_text}\n\n"
                    f"✅ Cleanup completed!\n\n"
                    f"```\n{result.stdout[-500:]}\n```",
                    parse_mode='Markdown'
                )
            else:
                await query.edit_message_text(
                    f"{original_text}\n\n"
                    f"❌ Cleanup failed!\n\n"
                    f"Error:\n```\n{result.stderr[-500:]}\n```",
                    parse_mode='Markdown'
                )
        except Exception as e:
            await query.edit_message_text(
                f"{original_text}\n\n"
                f"❌ Error: {str(e)}"
            )


async def handle_cert_action(query, param):
    """Handle certificate-related actions"""
    original_text = query.message.text

    if param == "status":
        await query.edit_message_text(
            f"{original_text}\n\n"
            f"⏳ Checking certificate status..."
        )

        try:
            result = subprocess.run(
                [f"{RUNBOOKS_DIR}/cert-status.sh"],
                capture_output=True,
                text=True,
                timeout=30
            )

            if result.returncode == 0:
                await query.edit_message_text(
                    f"{original_text}\n\n"
                    f"📋 *Certificate Status*\n\n"
                    f"```\n{result.stdout[-1000:]}\n```",
                    parse_mode='Markdown'
                )
            else:
                await query.edit_message_text(
                    f"{original_text}\n\n"
                    f"❌ Status check failed!\n\n"
                    f"Error:\n```\n{result.stderr[-500:]}\n```",
                    parse_mode='Markdown'
                )
        except Exception as e:
            await query.edit_message_text(
                f"{original_text}\n\n"
                f"❌ Error: {str(e)}"
            )

    elif param and param.startswith("renew"):
        # Extract domain if provided (format: renew_domain.com)
        domain = param.replace("renew_", "") if "_" in param else "all"

        await query.edit_message_text(
            f"{original_text}\n\n"
            f"⏳ Renewing certificate(s)..."
        )

        try:
            result = subprocess.run(
                [f"{RUNBOOKS_DIR}/cert-renew.sh"],
                capture_output=True,
                text=True,
                timeout=120
            )

            if result.returncode == 0:
                await query.edit_message_text(
                    f"{original_text}\n\n"
                    f"✅ Certificate renewed successfully!\n\n"
                    f"```\n{result.stdout[-500:]}\n```",
                    parse_mode='Markdown'
                )
            else:
                await query.edit_message_text(
                    f"{original_text}\n\n"
                    f"❌ Renewal failed!\n\n"
                    f"Error:\n```\n{result.stderr[-500:]}\n```",
                    parse_mode='Markdown'
                )
        except Exception as e:
            await query.edit_message_text(
                f"{original_text}\n\n"
                f"❌ Error: {str(e)}"
            )


async def handle_fail2ban_action(query, param):
    """Handle fail2ban-related actions"""
    original_text = query.message.text

    if param == "status":
        await query.edit_message_text(
            f"{original_text}\n\n"
            f"⏳ Checking fail2ban status..."
        )

        try:
            result = subprocess.run(
                [f"{RUNBOOKS_DIR}/fail2ban-status.sh"],
                capture_output=True,
                text=True,
                timeout=30
            )

            if result.returncode == 0:
                await query.edit_message_text(
                    f"{original_text}\n\n"
                    f"📋 *Fail2ban Status*\n\n"
                    f"```\n{result.stdout[-1000:]}\n```",
                    parse_mode='Markdown'
                )
            else:
                await query.edit_message_text(
                    f"{original_text}\n\n"
                    f"❌ Status check failed!\n\n"
                    f"Error:\n```\n{result.stderr[-500:]}\n```",
                    parse_mode='Markdown'
                )
        except Exception as e:
            await query.edit_message_text(
                f"{original_text}\n\n"
                f"❌ Error: {str(e)}"
            )


async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle errors"""
    logger.error(f"Update {update} caused error {context.error}")


def main():
    """Start the bot"""
    logger.info("Starting Telegram Bot Handler...")

    # Create application
    application = Application.builder().token(BOT_TOKEN).build()

    # Add handlers
    application.add_handler(CommandHandler("start", start_command))
    application.add_handler(CommandHandler("status", status_command))
    application.add_handler(CommandHandler("test", test_command))
    application.add_handler(CallbackQueryHandler(button_callback))
    application.add_error_handler(error_handler)

    logger.info("Bot is ready and polling for updates...")

    # Start polling
    application.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == '__main__':
    main()
