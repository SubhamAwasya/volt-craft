#!/bin/bash
set -e

# VoltCraft Privileged Helper Installer
# Must be run with root / admin privileges

if [ "$EUID" -ne 0 ]; then
    echo "=========================================================="
    echo " Error: VoltCraft Privileged Helper requires root access."
    echo " Please run with sudo: sudo ./install_helper.sh"
    echo "=========================================================="
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER_SRC="$SCRIPT_DIR/src/helper.m"
DEST_BIN="/Library/PrivilegedHelperTools/com.voltcraft.helper"
PLIST_PATH="/Library/LaunchDaemons/com.voltcraft.helper.plist"
SOCKET_PATH="/var/run/voltcraft_helper.sock"

echo "==> Stopping any previous helper daemon..."
launchctl bootout system "$PLIST_PATH" 2>/dev/null || true
launchctl unload "$PLIST_PATH" 2>/dev/null || true
rm -f "$SOCKET_PATH"

echo "==> Installing binary to $DEST_BIN..."
mkdir -p /Library/PrivilegedHelperTools

if [ -f "$SCRIPT_DIR/voltcraft-helper" ]; then
    cp "$SCRIPT_DIR/voltcraft-helper" "$DEST_BIN"
else
    /usr/bin/clang -Os -fobjc-arc -flto -framework Foundation -framework IOKit "$HELPER_SRC" -o "$DEST_BIN"
fi

strip "$DEST_BIN" 2>/dev/null || true
chown root:wheel "$DEST_BIN"
chmod 0755 "$DEST_BIN"

echo "==> Installing launchd service to $PLIST_PATH..."
cat << 'EOF' > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.voltcraft.helper</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Library/PrivilegedHelperTools/com.voltcraft.helper</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/var/log/voltcraft_helper.err</string>
    <key>StandardOutPath</key>
    <string>/var/log/voltcraft_helper.log</string>
</dict>
</plist>
EOF

chown root:wheel "$PLIST_PATH"
chmod 0644 "$PLIST_PATH"

echo "==> Starting daemon via launchctl..."
launchctl bootstrap system "$PLIST_PATH" 2>/dev/null || launchctl load -w "$PLIST_PATH"

echo "==> Verifying helper socket communication..."
sleep 1
if [ -S "$SOCKET_PATH" ]; then
    chmod 0666 "$SOCKET_PATH"
    RESP=$(nc -U "$SOCKET_PATH" <<< "PING" 2>/dev/null || true)
    echo "    Helper response: $RESP"
    echo "=========================================================="
    echo " SUCCESS: VoltCraft Privileged Helper is active!"
    echo " - Limits below 80% (20% - 100%) unlocked"
    echo " - Active hardware AC cut / forced discharge enabled"
    echo " - MagSafe 3 LED control enabled"
    echo "=========================================================="
else
    echo "Warning: Socket $SOCKET_PATH not yet ready. Check /var/log/voltcraft_helper.err"
fi
