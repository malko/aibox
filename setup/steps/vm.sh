#!/bin/bash

step_vm() {
    setup_ensure_host_context

    print_info "Checking if VM '$VM_NAME' exists..."
    if ! vm_exists "$VM_NAME"; then
        print_warn "VM '$VM_NAME' does not exist."

        CREATE_VM=$(prompt_config_yes_no "CREATE_VM" "Do you want to create a new VM?" "yes")
        save_config "CREATE_VM" "$CREATE_VM"

        if [[ "$CREATE_VM" == "yes" ]]; then
            vm_create "$VM_NAME"
            # libvirt creation still needs a manual OS install, so stop here
            # and let the user re-run setup. A Lima VM is ready immediately,
            # so the setup can continue in the same run.
            if [[ "$VM_BACKEND" == "libvirt" ]]; then
                exit 0
            fi
        else
            print_error "VM creation cancelled."
            exit 1
        fi
    fi

    print_success "VM '$VM_NAME' found!"
    "$SCRIPT_DIR/host/start-vm.sh" "$VM_NAME"

    if [[ "$(vm_state "$VM_NAME")" != "running" ]]; then
        print_error "VM '$VM_NAME' is not running."
        exit 1
    fi
}
