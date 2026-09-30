#!/bin/bash

step_opencode() {
    setup_ensure_guest_reachable

    OPENCODE_PORT=$(prompt_config "OPENCODE_PORT" "opencode-web port" "4096")
    save_config "OPENCODE_PORT" "$OPENCODE_PORT"

    print_info "Configuring services..."
    mkdir -p "${HOME}/.config/aibox"
    SERVICES_FILE="${HOME}/.config/aibox/services.json"
    if [[ ! -f "$SERVICES_FILE" ]]; then
        echo "{\"opencode\": \"$OPENCODE_PORT\"}" > "$SERVICES_FILE"
        print_success "Services config created with opencode:$OPENCODE_PORT"
    elif ! grep -q "opencode" "$SERVICES_FILE" 2>/dev/null; then
        "$SCRIPT_DIR/cmd/service-add" opencode "$OPENCODE_PORT"
    fi

    print_info "Configuring OpenCode..."
    ssh -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" 'mkdir -p ~/.config/opencode; if [ ! -f ~/.config/opencode/opencode.json ]; then echo "{ \"provider\": {} }" > ~/.config/opencode/opencode.json; fi'

    print_info "Installing opencode-web service..."
    ssh -t -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "source ~/.bashrc && ~/scripts/install-service.sh"
}
