#!/bin/bash

step_virtiofs() {
    setup_ensure_host_context

    CONFIGURE_VIRTIOFS=$(prompt_config_yes_no "CONFIGURE_VIRTIOFS" "Configure virtiofs (git share with host)?" "no")
    save_config "CONFIGURE_VIRTIOFS" "$CONFIGURE_VIRTIOFS"

    if [[ "$CONFIGURE_VIRTIOFS" != "yes" ]]; then
        print_info "Skipped virtiofs configuration."
        return 0
    fi

    HOST_SHARE_DIR=$(prompt_config "HOST_SHARE_DIR" "Host directory to share" "$HOME/git")
    save_config "HOST_SHARE_DIR" "$HOST_SHARE_DIR"

    "$SCRIPT_DIR/host/configure-virtiofs-host.sh" "$VM_NAME" "$HOST_SHARE_DIR"

    "$SCRIPT_DIR/host/start-vm.sh" "$VM_NAME"
    load_vm_info "$VM_NAME"

    ssh -t -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "set -e
if ! grep -q 'gitshare' /etc/fstab; then
    echo 'gitshare /home/$GUEST_USER/git virtiofs defaults,x-guest 0 0' | sudo tee -a /etc/fstab
fi

sudo mkdir -p /home/$GUEST_USER/git
sudo chown $GUEST_USER:$GUEST_USER /home/$GUEST_USER/git

sudo systemctl daemon-reload

sudo mount -a || true

echo 'Virtiofs configured!'"
}
