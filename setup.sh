#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-funcs.sh"
source "$SCRIPT_DIR/config-funcs.sh"
source "$SCRIPT_DIR/setup/lib.sh"

CONFIG_FILE=""
REQUESTED_STEPS=()

usage() {
    echo "Usage: $0 [options] [step ...]"
    echo ""
    echo "Runs one or more setup steps. Without a step, runs every step ('all')."
    echo "Prerequisites of a step are run automatically."
    echo ""
    echo "Steps:"
    local step
    for step in "${SETUP_STEP_ORDER[@]}"; do
        printf '  %-14s %s\n' "$step" "$(setup_step_desc "$step")"
    done
    printf '  %-14s %s\n' "all" "Run every step in order"
    echo ""
    echo "Options:"
    echo "  -c, --config FILE    Path to config file (default: ~/.config/aibox/aibox.conf)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                   Run the full setup"
    echo "  $0 motd              Reconfigure the MOTD (runs its prerequisites)"
    echo "  $0 dsh motd          Set up dsh and the MOTD"
    echo ""
    echo "The config file stores settings between runs. User responses are saved"
    echo "to the config file and used as defaults for subsequent runs."
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--config)
            if [[ $# -lt 2 || "$2" == -* ]]; then
                echo "Error: -c/--config requires a file argument" >&2
                exit 1
            fi
            CONFIG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option: $1" >&2
            echo "Use -h for help" >&2
            exit 1
            ;;
        *)
            REQUESTED_STEPS+=("$1")
            shift
            ;;
    esac
done

if [[ -z "$CONFIG_FILE" ]]; then
    CONFIG_FILE="$HOME/.config/aibox/aibox.conf"
fi

init_config_file

# The backend must be loaded after the config so VM_BACKEND can be read.
source "$SCRIPT_DIR/host/backend.sh"

vm_backend_require

print_ascii_logo

HOSTNAME_LOCAL=$(host_local_name)
print_info "=== AIBox Setup ==="
print_info "VM backend: $VM_BACKEND"
print_info "Host detected: $HOSTNAME_LOCAL"
print_info "Config file: $CONFIG_FILE"
echo ""

# Default to all steps, and expand 'all' to the ordered list.
if [[ ${#REQUESTED_STEPS[@]} -eq 0 ]]; then
    REQUESTED_STEPS=("all")
fi

EXPANDED_STEPS=()
for step in "${REQUESTED_STEPS[@]}"; do
    if [[ "$step" == "all" ]]; then
        EXPANDED_STEPS+=("${SETUP_STEP_ORDER[@]}")
    elif setup_known_step "$step"; then
        EXPANDED_STEPS+=("$step")
    else
        print_error "Unknown setup step: '$step'"
        echo "Run '$0 --help' to list available steps." >&2
        exit 1
    fi
done

for step in "${EXPANDED_STEPS[@]}"; do
    echo ""
    setup_run_step "$step"
done

echo ""
print_warn "=== Setup Complete! ==="
print_success "VM '$(get_config "VM_NAME" "aibox")' is ready!"
echo ""
print_info "To connect to your VM, run:"
echo "  aibox"
echo ""
print_info "To start the VM and the tunnel without a shell, run:"
echo "  aibox start"
echo ""
print_info "VM state, service URLs and tunnel state:"
echo "  aibox status"
echo ""
print_info "opencode web interface:"
echo "  http://localhost:$(get_config "OPENCODE_PORT" "4096")"

if [[ "$(get_config "INSTALL_DSH" "no")" == "yes" ]]; then
    echo ""
    print_info "dsh web interface:"
    echo "  http://localhost:$(get_config "DSH_PORT" "3080")"
fi

echo ""
print_info "To expose services on the LAN (temporary):"
echo "  aibox tunnel lan on"
