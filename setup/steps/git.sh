#!/bin/bash

step_git() {
    setup_ensure_guest_reachable

    CONFIGURE_GIT=$(prompt_config_yes_no "CONFIGURE_GIT" "Configure Git user in VM?" "yes")
    save_config "CONFIGURE_GIT" "$CONFIGURE_GIT"

    if [[ "$CONFIGURE_GIT" != "yes" ]]; then
        print_info "Skipped Git configuration."
        return 0
    fi

    vm_ssh -t -o ConnectTimeout=10 -- << EOF
git config --global user.name "${GUEST_USER}-aibox"
git config --global user.email "${GUEST_USER}@aibox.local"

echo "Git configured!"
EOF
}
