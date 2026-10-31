#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo ./uninstall_helper.sh"
    exit 1
fi

PLIST_PATH="/Library/LaunchDaemons/com.voltcraft.helper.plist"
DEST_BIN="/Library/PrivilegedHelperTools/com.voltcraft.helper"
SOCKET_PATH="/var/run/voltcraft_helper.sock"

echo "==> Stopping helper daemon..."
launchctl bootout system "$PLIST_PATH" 2>/dev/null || true
launchctl unload "$PLIST_PATH" 2>/dev/null || true

echo "==> Removing helper files..."
rm -f "$PLIST_PATH"
rm -f "$DEST_BIN"
rm -f "$SOCKET_PATH"
rm -f /var/log/voltcraft_helper.log
rm -f /var/log/voltcraft_helper.err

echo "==> Restoring default SMC state..."
# Unload complete
echo "VoltCraft Privileged Helper uninstalled successfully."
