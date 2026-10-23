#!/bin/bash
# Opens a host terminal connected to the VM.
#
# The terminal runs 'aibox -n': a plain SSH session, with no port forwarding
# and without touching the tunnel service, even when it is installed. The VM
# is started if needed.
#
# Any terminal emulator can be used: the well known ones are tried first, then
# the freedesktop default terminal launcher, then a generated desktop entry
# (Terminal=true) and finally the macOS Terminal.app.
#
# Used by the web console. The command exits 0 when a terminal was opened, or
# when it prints the command to run by hand (no graphical session). It exits
# 1 with an error message on stderr when the terminal cannot be opened.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIBOX_ROOT="${AIBOX_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
AIBOX_SCRIPT="$AIBOX_ROOT/aibox"
CONFIG_FILE="$HOME/.config/aibox/aibox.conf"

source "$AIBOX_ROOT/shared-funcs.sh"
source "$AIBOX_ROOT/config-funcs.sh"
init_config_file
source "$AIBOX_ROOT/host/backend.sh"

VM_NAME=$(get_config "VM_NAME" "aibox")

if ! vm_exists "$VM_NAME"; then
    echo "the VM does not exist" >&2
    exit 1
fi

# The terminal runs the aibox script itself, so the session behaves exactly
# like the one started by hand.
AIBOX_ARGS=(-n "$@")

# Strategy used to open the terminal. AIBOX_TERMINAL forces one: an emulator
# name (kitty, alacritty, ...), "xdg-terminal-exec", "xdg-open", "gio" or
# "macos". Empty means "try them all".
STRATEGY="${AIBOX_TERMINAL:-}"

# Temp file with an optional suffix, portable between GNU and BSD mktemp.
temp_file() {
    local suffix="$1" path
    path=$(mktemp "${TMPDIR:-/tmp}/aibox-term-XXXXXX") || return 1
    if [[ -n "$suffix" ]]; then
        mv "$path" "$path.$suffix"
        path="$path.$suffix"
    fi
    printf '%s\n' "$path"
}

# open_terminal <emulator>: launches the command in the given emulator.
# The emulators daemonize, so they return at once with their status.
open_terminal() {
    local emulator="$1"

    case "$emulator" in
        kitty)
            kitty --detach "$AIBOX_SCRIPT" "${AIBOX_ARGS[@]}" >/dev/null 2>&1
            ;;
        alacritty)
            alacritty -e "$AIBOX_SCRIPT" "${AIBOX_ARGS[@]}" >/dev/null 2>&1
            ;;
        wezterm)
            wezterm start -- "$AIBOX_SCRIPT" "${AIBOX_ARGS[@]}" >/dev/null 2>&1
            ;;
        foot)
            foot "$AIBOX_SCRIPT" "${AIBOX_ARGS[@]}" >/dev/null 2>&1
            ;;
        gnome-terminal)
            gnome-terminal -- "$AIBOX_SCRIPT" "${AIBOX_ARGS[@]}" >/dev/null 2>&1
            ;;
        konsole)
            konsole -e "$AIBOX_SCRIPT" "${AIBOX_ARGS[@]}" >/dev/null 2>&1
            ;;
        xfce4-terminal)
            xfce4-terminal --command "$AIBOX_SCRIPT ${AIBOX_ARGS[*]}" >/dev/null 2>&1
            ;;
        x-terminal-emulator)
            x-terminal-emulator -e "$AIBOX_SCRIPT" "${AIBOX_ARGS[@]}" >/dev/null 2>&1
            ;;
        xterm)
            xterm -e "$AIBOX_SCRIPT" "${AIBOX_ARGS[@]}" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# open_default_terminal: uses the freedesktop default terminal launcher. It
# waits for the command to end, so it runs in the background: the request must
# not block while the session is open.
open_default_terminal() {
    command -v xdg-terminal-exec >/dev/null 2>&1 || return 1

    xdg-terminal-exec -- "$AIBOX_SCRIPT" "${AIBOX_ARGS[@]}" >/dev/null 2>&1 </dev/null &
    local pid=$!

    # A launcher that fails exits at once; one that works stays alive with
    # the session.
    local waited=0
    while (( waited < 10 )) && kill -0 "$pid" 2>/dev/null; do
        sleep 0.1
        waited=$((waited + 1))
    done

    kill -0 "$pid" 2>/dev/null && return 0
    wait "$pid" 2>/dev/null
    return 1
}

# open_desktop_entry: asks the desktop environment to open a generated
# desktop entry marked with Terminal=true, so it uses the terminal the user
# configured as default. xdg-open always exits 0, even when nothing is
# opened, so the outcome cannot be reported: this is the last resort.
open_desktop_entry() {
    local launcher="$1" entry
    entry=$(temp_file desktop) || return 1

    {
        printf '[Desktop Entry]\n'
        printf 'Type=Application\n'
        printf 'Name=aibox terminal\n'
        printf 'Exec=%s %s\n' "$AIBOX_SCRIPT" "${AIBOX_ARGS[*]}"
        printf 'Terminal=true\n'
        printf 'NoDisplay=true\n'
    } > "$entry"
    chmod +x "$entry"

    "$launcher" "$entry" >/dev/null 2>&1
    local status=$?
    rm -f "$entry"
    return $status
}

# open_macos_terminal: macOS opens a .command script in Terminal.app.
open_macos_terminal() {
    command -v open >/dev/null 2>&1 || return 1

    local script
    script=$(temp_file command) || return 1
    {
        printf '#!/bin/sh\n'
        printf 'exec %s %s\n' "$AIBOX_SCRIPT" "${AIBOX_ARGS[*]}"
    } > "$script"
    chmod +x "$script"

    open -a Terminal "$script" >/dev/null 2>&1
    local status=$?
    rm -f "$script"
    return $status
}

if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    echo "No graphical session: run this command in a terminal instead:"
    echo "  $AIBOX_SCRIPT ${AIBOX_ARGS[*]}"
    exit 0
fi

# try_strategy <name>: opens the terminal with the given strategy.
try_strategy() {
    case "$1" in
        xdg-terminal-exec) open_default_terminal ;;
        xdg-open) open_desktop_entry "xdg-open" ;;
        gio) open_desktop_entry "gio open" ;;
        macos) open_macos_terminal ;;
        *) open_terminal "$1" ;;
    esac
}

# A forced strategy is used alone.
if [[ -n "$STRATEGY" ]]; then
    if try_strategy "$STRATEGY"; then
        exit 0
    fi
    echo "no terminal emulator found" >&2
    echo "Run this command in a terminal instead: $AIBOX_SCRIPT ${AIBOX_ARGS[*]}" >&2
    exit 1
fi

# The well known emulators first: they return their status at once.
for emulator in kitty alacritty wezterm foot gnome-terminal konsole xfce4-terminal x-terminal-emulator xterm; do
    command -v "$emulator" >/dev/null 2>&1 || continue
    if try_strategy "$emulator"; then
        exit 0
    fi
done

# Then the generic way: the default terminal of the desktop environment, as
# defined by the freedesktop default terminal specification. It covers any
# emulator that registers itself with a Terminal=true desktop entry.
if try_strategy "xdg-terminal-exec"; then
    exit 0
fi

if [[ "$(uname -s)" == "Darwin" ]] && try_strategy "macos"; then
    exit 0
fi

# Last resort: a generated desktop entry. xdg-open cannot report a failure,
# so the command to run by hand is printed as well.
if command -v xdg-open >/dev/null 2>&1 && open_desktop_entry "xdg-open"; then
    echo "  $AIBOX_SCRIPT ${AIBOX_ARGS[*]}"
    exit 0
fi

echo "no terminal emulator found" >&2
echo "Run this command in a terminal instead: $AIBOX_SCRIPT ${AIBOX_ARGS[*]}" >&2
exit 1
