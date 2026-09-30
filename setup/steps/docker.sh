#!/bin/bash

step_docker() {
    setup_ensure_guest_reachable

    INSTALL_DOCKER=$(prompt_config_yes_no "INSTALL_DOCKER" "Install Docker?" "yes")
    save_config "INSTALL_DOCKER" "$INSTALL_DOCKER"

    if [[ "$INSTALL_DOCKER" != "yes" ]]; then
        print_info "Skipped Docker installation."
        return 0
    fi

    DOCKER_INSTALLED=$(ssh -o ConnectTimeout=5 "$GUEST_USER@$GUEST_IP" "command -v docker" 2>/dev/null || echo "")
    if [[ -n "$DOCKER_INSTALLED" ]]; then
        print_info "Docker already installed, skipping."
        return 0
    fi

    ssh -t -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "~/scripts/install-docker.sh"
}
