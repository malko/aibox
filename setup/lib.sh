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
    [opencode]="Install the opencode-web service"
    [dsh]="Install dsh and the dsh-web service"
    [update-check]="Install the automatic update check"
    [virtiofs]="Configure the virtiofs git share with the host"
    [cli]="Install the 'aibox' command and shell completion on the host"
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

# setup_run_step <name> executes the step and its prerequisites exactly once.
setup_run_step() {
    local name="$1"
    local dep

    if [[ -z "${SETUP_STEP_DEPS[$name]+x}" ]]; then
        print_error "Unknown setup step: '$name'"
        return 1
    fi

    [[ -n "${SETUP_DONE[$name]:-}" ]] && return 0

    for dep in ${SETUP_STEP_DEPS[$name]}; do
        setup_run_step "$dep" || return 1
    done

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
