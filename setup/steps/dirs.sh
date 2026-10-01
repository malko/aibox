#!/bin/bash

step_dirs() {
    setup_ensure_guest_reachable

    vm_ssh -t -o ConnectTimeout=10 -- \
        "mkdir -p ~/git/opencode/agents ~/git/opencode/commands ~/git/opencode/skills ~/git/opencode/tools ~/scripts"
}
