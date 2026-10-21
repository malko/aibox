#!/bin/bash

step_deps() {
    setup_ensure_guest_reachable

    INSTALL_DEPS=$(prompt_config_yes_no "INSTALL_DEPS" "Install dependencies in VM?" "yes")
    save_config "INSTALL_DEPS" "$INSTALL_DEPS"

    if [[ "$INSTALL_DEPS" != "yes" ]]; then
        print_info "Skipped dependencies installation."
        return 0
    fi

    setup_guest_ssh '"$HOME/scripts/install-deps.sh"'
}
