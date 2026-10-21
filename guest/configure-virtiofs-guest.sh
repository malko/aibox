#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-funcs.sh"
source "$SCRIPT_DIR/sudo-funcs.sh"

print_info "=== Configure Virtiofs (Guest) ==="

if ! grep -q "gitshare" /etc/fstab; then
    sudo_cmd sh -c 'printf "%s\n" "$1" >> /etc/fstab' _ \
        "gitshare /home/$USER/git virtiofs defaults,x-guest 0 0"
fi

sudo_cmd mkdir -p "/home/$USER/git"
sudo_cmd chown "$USER:$USER" "/home/$USER/git"

sudo_cmd mount -a || true

echo "Virtiofs mount configured!"

print_success "Virtiofs configured in guest!"
