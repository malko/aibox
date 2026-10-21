#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-funcs.sh"
source "$SCRIPT_DIR/config-funcs.sh"
source "$SCRIPT_DIR/setup/lib.sh"

CONFIG_FILE=""
REQUESTED_STEPS=()
STATUS_ONLY=false
JSON_MODE=false
NO_BANNER=false
NO_DEPS=false
ASSUME_YES=false

usage() {
    echo "Usage: $0 [options] [step ...]"
    echo ""
    echo "Runs one or more setup steps. Without a step, runs every step ('all')."
    echo "Prerequisites of a step are run automatically."
    echo ""
    echo "Steps:"
    local step
    for step in "${SETUP_STEP_ORDER[@]}"; do
        printf '  %-14s %s\n' "$step" "${SETUP_STEP_DESC[$step]}"
    done
    printf '  %-14s %s\n' "all" "Run every step in order"
    echo ""
    echo "Options:"
    echo "  -c, --config FILE    Path to config file (default: ~/.config/aibox/aibox.conf)"
    echo "  -y, --yes            Use saved/default answers (non-interactive)"
    echo "      --no-deps        Do not run prerequisites automatically"
    echo "      --no-banner      Do not print the ASCII banner"
    echo "      --status         Show the detected installation status and exit"
    echo "      --json           With --status, print machine-readable JSON"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                   Run the full setup"
    echo "  $0 motd              Reconfigure the MOTD (runs its prerequisites)"
    echo "  $0 dsh motd          Set up dsh and the MOTD"
    echo "  $0 --status          Show what is installed"
    echo "  $0 --status --json   Same, for scripts and the web UI"
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
        -y|--yes)
            ASSUME_YES=true
            shift
            ;;
        --no-deps)
            NO_DEPS=true
            shift
            ;;
        --no-banner)
            NO_BANNER=true
            shift
            ;;
        --status)
            STATUS_ONLY=true
            shift
            ;;
        --json)
            JSON_MODE=true
            shift
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

if [[ "$JSON_MODE" == "true" && "$STATUS_ONLY" != "true" ]]; then
    echo "Error: --json is only supported with --status." >&2
    exit 1
fi

if [[ -z "$CONFIG_FILE" ]]; then
    CONFIG_FILE="$HOME/.config/aibox/aibox.conf"
fi

init_config_file

check_requirements jq

if [[ "$STATUS_ONLY" == "true" ]]; then
    source "$SCRIPT_DIR/setup/status.sh"
    if [[ "$JSON_MODE" == "true" ]]; then
        setup_status_json
    else
        setup_status_human
    fi
    exit 0
fi

check_requirements virsh

if [[ "$ASSUME_YES" == "true" ]]; then
    export AIBOX_ASSUME_YES=1
fi

if [[ "$NO_DEPS" == "true" ]]; then
    export SETUP_SKIP_DEPS=1
fi

if [[ "$NO_BANNER" != "true" ]]; then
    print_ascii_logo
fi

HOSTNAME_LOCAL=$(hostname).local
print_info "=== AIBox Setup ==="
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
print_info "opencode web interface (password is generated on startup):"
echo "  http://localhost:$(get_config "OPENCODE_PORT" "4096")"
echo "  Connection password: see the VM MOTD or run 'aibox status'"

if [[ "$(get_config "INSTALL_DSH" "no")" == "yes" ]]; then
    echo ""
    print_info "dsh web interface:"
    echo "  http://localhost:$(get_config "DSH_PORT" "3080")"
fi

echo ""
print_info "To expose a service on the LAN:"
echo "  aibox tunnel lan on opencode --permanent   # survives reboot"
echo "  aibox tunnel lan on dsh --timeout 30m      # temporary"
