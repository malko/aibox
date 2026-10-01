#!/bin/bash

step_hosts() {
    setup_ensure_guest_reachable

    CONFIGURE_HOST_ACCESS=$(prompt_config_yes_no "CONFIGURE_HOST_ACCESS" "Configure 'aibox-host' in VM /etc/hosts?" "yes")
    save_config "CONFIGURE_HOST_ACCESS" "$CONFIGURE_HOST_ACCESS"

    if [[ "$CONFIGURE_HOST_ACCESS" != "yes" ]]; then
        print_info "Skipped /etc/hosts configuration."
        return 0
    fi

    HOST_ENTRY_EXISTS=$(vm_ssh -o ConnectTimeout=5 -- "grep -q 'aibox-host' /etc/hosts && echo 'yes'" 2>/dev/null || echo "no")
    if [[ "$HOST_ENTRY_EXISTS" == "yes" ]]; then
        print_info "aibox-host entry already exists in VM /etc/hosts, skipping."
        return 0
    fi

    # libvirt: fixed host gateway. Lima: resolve host.lima.internal in the guest.
    HOST_ADDRESS=$(vm_host_alias_ip)
    if [[ ! "$HOST_ADDRESS" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        HOST_ADDRESS=$(vm_ssh -o ConnectTimeout=5 -- "getent hosts $HOST_ADDRESS | awk '{print \$1}'" 2>/dev/null || echo "")
    fi

    if [[ -z "$HOST_ADDRESS" ]]; then
        print_error "Could not resolve the host address for 'aibox-host'."
        return 1
    fi

    vm_ssh -t -o ConnectTimeout=10 -- \
        "echo '$HOST_ADDRESS    aibox-host' | sudo tee -a /etc/hosts"
}
