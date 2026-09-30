#!/bin/bash

step_dirs() {
    setup_ensure_guest_reachable

    ssh -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" \
        "mkdir -p ~/git/opencode/agents ~/git/opencode/commands ~/git/opencode/skills ~/git/opencode/tools ~/scripts"
}
