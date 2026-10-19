#!/bin/bash

USER_NAME="${USER:-$(whoami)}"
HOME_DIR="/home/$USER_NAME"
OPENCODE_PORT="${1:-4096}"
echo "==> User: $USER_NAME"
echo "==> Port: $OPENCODE_PORT"

if ! [[ "$OPENCODE_PORT" =~ ^[0-9]+$ ]]; then
    echo "Error: invalid port: $OPENCODE_PORT" >&2
    exit 1
fi

NVM_DIR="$HOME_DIR/.nvm"
if [ -d "$NVM_DIR" ]; then
    echo "==> NVM detected: $NVM_DIR"
    # Source NVM to get correct PATH
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    NVM_SOURCED=true
else
    echo "==> NVM not found"
    NVM_SOURCED=false
fi

echo "==> Looking for opencode..."
OPENCODE_PATH=$(which opencode 2>/dev/null || echo "")
if [ -z "$OPENCODE_PATH" ]; then
    echo "Error: opencode not found in PATH"
    echo "Make sure opencode is installed: npm install -g @opencode/cli"
    exit 1
fi
echo "==> opencode found: $OPENCODE_PATH"

WRAPPER_DIR="$HOME_DIR/.local/bin"
WRAPPER_SCRIPT="$WRAPPER_DIR/opencode-runner"
echo "==> Creating wrapper at: $WRAPPER_SCRIPT"
mkdir -p "$WRAPPER_DIR"

# opencode serve generates its own password at startup (like dsh generates a
# token) and prints it in the journal. Unset any password-related variable so
# opencode always creates (and prints) a fresh key on every restart.
if [ "$NVM_SOURCED" = true ]; then
    cat > "$WRAPPER_SCRIPT" << EOFWRAPPER
#!/bin/bash
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \\. "\$NVM_DIR/nvm.sh"
unset OPENCODE_PASSWORD OPENCODE_SERVER_PASSWORD
exec opencode serve --hostname 127.0.0.1 --port $OPENCODE_PORT
EOFWRAPPER
    echo "==> Wrapper created with NVM support"
else
    cat > "$WRAPPER_SCRIPT" << EOFWRAPPER
#!/bin/bash
unset OPENCODE_PASSWORD OPENCODE_SERVER_PASSWORD
exec opencode serve --hostname 127.0.0.1 --port $OPENCODE_PORT
EOFWRAPPER
    echo "==> Wrapper created without NVM"
fi
chmod 755 "$WRAPPER_SCRIPT"

SERVICE_DIR="$HOME_DIR/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/opencode.service"
echo "==> Service file: $SERVICE_FILE"
mkdir -p "$SERVICE_DIR"
mkdir -p "$HOME_DIR/git/opencode"

# v2 only: stop and drop the legacy opencode-web unit/wrapper so it does not
# keep running (and holding the port) alongside the new service.
LEGACY_REMOVED=false
if [ -f "$SERVICE_DIR/opencode-web.service" ]; then
    echo "==> Removing legacy opencode-web.service..."
    systemctl --user disable --now opencode-web.service 2>/dev/null || true
    rm -f "$SERVICE_DIR/opencode-web.service" "$WRAPPER_DIR/opencode-web-runner"
    LEGACY_REMOVED=true
fi

NEW_CONTENT=$(cat << 'EOF'
[Unit]
Description=OpenCode Server

[Service]
Type=simple
Environment="OPENCODE_CONFIG_DIR=%h/git/opencode/"
ExecStart=%h/.local/bin/opencode-runner
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF
)

CURRENT_CONTENT=""
if [ -f "$SERVICE_FILE" ]; then
    CURRENT_CONTENT=$(cat "$SERVICE_FILE")
fi

if [ "$CURRENT_CONTENT" != "$NEW_CONTENT" ]; then
    echo "==> Updating service file..."
    echo "$NEW_CONTENT" > "$SERVICE_FILE"
    NEEDS_RELOAD=true
else
    echo "==> Service file unchanged"
    NEEDS_RELOAD=false
fi

if [ "$NEEDS_RELOAD" = true ] || [ "$LEGACY_REMOVED" = true ]; then
    echo "==> Reloading systemd..."
    systemctl --user daemon-reload
fi

echo "==> Enabling service..."
systemctl --user enable opencode.service

echo "==> Starting service..."
systemctl --user restart opencode.service

echo "==> Checking linger..."
if loginctl show-user "$USER_NAME" 2>/dev/null | grep -q "Linger=yes"; then
    echo "==> Linger already enabled"
else
    echo "==> Enabling linger (requires sudo)..."
    sudo loginctl enable-linger "$USER_NAME"
fi

# Show the connection details opencode printed at startup. The password is
# regenerated on each restart, so read the current value from the journal.
OPENCODE_URL=""
OPENCODE_PASSWORD=""
SINCE=$(systemctl --user show -p ActiveEnterTimestamp --value opencode.service 2>/dev/null)
for _ in $(seq 1 10); do
    if [ -n "$SINCE" ]; then
        OPENCODE_LOG=$(journalctl --user -u opencode.service --since "$SINCE" --no-pager -o cat 2>/dev/null | tr -d '\033')
    else
        OPENCODE_LOG=$(journalctl --user -u opencode.service -n 500 --no-pager -o cat 2>/dev/null | tr -d '\033')
    fi
    OPENCODE_URL=$(printf '%s\n' "$OPENCODE_LOG" | grep -oE 'https?://[^[:space:]"]+' | tail -n 1)
    OPENCODE_PASSWORD=$(printf '%s\n' "$OPENCODE_LOG" | sed -nE 's/.*server password ([^[:space:]]+).*/\1/p' | tail -n 1)
    [ -n "$OPENCODE_URL" ] && [ -n "$OPENCODE_PASSWORD" ] && break
    sleep 1
done

echo ""
echo "=== Done ==="
if [ -n "$OPENCODE_URL" ]; then
    echo "URL:      $OPENCODE_URL"
fi
if [ -n "$OPENCODE_PASSWORD" ]; then
    echo "User:     opencode"
    echo "Password: $OPENCODE_PASSWORD"
fi
echo "Status:   systemctl --user status opencode.service"
echo "Logs:     journalctl --user -u opencode.service -f"
