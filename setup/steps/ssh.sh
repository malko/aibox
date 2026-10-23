#!/bin/bash

step_ssh() {
    setup_ensure_host_context

    if [[ "$VM_BACKEND" == "lima" ]]; then
        print_info "SSH keys are managed automatically by Lima, skipping key setup."
    else
        GUEST_USER=$(prompt_config "GUEST_USER" "VM username" "aibox")
        save_config "GUEST_USER" "$GUEST_USER"

        print_info "Setting up SSH key authentication..."
        "$SCRIPT_DIR/host/configure-ssh.sh" "$VM_NAME" "$GUEST_IP" "$GUEST_USER"
    fi

    setup_ensure_guest_reachable
}
