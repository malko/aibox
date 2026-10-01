#!/bin/bash
# Shared helpers for the modular AIBox setup.
#
# Sourced by setup.sh. Steps live in setup/steps/<name>.sh and each defines a
# single function named "step_<name>". Steps rely on the host context exported
# by the runner (VM_NAME, GUEST_USER, GUEST_IP, CONFIG_FILE, SCRIPT_DIR) and on
# the helpers from shared-funcs.sh / config-funcs.sh / host/backend.sh.

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
# Implemented as a function instead of an associative array to stay compatible
# with the bash 3.2 shipped by macOS.
setup_step_deps() {
    case "$1" in
        vm)           echo "" ;;
        ssh)          echo "vm" ;;
        scripts)      echo "ssh" ;;
        deps)         echo "scripts" ;;
        sshd)         echo "scripts" ;;
        git)          echo "scripts" ;;
        dirs)         echo "scripts" ;;
        hosts)        echo "scripts" ;;
        motd)         echo "scripts" ;;
        docker)       echo "scripts" ;;
        vscode)       echo "docker" ;;
        opencode)     echo "deps" ;;
        dsh)          echo "deps" ;;
        update-check) echo "scripts" ;;
        virtiofs)     echo "vm" ;;
        cli)          echo "" ;;
        tunnel)       echo "cli" ;;
        *)            echo "" ;;
    esac
}

# Human description of each step, used in help output.
setup_step_desc() {
    case "$1" in
        vm)           echo "Ensure the VM exists and is running" ;;
        ssh)          echo "Set up SSH key authentication" ;;
        scripts)      echo "Upload helper scripts to the VM" ;;
        deps)         echo "Install dependencies in the VM (nvm, node, opencode)" ;;
        sshd)         echo "Disable SSH password authentication" ;;
        git)          echo "Configure Git user in the VM" ;;
        dirs)         echo "Create ~/git/opencode directories in the VM" ;;
        hosts)        echo "Add 'aibox-host' to the VM /etc/hosts" ;;
        motd)         echo "Configure the AIBOX MOTD" ;;
        docker)       echo "Install Docker in the VM" ;;
        vscode)       echo "Install vscode-server" ;;
        opencode)     echo "Install the opencode-web service" ;;
        dsh)          echo "Install dsh and the dsh-web service" ;;
        update-check) echo "Install the automatic update check" ;;
        virtiofs)     echo "Configure the virtiofs git share with the host" ;;
        cli)          echo "Install the 'aibox' command and shell completion on the host" ;;
        tunnel)       echo "Install the tunnel user service on the host" ;;
        *)            echo "" ;;
    esac
}

# Tracks steps already run in this invocation (" step " list), so prerequisites
# run once. A string is used instead of an associative array for bash 3.2.
SETUP_DONE_STEPS=" "

setup_mark_done() {
    SETUP_DONE_STEPS="$SETUP_DONE_STEPS$1 "
}

setup_is_done() {
    [[ "$SETUP_DONE_STEPS" == *" $1 "* ]]
}

setup_known_step() {
    local step
    for step in "${SETUP_STEP_ORDER[@]}"; do
        [[ "$step" == "$1" ]] && return 0
    done
    return 1
}

# setup_ensure_host_context loads the values every guest step needs.
# It is idempotent and safe to call repeatedly.
setup_ensure_host_context() {
    [[ -n "${SETUP_CONTEXT_LOADED:-}" ]] && return 0

    VM_NAME=$(get_config "VM_NAME" "aibox")
    if [[ "$VM_BACKEND" == "lima" ]]; then
        # Lima owns the guest user: it is always the host user.
        GUEST_USER="$(vm_default_guest_user)"
    else
        GUEST_USER=$(get_config "GUEST_USER" "$(vm_default_guest_user)")
    fi

    load_vm_info "$VM_NAME"
    SETUP_CONTEXT_LOADED=1
}

# setup_ensure_guest_reachable makes sure VM_NAME/GUEST_USER/GUEST_IP are set
# and that the guest answers on SSH. Used by any step that talks to the guest.
setup_ensure_guest_reachable() {
    setup_ensure_host_context

    if ! vm_exists "$VM_NAME"; then
        print_error "VM '$VM_NAME' does not exist."
        return 1
    fi

    if [[ "$(vm_state "$VM_NAME")" != "running" ]]; then
        print_error "VM '$VM_NAME' is not running."
        return 1
    fi

    vm_resolve "$VM_NAME"

    if ! vm_ssh_ready "$VM_NAME"; then
        print_error "SSH to $VM_SSH_TARGET is not responding."
        return 1
    fi
}

# setup_run_step <name> executes the step and its prerequisites exactly once.
setup_run_step() {
    local name="$1"
    local dep

    if ! setup_known_step "$name"; then
        print_error "Unknown setup step: '$name'"
        return 1
    fi

    setup_is_done "$name" && return 0

    for dep in $(setup_step_deps "$name"); do
        setup_run_step "$dep" || return 1
    done

    print_info "=== Setup step: $name ($(setup_step_desc "$name")) ==="

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
    setup_mark_done "$name"
    print_success "Step '$name' done."
}
