#!/bin/bash

step_sshd() {
    setup_ensure_guest_reachable

    DISABLE_PASSWORD_AUTH=$(prompt_config_yes_no "DISABLE_PASSWORD_AUTH" "Disable password authentication in VM?" "yes")
    save_config "DISABLE_PASSWORD_AUTH" "$DISABLE_PASSWORD_AUTH"

    if [[ "$DISABLE_PASSWORD_AUTH" != "yes" ]]; then
        print_info "Skipped SSH password authentication change."
        return 0
    fi

    PASSWORD_AUTH_DISABLED=$(vm_ssh -o ConnectTimeout=5 -- "grep -qs '^PasswordAuthentication no' /etc/ssh/sshd_config.d/00-aibox.conf && echo yes" 2>/dev/null || echo "")
    if [[ -n "$PASSWORD_AUTH_DISABLED" ]]; then
        print_info "Password authentication already disabled, skipping."
        return 0
    fi

    vm_ssh -t -t -o ConnectTimeout=10 -- "~/scripts/configure-sshd.sh"
}
