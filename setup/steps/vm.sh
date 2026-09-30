#!/bin/bash

step_vm() {
    setup_ensure_host_context

    print_info "Checking if VM '$VM_NAME' exists..."
    if ! virsh -c "$LIBVIRT_DEFAULT_URI" dominfo "$VM_NAME" &>/dev/null; then
        print_warn "VM '$VM_NAME' does not exist."

        CREATE_VM=$(prompt_config_yes_no "CREATE_VM" "Do you want to create a new VM?" "yes")
        save_config "CREATE_VM" "$CREATE_VM"

        if [[ "$CREATE_VM" == "yes" ]]; then
            "$SCRIPT_DIR/host/create-vm.sh" "$VM_NAME"
            exit 0
        else
            print_error "VM creation cancelled."
            exit 1
        fi
    fi

    print_success "VM '$VM_NAME' found!"
    "$SCRIPT_DIR/host/start-vm.sh" "$VM_NAME"

    load_vm_info "$VM_NAME"
    if [[ -z "$GUEST_IP" ]]; then
        print_error "Could not determine VM IP."
        exit 1
    fi
}
