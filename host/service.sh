#!/bin/bash
# Host service manager abstraction for aibox.
#
# The tunnel runs as a user service: systemd --user on Linux, launchd
# LaunchAgent on macOS. Scripts use the svc_* helpers below instead of calling
# systemctl/launchctl directly.
#
# Requires: shared-funcs.sh and config-funcs.sh sourced, init_config_file run.
# The implementation file is sourced lazily by svc_require so that scripts that
# never touch the service (help, status, ...) work everywhere.

SVC_NAME="aibox-tunnel"
SVC_MANAGER=""
SVC_AVAILABLE=false

# svc_manager_detect prints the platform service manager.
svc_manager_detect() {
    if is_macos; then
        printf '%s\n' "launchd"
    elif command -v systemctl &>/dev/null && systemctl --user show-environment &>/dev/null; then
        printf '%s\n' "systemd"
    else
        printf '%s\n' "none"
    fi
}

# svc_require loads the implementation and errors out when the platform has no
# supported user service manager.
svc_require() {
    if [[ "$SVC_AVAILABLE" == "true" ]]; then
        return 0
    fi

    SVC_MANAGER="$(svc_manager_detect)"
    local impl="$SCRIPT_DIR/host/services/$SVC_MANAGER.sh"

    if [[ "$SVC_MANAGER" != "none" && -f "$impl" ]]; then
        # shellcheck source=host/services/systemd.sh
        source "$impl"
        SVC_AVAILABLE=true
        return 0
    fi

    print_error "No user service manager available (detected: $SVC_MANAGER)."
    print_info "The tunnel service needs systemd --user (Linux) or launchd (macOS)."
    return 1
}
