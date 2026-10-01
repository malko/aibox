#!/bin/bash

step_vscode() {
    setup_ensure_guest_reachable

    INSTALL_VSCODE=$(prompt_config_yes_no "INSTALL_VSCODE" "Install vscode-server?" "yes")
    save_config "INSTALL_VSCODE" "$INSTALL_VSCODE"

    if [[ "$INSTALL_VSCODE" != "yes" ]]; then
        print_info "Skipped vscode-server installation."
        return 0
    fi

    vm_ssh -t -o ConnectTimeout=10 -- "~/scripts/install-vscode.sh"
}
