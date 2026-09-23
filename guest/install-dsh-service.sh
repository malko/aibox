#!/bin/bash
set -e

DSH_PORT="${1:-3080}"

USER_NAME="${USER:-$(whoami)}"
HOME_DIR="/home/$USER_NAME"
echo "==> User: $USER_NAME"
echo "==> Port: $DSH_PORT"

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

echo "==> Looking for dsh..."
DSH_PATH=$(command -v dsh 2>/dev/null || echo "")
if [ -z "$DSH_PATH" ]; then
    echo "Error: dsh not found in PATH"
    echo "Install it first: ~/scripts/install-dsh.sh"
    exit 1
fi
echo "==> dsh found: $DSH_PATH"

WRAPPER_DIR="$HOME_DIR/.local/bin"
WRAPPER_SCRIPT="$WRAPPER_DIR/dsh-web-runner"
echo "==> Creating wrapper at: $WRAPPER_SCRIPT"
mkdir -p "$WRAPPER_DIR"

if [ "$NVM_SOURCED" = true ]; then
    cat > "$WRAPPER_SCRIPT" << EOFWRAPPER
#!/bin/bash
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \\. "\$NVM_DIR/nvm.sh"
exec dsh web --no-open --port $DSH_PORT
EOFWRAPPER
    echo "==> Wrapper created with NVM support"
else
    cat > "$WRAPPER_SCRIPT" << EOFWRAPPER
#!/bin/bash
exec dsh web --no-open --port $DSH_PORT
EOFWRAPPER
    echo "==> Wrapper created without NVM"
fi
chmod 755 "$WRAPPER_SCRIPT"

SERVICE_DIR="$HOME_DIR/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/dsh-web.service"
echo "==> Service file: $SERVICE_FILE"
mkdir -p "$SERVICE_DIR"

NEW_CONTENT=$(cat << 'EOF'
[Unit]
Description=DeepSeek Harness Web Service

[Service]
Type=simple
ExecStart=%h/.local/bin/dsh-web-runner
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
systemctl --user enable dsh-web.service

echo "==> Starting service..."
systemctl --user restart dsh-web.service

echo "==> Checking linger..."
if loginctl show-user "$USER_NAME" 2>/dev/null | grep -q "Linger=yes"; then
    echo "==> Linger already enabled"
else
    echo "==> Enabling linger (requires sudo)..."
    sudo loginctl enable-linger "$USER_NAME"
fi

echo ""
echo "=== Done ==="
echo "Status: systemctl --user status dsh-web.service"
echo "Logs:   journalctl --user -u dsh-web.service -f"
