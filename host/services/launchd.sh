#!/bin/bash
# launchd implementation of the aibox host service (macOS).
#
# Sourced by host/service.sh. Provides the svc_* interface.
#
# The tunnel runs as a per-user LaunchAgent (gui/$UID). RunAtLoad is false:
# the agent is loaded at login but does not run until the aibox CLI starts it
# (and it is never the one starting the VM). KeepAlive only restarts the job on
# non-zero exit, so an idle VM leaves the agent loaded but stopped.

SVC_LAUNCHD_LABEL="com.aibox.tunnel"
SVC_PLIST_DIR="$HOME/Library/LaunchAgents"
SVC_PLIST="$SVC_PLIST_DIR/$SVC_LAUNCHD_LABEL.plist"
SVC_LOG_DIR="$HOME/Library/Logs"
SVC_LOG_FILE="$SVC_LOG_DIR/aibox-tunnel.log"

svc_installed() {
    [[ -f "$SVC_PLIST" ]]
}

svc_is_active() {
    launchctl list "$SVC_LAUNCHD_LABEL" 2>/dev/null | grep -qE '"PID" = [0-9]+'
}

svc_bootstrap() {
    launchctl bootstrap "gui/$(id -u)" "$SVC_PLIST" 2>/dev/null \
        || launchctl load -w "$SVC_PLIST" 2>/dev/null
}

svc_bootout() {
    launchctl bootout "gui/$(id -u)/$SVC_LAUNCHD_LABEL" 2>/dev/null \
        || launchctl unload -w "$SVC_PLIST" 2>/dev/null
}

svc_install() {
    mkdir -p "$SVC_PLIST_DIR" "$SVC_LOG_DIR"
    cat > "$SVC_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$SVC_LAUNCHD_LABEL</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>$PATH</string>
    </dict>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/host/tunnel.sh</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ThrottleInterval</key>
    <integer>5</integer>
    <key>StandardOutPath</key>
    <string>$SVC_LOG_FILE</string>
    <key>StandardErrorPath</key>
    <string>$SVC_LOG_FILE</string>
</dict>
</plist>
EOF
    svc_bootout
    svc_bootstrap
    # Loaded at login, but not started until the aibox CLI asks for it
    # (RunAtLoad is false), so nothing runs while the VM is off.
}

svc_uninstall() {
    svc_bootout
    rm -f "$SVC_PLIST"
}

svc_start() {
    if ! launchctl list "$SVC_LAUNCHD_LABEL" >/dev/null 2>&1; then
        svc_bootstrap
    fi
    launchctl kickstart -k "gui/$(id -u)/$SVC_LAUNCHD_LABEL" 2>/dev/null || true
}

svc_stop() {
    svc_bootout
}

svc_restart() {
    svc_bootout
    svc_bootstrap
}

svc_status_text() {
    if ! svc_installed; then
        printf '%s\n' "not installed"
        return 0
    fi
    if svc_is_active; then
        printf '%s\n' "running"
    elif launchctl list "$SVC_LAUNCHD_LABEL" >/dev/null 2>&1; then
        printf '%s\n' "loaded (not running)"
    else
        printf '%s\n' "installed (not loaded)"
    fi
}

svc_apply_if_active() {
    if svc_is_active; then
        svc_restart
    fi
}

svc_logs() {
    if [[ -f "$SVC_LOG_FILE" ]]; then
        tail -n 100 "$SVC_LOG_FILE"
    else
        echo "No tunnel logs yet ($SVC_LOG_FILE)."
    fi
}
