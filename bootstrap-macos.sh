#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared-funcs.sh"

if ! is_macos; then
    print_error "This bootstrap is for macOS; on Linux run ./setup.sh directly."
    exit 1
fi

print_ascii_logo
print_info "=== AIBox macOS bootstrap ==="
echo ""

# --- Homebrew -----------------------------------------------------------------
if ! command -v brew &>/dev/null; then
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x "$candidate" ]]; then
            eval "$("$candidate" shellenv)"
            break
        fi
    done
fi

if ! command -v brew &>/dev/null; then
    print_warn "Homebrew is required to install Lima (the macOS VM manager)."
    print_info "Installing Homebrew now; you may be asked for your password."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

if ! command -v brew &>/dev/null; then
    print_error "Homebrew installation failed. Install it manually from https://brew.sh and re-run."
    exit 1
fi

# --- Dependencies -------------------------------------------------------------
print_info "Installing Lima and jq (this can take a few minutes on first run)..."
brew install lima jq

# --- Setup --------------------------------------------------------------------
echo ""
print_success "Dependencies installed."
print_info "Starting the AIBox setup: it will create the VM and configure it."
echo ""
exec "$SCRIPT_DIR/setup.sh" "$@"
