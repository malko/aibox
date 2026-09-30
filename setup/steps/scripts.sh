#!/bin/bash

step_scripts() {
    setup_ensure_guest_reachable

    ssh -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "mkdir -p ~/scripts"
    "$SCRIPT_DIR/host/upload-scripts.sh" "$VM_NAME" "$GUEST_IP" "$GUEST_USER"
}
