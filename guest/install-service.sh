#!/bin/bash

USER_NAME="${USER:-$(whoami)}"
HOME_DIR="/home/$USER_NAME"
echo "==> User: $USER_NAME"

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
    echo "Make sure opencode is installed: npm install -g opencode"
    exit 1
fi
echo "==> opencode found: $OPENCODE_PATH"

WRAPPER_DIR="$HOME_DIR/.local/bin"
WRAPPER_SCRIPT="$WRAPPER_DIR/opencode-web-runner"
echo "==> Creating wrapper at: $WRAPPER_SCRIPT"
mkdir -p "$WRAPPER_DIR"

if [ "$NVM_SOURCED" = true ]; then
    cat > "$WRAPPER_SCRIPT" << 'EOFWRAPPER'
#!/bin/bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
exec opencode web
EOFWRAPPER
    echo "==> Wrapper created with NVM support"
else
    cat > "$WRAPPER_SCRIPT" << 'EOFWRAPPER'
#!/bin/bash
exec opencode web
EOFWRAPPER
    echo "==> Wrapper created without NVM"
fi
chmod +x "$WRAPPER_SCRIPT"

SERVICE_DIR="$HOME_DIR/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/opencode-web.service"
echo "==> Service file: $SERVICE_FILE"
mkdir -p "$SERVICE_DIR"

NEW_CONTENT=$(cat << 'EOF'
[Unit]
Description=OpenCode Web Service

[Service]
Type=simple
ExecStart=%h/.local/bin/opencode-web-runner
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

if [ "$NEEDS_RELOAD" = true ]; then
    echo "==> Reloading systemd..."
    systemctl --user daemon-reload
fi

echo "==> Enabling service..."
systemctl --user enable opencode-web.service

echo "==> Starting service..."
systemctl --user start opencode-web.service

echo "==> Checking linger..."
if loginctl show-user "$USER_NAME" 2>/dev/null | grep -q "Linger=yes"; then
    echo "==> Linger already enabled"
else
    echo "==> Enabling linger (requires sudo)..."
    sudo loginctl enable-linger "$USER_NAME"
fi

echo ""
echo "=== Done ==="
echo "Status: systemctl --user status opencode-web.service"
echo "Logs:   journalctl --user -u opencode-web.service -f"
