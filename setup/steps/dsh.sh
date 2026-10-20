#!/bin/bash

step_dsh() {
    setup_ensure_guest_reachable

    INSTALL_DSH=$(prompt_config_yes_no "INSTALL_DSH" "Install dsh (DeepSeek Harness)?" "no")
    save_config "INSTALL_DSH" "$INSTALL_DSH"

    if [[ "$INSTALL_DSH" != "yes" ]]; then
        print_info "Skipped dsh installation."
        return 0
    fi

    DSH_PORT=$(prompt_config "DSH_PORT" "dsh-web port" "3080")
    save_config "DSH_PORT" "$DSH_PORT"

    print_info "Installing dsh..."
    ssh -t -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "~/scripts/install-dsh.sh"

    print_info "Installing dsh-web service..."
    ssh -t -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "source ~/.bashrc && ~/scripts/install-dsh-service.sh $DSH_PORT"

    source "$SCRIPT_DIR/services-funcs.sh"
    if ! service_exists dsh; then
        "$SCRIPT_DIR/cmd/service-add" dsh "$DSH_PORT"
    fi
}
