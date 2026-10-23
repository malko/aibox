#!/bin/bash

step_opencode() {
    setup_ensure_guest_reachable

    OPENCODE_PORT=$(prompt_config "OPENCODE_PORT" "opencode port" "4096")
    save_config "OPENCODE_PORT" "$OPENCODE_PORT"

    print_info "Configuring services..."
    mkdir -p "${HOME}/.config/aibox"
    source "$SCRIPT_DIR/services-funcs.sh"
    if ! service_exists opencode; then
        "$SCRIPT_DIR/cmd/service-add" opencode "$OPENCODE_PORT"
    fi

    print_info "Configuring OpenCode..."
    vm_ssh -o ConnectTimeout=10 -- 'mkdir -p ~/.config/opencode; if [ ! -f ~/.config/opencode/opencode.json ]; then echo "{ \"provider\": {} }" > ~/.config/opencode/opencode.json; fi'

    print_info "Installing opencode server service..."
    print_info "opencode generates its own password at startup (shown in the MOTD and 'aibox status')."
    setup_guest_ssh '"$HOME/scripts/install-service.sh" '"$OPENCODE_PORT"
}
