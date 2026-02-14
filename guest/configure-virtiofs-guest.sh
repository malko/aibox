#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-funcs.sh"

print_info "=== Configure Virtiofs (Guest) ==="

if ! grep -q "git-share" /etc/fstab; then
    echo "git-share /home/$USER/git virtiofs defaults,x-guest 0 0" | sudo tee -a /etc/fstab
fi

sudo mkdir -p /home/$USER/git
sudo chown $USER:$USER /home/$USER/git

sudo mount -a || true

echo "Virtiofs mount configured!"

print_success "Virtiofs configured in guest!"
