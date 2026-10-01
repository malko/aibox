#!/bin/bash

step_tunnel() {
    INSTALL_TUNNEL=$(prompt_config_yes_no "INSTALL_TUNNEL" "Install the aibox tunnel user service?" "yes")
    save_config "INSTALL_TUNNEL" "$INSTALL_TUNNEL"

    if [[ "$INSTALL_TUNNEL" == "yes" ]]; then
        "$SCRIPT_DIR/cmd/tunnel" install
    else
        "$SCRIPT_DIR/cmd/tunnel" uninstall >/dev/null 2>&1 || true
    fi
}
