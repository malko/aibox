#!/bin/bash
# systemd --user implementation of the aibox host service.
#
# Sourced by host/service.sh. Provides the svc_* interface.

SVC_UNIT_NAME="aibox-tunnel.service"
SVC_UNIT_DIR="$HOME/.config/systemd/user"
SVC_UNIT_FILE="$SVC_UNIT_DIR/$SVC_UNIT_NAME"

svc_installed() {
    [[ -f "$SVC_UNIT_FILE" ]]
}

svc_is_active() {
    systemctl --user is-active --quiet "$SVC_UNIT_NAME" 2>/dev/null
}

svc_install() {
    mkdir -p "$SVC_UNIT_DIR"
    cat > "$SVC_UNIT_FILE" << EOF
[Unit]
Description=AIBox SSH tunnel (VM services)
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=$SCRIPT_DIR/host/tunnel.sh
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    # Not enabled: the service is started on demand by the aibox CLI
    # (aibox start/connect), so nothing runs while the VM is off.
}

svc_uninstall() {
    systemctl --user stop "$SVC_UNIT_NAME" >/dev/null 2>&1 || true
    systemctl --user disable "$SVC_UNIT_NAME" >/dev/null 2>&1 || true
    rm -f "$SVC_UNIT_FILE"
    systemctl --user daemon-reload 2>/dev/null || true
}

svc_start() {
    systemctl --user start "$SVC_UNIT_NAME"
}

svc_stop() {
    systemctl --user stop "$SVC_UNIT_NAME"
}

svc_restart() {
    systemctl --user restart "$SVC_UNIT_NAME"
}

svc_status_text() {
    if ! svc_installed; then
        printf '%s\n' "not installed"
        return 0
    fi
    local state
    state=$(systemctl --user is-active "$SVC_UNIT_NAME" 2>/dev/null || true)
    printf '%s\n' "${state:-unknown}"
}

svc_apply_if_active() {
    if svc_is_active; then
        svc_restart
    fi
}

svc_logs() {
    journalctl --user -u "$SVC_UNIT_NAME" -n 100 --no-pager
}
