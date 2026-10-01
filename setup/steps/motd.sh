#!/bin/bash

step_motd() {
    setup_ensure_guest_reachable

    CONFIGURE_MOTD=$(prompt_config_yes_no "CONFIGURE_MOTD" "Set AIBOX logo as MOTD?" "yes")
    save_config "CONFIGURE_MOTD" "$CONFIGURE_MOTD"

    if [[ "$CONFIGURE_MOTD" != "yes" ]]; then
        print_info "Skipped MOTD configuration."
        return 0
    fi

    vm_ssh -t -t -o ConnectTimeout=10 -- "~/scripts/configure-motd.sh"
}
