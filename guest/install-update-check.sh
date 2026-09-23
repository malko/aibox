#!/bin/bash
set -e

USER_NAME="${USER:-$(whoami)}"
HOME_DIR="/home/$USER_NAME"
echo "==> User: $USER_NAME"

CHECK_SCRIPT="$HOME_DIR/scripts/update-check.sh"
if [[ ! -f "$CHECK_SCRIPT" ]]; then
    echo "Error: $CHECK_SCRIPT not found"
    echo "Upload scripts first (host/upload-scripts.sh)."
    exit 1
fi
chmod +x "$CHECK_SCRIPT"

SERVICE_DIR="$HOME_DIR/.config/systemd/user"
mkdir -p "$SERVICE_DIR"

SERVICE_FILE="$SERVICE_DIR/aibox-update-check.service"
TIMER_FILE="$SERVICE_DIR/aibox-update-check.timer"

NEW_SERVICE=$(cat << 'EOF'
[Unit]
Description=AIBox update check

[Service]
Type=oneshot
ExecStart=%h/scripts/update-check.sh
EOF
)

NEW_TIMER=$(cat << 'EOF'
[Unit]
Description=Run the AIBox update check at boot and daily

[Timer]
OnBootSec=2min
OnUnitActiveSec=1d
Persistent=true

[Install]
WantedBy=timers.target
EOF
)

# Write a unit only when its content changed; returns 0 when it did.
write_if_changed() {
    local file="$1"
    local content="$2"
    local current=""
    [[ -f "$file" ]] && current=$(cat "$file")
    if [[ "$current" != "$content" ]]; then
        echo "==> Updating $(basename "$file")"
        printf '%s\n' "$content" > "$file"
        return 0
    fi
    echo "==> $(basename "$file") unchanged"
    return 1
}

NEEDS_RELOAD=false
if write_if_changed "$SERVICE_FILE" "$NEW_SERVICE"; then
    NEEDS_RELOAD=true
fi
if write_if_changed "$TIMER_FILE" "$NEW_TIMER"; then
    NEEDS_RELOAD=true
fi

if [[ "$NEEDS_RELOAD" == true ]]; then
    echo "==> Reloading systemd..."
    systemctl --user daemon-reload
fi

echo "==> Enabling timer..."
systemctl --user enable --now aibox-update-check.timer

echo "==> Running initial check (background)..."
systemctl --user start --no-block aibox-update-check.service || true

echo ""
echo "=== Done ==="
echo "Status: systemctl --user status aibox-update-check.timer"
echo "Logs:   journalctl --user -u aibox-update-check.service"
