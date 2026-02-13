#!/bin/bash
set -e

USER_NAME="${USER:-$(whoami)}"
HOME_DIR="/home/$USER_NAME"
echo "==> Utilisateur: $USER_NAME"

NVM_DIR="$HOME_DIR/.nvm"
if [ -d "$NVM_DIR" ]; then
    echo "==> NVM détecté: $NVM_DIR"
    NVM_SOURCED=true
else
    echo "==> NVM non trouvé"
    NVM_SOURCED=false
fi

OPENCODE_PATH=$(which opencode)
if [ -z "$OPENCODE_PATH" ]; then
    echo "Erreur: opencode non trouvé dans PATH"
    exit 1
fi
echo "==> opencode trouvé: $OPENCODE_PATH"

WRAPPER_DIR="$HOME_DIR/.local/bin"
WRAPPER_SCRIPT="$WRAPPER_DIR/opencode-web-runner"
mkdir -p "$WRAPPER_DIR"

if [ "$NVM_SOURCED" = true ]; then
    cat > "$WRAPPER_SCRIPT" << EOFWRAPPER
#!/bin/bash
export NVM_DIR="$NVM_DIR"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
exec $OPENCODE_PATH web
EOFWRAPPER
    echo "==> Wrapper créé avec support NVM: $WRAPPER_SCRIPT"
else
    cat > "$WRAPPER_SCRIPT" << EOFWRAPPER
#!/bin/bash
exec $OPENCODE_PATH web
EOFWRAPPER
    echo "==> Wrapper créé sans NVM: $WRAPPER_SCRIPT"
fi
chmod +x "$WRAPPER_SCRIPT"

SERVICE_DIR="/home/$USER_NAME/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/opencode-web.service"

mkdir -p "$SERVICE_DIR"

NEW_CONTENT=$(cat << EOF
[Unit]
Description=OpenCode Web Service

[Service]
Type=simple
ExecStart=$WRAPPER_SCRIPT
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
    echo "==> Mise à jour du fichier service..."
    echo "$NEW_CONTENT" > "$SERVICE_FILE"
    NEEDS_RELOAD=true
else
    echo "==> Fichier service inchangé"
    NEEDS_RELOAD=false
fi

if [ "$NEEDS_RELOAD" = true ]; then
    echo "==> Rechargement de la configuration systemd..."
    systemctl --user daemon-reload
fi

if systemctl --user is-enabled --quiet opencode-web.service 2>/dev/null; then
    echo "==> Service déjà activé"
else
    echo "==> Activation du service..."
    systemctl --user enable opencode-web.service
fi

if systemctl --user is-active --quiet opencode-web.service 2>/dev/null; then
    echo "==> Service déjà démarré"
else
    echo "==> Démarrage du service..."
    systemctl --user start opencode-web.service
fi

if loginctl show-user "$USER_NAME" 2>/dev/null | grep -q "Linger=yes"; then
    echo "==> Linger déjà activé"
else
    echo "==> Activation du linger (nécessite sudo)..."
    sudo loginctl enable-linger "$USER_NAME"
fi

echo ""
echo "=== Terminé ==="
echo "Statut: systemctl --user status opencode-web.service"
echo "Logs:   journalctl --user -u opencode-web.service -f"
