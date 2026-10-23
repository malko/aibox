#!/bin/bash

step_claude() {
    setup_ensure_guest_reachable

    INSTALL_CLAUDE=$(prompt_config_yes_no "INSTALL_CLAUDE" "Install Claude Code?" "yes")
    save_config "INSTALL_CLAUDE" "$INSTALL_CLAUDE"

    if [[ "$INSTALL_CLAUDE" != "yes" ]]; then
        print_info "Skipped Claude Code installation."
        return 0
    fi

    setup_guest_ssh '"$HOME/scripts/install-claude.sh"'
}
