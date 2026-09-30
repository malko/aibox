#!/bin/bash

step_hosts() {
    setup_ensure_guest_reachable

    CONFIGURE_HOST_ACCESS=$(prompt_config_yes_no "CONFIGURE_HOST_ACCESS" "Configure 'aibox-host' in VM /etc/hosts?" "yes")
    save_config "CONFIGURE_HOST_ACCESS" "$CONFIGURE_HOST_ACCESS"

    if [[ "$CONFIGURE_HOST_ACCESS" != "yes" ]]; then
        print_info "Skipped /etc/hosts configuration."
        return 0
    fi

    HOST_ENTRY_EXISTS=$(ssh -o ConnectTimeout=5 "$GUEST_USER@$GUEST_IP" "grep -q 'aibox-host' /etc/hosts && echo 'yes'" 2>/dev/null || echo "no")
    if [[ "$HOST_ENTRY_EXISTS" == "yes" ]]; then
        print_info "aibox-host entry already exists in VM /etc/hosts, skipping."
        return 0
    fi

    ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" \
        "echo '192.168.122.1    aibox-host' | sudo tee -a /etc/hosts"
}
