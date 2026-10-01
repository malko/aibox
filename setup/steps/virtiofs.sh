#!/bin/bash

step_virtiofs() {
    setup_ensure_host_context

    # On macOS the git share is declared in the Lima instance config at creation
    # time (host ~/git -> guest ~/git, writable); no guest fstab entry needed.
    if [[ "$VM_BACKEND" == "lima" ]]; then
        print_info "File sharing on macOS is handled by Lima mounts (host ~/git -> guest ~/git)."
        print_info "Edit ~/.lima/$VM_NAME/lima.yaml to change it, then restart the VM."
        return 0
    fi

    CONFIGURE_VIRTIOFS=$(prompt_config_yes_no "CONFIGURE_VIRTIOFS" "Configure virtiofs (git share with host)?" "no")
    save_config "CONFIGURE_VIRTIOFS" "$CONFIGURE_VIRTIOFS"

    if [[ "$CONFIGURE_VIRTIOFS" != "yes" ]]; then
        print_info "Skipped virtiofs configuration."
        return 0
    fi

    HOST_SHARE_DIR=$(prompt_config "HOST_SHARE_DIR" "Host directory to share" "$HOME/git")
    save_config "HOST_SHARE_DIR" "$HOST_SHARE_DIR"

    vm_configure_share "$VM_NAME" "$HOST_SHARE_DIR"

    "$SCRIPT_DIR/host/start-vm.sh" "$VM_NAME"
    setup_ensure_guest_reachable

    vm_ssh -t -t -o ConnectTimeout=10 -- "set -e
if ! grep -q 'gitshare' /etc/fstab; then
    echo 'gitshare /home/$GUEST_USER/git virtiofs defaults,x-guest 0 0' | sudo tee -a /etc/fstab
fi

sudo mkdir -p /home/$GUEST_USER/git
sudo chown $GUEST_USER:$GUEST_USER /home/$GUEST_USER/git

sudo systemctl daemon-reload

sudo mount -a || true

echo 'Virtiofs configured!'"
}
