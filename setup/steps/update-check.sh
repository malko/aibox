#!/bin/bash

step_update-check() {
    setup_ensure_guest_reachable

    INSTALL_UPDATE_CHECK=$(prompt_config_yes_no "INSTALL_UPDATE_CHECK" "Install automatic update check?" "yes")
    save_config "INSTALL_UPDATE_CHECK" "$INSTALL_UPDATE_CHECK"

    if [[ "$INSTALL_UPDATE_CHECK" != "yes" ]]; then
        print_info "Skipped update check installation."
        return 0
    fi

    print_info "Installing update check service..."
    ssh -t -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "~/scripts/install-update-check.sh"
}
