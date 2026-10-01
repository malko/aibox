#!/bin/bash

step_scripts() {
    setup_ensure_guest_reachable

    vm_ssh -- "mkdir -p ~/scripts"
    "$SCRIPT_DIR/host/upload-scripts.sh" "$VM_NAME"
}
