#!/bin/bash
# Shared helpers for the modular AIBox setup.
#
# Sourced by setup.sh. Steps live in setup/steps/<name>.sh and each defines a
# single function named "step_<name>". Steps rely on the host context exported
# by the runner (VM_NAME, GUEST_USER, GUEST_IP, LIBVIRT_DEFAULT_URI, CONFIG_FILE,
# SCRIPT_DIR) and on the helpers from shared-funcs.sh / config-funcs.sh.

# Ordered list of all steps. `all` runs them in this order.
SETUP_STEP_ORDER=(
    vm
    ssh
    scripts
    deps
    sshd
    git
    dirs
    hosts
    motd
    docker
    vscode
    opencode
    dsh
    claude
    update-check
    virtiofs
    cli
    tunnel
)

# Prerequisites per step: running a step first runs its dependencies (recursively).
declare -A SETUP_STEP_DEPS=(
    [vm]=""
    [ssh]="vm"
    [scripts]="ssh"
    [deps]="scripts"
    [sshd]="scripts"
    [git]="scripts"
    [dirs]="scripts"
    [hosts]="scripts"
    [motd]="scripts"
    [docker]="scripts"
    [vscode]="docker"
    [opencode]="deps"
    [dsh]="deps"
    [claude]="deps"
    [update-check]="scripts"
    [virtiofs]="vm"
    [cli]=""
    [tunnel]="cli"
)

# Human description of each step, used in help output.
declare -A SETUP_STEP_DESC=(
    [vm]="Ensure the VM exists and is running"
    [ssh]="Set up SSH key authentication"
    [scripts]="Upload helper scripts to the VM"
    [deps]="Install dependencies in the VM (nvm, node, opencode)"
    [sshd]="Disable SSH password authentication"
    [git]="Configure Git user in the VM"
    [dirs]="Create ~/git/opencode directories in the VM"
    [hosts]="Add 'aibox-host' to the VM /etc/hosts"
    [motd]="Install the AIBOX MOTD (banner + services)"
    [docker]="Install Docker in the VM"
    [vscode]="Install vscode-server"
    [opencode]="Install the opencode serve service"
    [dsh]="Install dsh and the dsh-web service"
    [claude]="Install Claude Code"
    [update-check]="Install the automatic update check"
    [virtiofs]="Configure the virtiofs git share with the host"
    [cli]="Link 'aibox' into ~/.local/bin and enable shell completion"
    [tunnel]="Install the tunnel user service on the host"
)

# Tracks steps already run in this invocation, so prerequisites run once.
declare -A SETUP_DONE=()

setup_known_step() {
    [[ -n "${SETUP_STEP_DEPS[$1]+x}" ]]
}

# setup_ensure_host_context loads the values every guest step needs.
# It is idempotent and safe to call repeatedly.
setup_ensure_host_context() {
    [[ -n "${SETUP_CONTEXT_LOADED:-}" ]] && return 0

    LIBVIRT_DEFAULT_URI=$(get_config "LIBVIRT_DEFAULT_URI" "qemu:///system")
    VM_NAME=$(get_config "VM_NAME" "aibox")
    GUEST_USER=$(get_config "GUEST_USER" "aibox")

    load_vm_info "$VM_NAME"
    SETUP_CONTEXT_LOADED=1
}

# setup_ensure_guest_reachable makes sure VM_NAME/GUEST_USER/GUEST_IP are set
# and that the guest answers on SSH. Used by any step that talks to the guest.
setup_ensure_guest_reachable() {
    setup_ensure_host_context

    if [[ -z "$GUEST_IP" ]]; then
        print_error "Could not determine VM IP. Is the VM running?"
        return 1
    fi

    if ! nc -z -w 1 "$GUEST_IP" 22 &>/dev/null; then
        print_error "SSH to $GUEST_USER@$GUEST_IP is not responding."
        return 1
    fi
}

# Make sure the two shared guest helpers exist even when the web UI runs a
# single step with --no-deps (for example 'motd' without the 'scripts' step).
setup_ensure_guest_helpers() {
    [[ "${SETUP_GUEST_HELPERS_READY:-false}" == "true" ]] && return 0

    # A web setup job always pushes the current scripts once, so a replayed
    # step never runs an old guest script from a previous aibox version.
    if [[ "${AIBOX_WEB_JOB:-0}" == "1" && "${SETUP_GUEST_SCRIPTS_UPLOADED:-false}" != "true" ]]; then
        "$SCRIPT_DIR/host/upload-scripts.sh" "$VM_NAME" "$GUEST_IP" "$GUEST_USER" >/dev/null 2>&1 || true
        SETUP_GUEST_SCRIPTS_UPLOADED=true
        SETUP_GUEST_HELPERS_READY=true
        return 0
    fi

    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$GUEST_USER@$GUEST_IP" \
        'test -f "$HOME/scripts/update-target.sh"' 2>/dev/null; then
        "$SCRIPT_DIR/host/upload-scripts.sh" "$VM_NAME" "$GUEST_IP" "$GUEST_USER" >/dev/null 2>&1 || true
        SETUP_GUEST_HELPERS_READY=true
        return 0
    fi

    if ssh -o BatchMode=yes -o ConnectTimeout=5 "$GUEST_USER@$GUEST_IP" \
        'test -f "$HOME/scripts/shared-funcs.sh" && test -f "$HOME/scripts/sudo-funcs.sh"' 2>/dev/null; then
        SETUP_GUEST_HELPERS_READY=true
        return 0
    fi

    ssh -o ConnectTimeout=5 "$GUEST_USER@$GUEST_IP" 'mkdir -p "$HOME/scripts"' 2>/dev/null || true
    if scp -q -o ConnectTimeout=10 \
        "$SCRIPT_DIR/shared-funcs.sh" \
        "$SCRIPT_DIR/guest/sudo-funcs.sh" \
        "$GUEST_USER@$GUEST_IP:~/scripts/" 2>/dev/null; then
        SETUP_GUEST_HELPERS_READY=true
    fi
}

# setup_guest_ssh <remote-command>
# Runs a command in the guest. When a sudo password was supplied by the web
# UI, it is fed on stdin and exported as SUDO_PASSWORD for sudo-funcs.sh.
# The CLI path keeps the interactive ssh -t -t behaviour.
setup_guest_ssh() {
    local command="$1"

    setup_ensure_guest_helpers

    if [[ -n "${AIBOX_SUDO_PASSWORD:-}" ]]; then
        printf '%s\n' "$AIBOX_SUDO_PASSWORD" | \
            ssh -T -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" \
                'IFS= read -r SUDO_PASSWORD; export SUDO_PASSWORD; '"$command"
    else
        ssh -t -t -o ConnectTimeout=10 "$GUEST_USER@$GUEST_IP" "$command"
    fi
}

# setup_run_step <name> executes the step and its prerequisites exactly once.
setup_run_step() {
    local name="$1"
    local dep

    if [[ -z "${SETUP_STEP_DEPS[$name]+x}" ]]; then
        print_error "Unknown setup step: '$name'"
        return 1
    fi

    [[ -n "${SETUP_DONE[$name]:-}" ]] && return 0

    if [[ "${SETUP_SKIP_DEPS:-0}" != "1" ]]; then
        for dep in ${SETUP_STEP_DEPS[$name]}; do
            setup_run_step "$dep" || return 1
        done
    fi

    print_info "=== Setup step: $name (${SETUP_STEP_DESC[$name]}) ==="

    local step_file="$SCRIPT_DIR/setup/steps/$name.sh"
    if [[ ! -f "$step_file" ]]; then
        print_error "Missing step script: $step_file"
        return 1
    fi

    source "$step_file"
    if ! declare -F "step_$name" >/dev/null; then
        print_error "Step '$name' does not define step_$name()"
        return 1
    fi

    "step_$name" || return 1
    SETUP_DONE[$name]=1
    print_success "Step '$name' done."
}
