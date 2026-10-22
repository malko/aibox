#!/bin/bash

# xterm-256 colour index closest to an RGB triple (6x6x6 cube).
_aibox_rgb256() {
    printf '%s' $(( 16 + 36*((($1)*5+127)/255) + 6*((($2)*5+127)/255) + ((($3)*5+127)/255) ))
}

# aibox_banner_render [24|256]
#   "AIBox" wordmark (ANSI Shadow, A/I/B uppercase + x-height o/x) in a frame.
#   Wordmark gradient is left -> right cyan/green -> orange (K2r); the frame
#   uses the K2 colour #C2410C; tagline is dim grey. 24 = truecolor.
aibox_banner_render() {
    local mode="${1:-24}"
    local esc reset
    esc=$'\033'
    reset="${esc}[0m"
    local border dim

    if [ "$mode" = "256" ]; then
        border="${esc}[38;5;$(_aibox_rgb256 194 65 12)m"
        dim="${esc}[2;38;5;$(_aibox_rgb256 148 163 184)m"
    else
        border="${esc}[38;2;194;65;12m"
        dim="${esc}[2;38;2;148;163;184m"
    fi

    local -a art=(
        " █████╗ ██╗██████╗"
        "██╔══██╗██║██╔══██╗"
        "███████║██║██████╔╝ ██████╗ ██╗  ██╗"
        "██╔══██║██║██╔══██╗██╔═══██╗╚██╗██╔╝"
        "██║  ██║██║██████╔╝╚██████╔╝██╔╝╚██╗"
        "╚═╝  ╚═╝╚═╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝"
    )

    # Without a UTF-8 locale bash counts bytes and would split the glyphs.
    case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
        *UTF-8*|*utf-8*|*utf8*|*UTF8*) ;;
        *)
            local l
            for l in "${art[@]}"; do printf '%s\n' "$l"; done
            printf '  your AI, in its own box\n'
            return 0
            ;;
    esac

    local w=38 i ch line out k r g b sr sg sb er eg eb t top=""
    for ((k=0;k<w;k++)); do top+="─"; done

    printf '%s╭%s╮%s\n' "$border" "$top" "$reset"
    for line in "${art[@]}"; do
        while [ "${#line}" -lt 36 ]; do line+=" "; done
        out=""
        for ((i=0;i<36;i++)); do
            ch=${line:i:1}
            if [ "$i" -lt 12 ]; then
                t=$i;          sr=34;  sg=211; sb=238; er=74;  eg=222; eb=128
            elif [ "$i" -lt 24 ]; then
                t=$((i-12));   sr=74;  sg=222; sb=128; er=251; eg=191; eb=36
            else
                t=$((i-24));   sr=251; sg=191; sb=36;  er=249; eg=115; eb=22
            fi
            r=$(( sr + (er-sr)*t/11 ))
            g=$(( sg + (eg-sg)*t/11 ))
            b=$(( sb + (eb-sb)*t/11 ))
            if [ "$mode" = "256" ]; then
                out="${out}${esc}[1;38;5;$(_aibox_rgb256 "$r" "$g" "$b")m${ch}"
            else
                out="${out}${esc}[1;38;2;${r};${g};${b}m${ch}"
            fi
        done
        printf '%s│%s %s %s│%s\n' "$border" "$reset" "$out" "$border" "$reset"
    done

    local tag=" your AI, in its own box" spaces=""
    for ((k=${#tag};k<w;k++)); do spaces+=" "; done
    printf '%s│%s%s%s%s%s│%s\n' "$border" "$reset" "$dim" "$tag$spaces" "$reset" "$border" "$reset"
    printf '%s╰%s╯%s\n' "$border" "$top" "$reset"
}

print_ascii_logo() {
    local mode=256
    case "${COLORTERM:-}${TERM:-}" in
        *truecolor*|*24bit*|*direct*) mode=24 ;;
    esac
    aibox_banner_render "$mode"
}

print_info() { echo -e "\033[0;34mℹ️  $1\033[0m"; }
print_success() { echo -e "\033[0;32m✅ $1\033[0m"; }
print_warn() { echo -e "\033[1;33m⚠️  $1\033[0m"; }
print_error() { echo -e "\033[0;31m❌ $1\033[0m" >&2; }

# True when the locale can render the UTF-8 glyphs of the status output.
aibox_utf8_locale() {
    case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
        *UTF-8*|*utf-8*|*utf8*|*UTF8*) return 0 ;;
    esac
    return 1
}

# True when the standard output is a terminal able to show colours.
aibox_color_terminal() {
    [[ -t 1 ]] || return 1
    [[ "${TERM:-}" != "dumb" ]] || return 1
    aibox_utf8_locale
}

# aibox_status_dot <state>
#   Availability marker of a service: a coloured dot on a terminal, nothing
#   when the output is redirected (the state is then given as text).
#   up -> green, down -> red, anything else -> dim.
aibox_status_dot() {
    local state="${1:-unknown}"
    local esc=$'\033'
    local color

    aibox_color_terminal || return 0

    case "$state" in
        up) color="0;32" ;;
        down) color="0;31" ;;
        *) color="0;90" ;;
    esac
    printf '%s[%sm●%s[0m ' "$esc" "$color" "$esc"
}

# aibox_status_text <state>
#   Availability state as text, used when the coloured dot is not shown.
aibox_status_text() {
    local state="${1:-unknown}"

    aibox_color_terminal && return 0

    case "$state" in
        up) printf '  [up]' ;;
        down) printf '  [down]' ;;
        *) printf '  [unknown]' ;;
    esac
}

# aibox_expand_tilde <path>
#   Expands a leading '~' to the home directory. Any other path is returned
#   unchanged, so it stays safe to use as a pattern.
aibox_expand_tilde() {
    local path="$1"
    # shellcheck disable=SC2088  # the tilde is matched literally, not expanded
    case "$path" in
        "~")   printf '%s\n' "$HOME" ;;
        "~/"*) printf '%s\n' "$HOME/${path#\~/}" ;;
        *)     printf '%s\n' "$path" ;;
    esac
}

# aibox_real_path <path>
#   Physical path of an existing file or directory, with the symlinks
#   resolved like the filesystem does. Returns 1 when the path does not
#   exist. A symlinked file keeps its name, only its parent directory is
#   resolved.
aibox_real_path() {
    local path="$1"
    local dir base

    if [[ ! -e "$path" ]]; then
        return 1
    fi

    if [[ -d "$path" ]]; then
        (cd -- "$path" && pwd -P) || return 1
        return 0
    fi

    dir="$(dirname -- "$path")"
    base="$(basename -- "$path")"
    [[ -d "$dir" ]] || return 1
    printf '%s/%s\n' "$(cd -- "$dir" && pwd -P)" "$base"
}

prompt() {
    local prompt_text="$1"
    local default="$2"
    local result
    if [[ -n "$default" ]]; then
        read -p "$prompt_text [$default]: " result
        echo "${result:-$default}"
    else
        read -p "$prompt_text: " result
        echo "$result"
    fi
}

prompt_yes_no() {
    local prompt_text="$1"
    local default="$2"
    local result
    while true; do
        if [[ "$default" == "yes" ]]; then
            read -p "$prompt_text [Y/n]: " result
            result="${result:-y}"
        else
            read -p "$prompt_text [y/N]: " result
            result="${result:-n}"
        fi
        case "$result" in
            y|Y) return 0 ;;
            n|N) return 1 ;;
        esac
    done
}

prompt_password() {
    local prompt_text="$1"
    local password=""
    local confirm=""
    
    while true; do
        read -s -p "$prompt_text: " password
        echo ""
        if [[ -z "$password" ]]; then
            print_error "Password cannot be empty"
            continue
        fi
        echo ""
        read -s -p "Confirm password: " confirm
        echo ""
        if [[ "$password" == "$confirm" ]]; then
            echo "$password"
            return 0
        else
            print_error "Passwords do not match, try again"
        fi
    done
}

# Cached VM info (VM name + last known IP). Stored in a user-owned runtime
# dir and parsed (not sourced) so its content is never executed as code.
VM_INFO_FILE="${XDG_RUNTIME_DIR:-$HOME/.cache}/aibox-vm-info"

save_vm_info() {
    local vm_name="$1"
    local guest_ip="$2"
    mkdir -p "$(dirname "$VM_INFO_FILE")"
    printf 'VM_NAME=%s\nGUEST_IP=%s\n' "$vm_name" "$guest_ip" > "$VM_INFO_FILE"
}

# Sets GUEST_IP from the cache. If a VM name is given, the cached IP is
# only used when it belongs to that VM.
load_vm_info() {
    local vm_name="${1:-}"
    [[ -f "$VM_INFO_FILE" ]] || return 0
    if [[ -n "$vm_name" ]]; then
        local cached_vm
        cached_vm=$(sed -n 's/^VM_NAME=//p' "$VM_INFO_FILE")
        [[ "$cached_vm" == "$vm_name" ]] || return 0
    fi
    GUEST_IP=$(sed -n 's/^GUEST_IP=//p' "$VM_INFO_FILE")
}

check_command() {
    if ! command -v "$1" &>/dev/null; then
        print_error "Command '$1' not found. Install it and try again."
        exit 1
    fi
}

check_requirements() {
    local missing=()

    for c in "$@"; do
        if ! command -v "$c" &>/dev/null; then
            missing+=("$c")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing required command(s): ${missing[*]}"
        exit 1
    fi
}

# True when running on macOS (Darwin).
is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

# Hostname used in LAN URLs. LAN_HOSTNAME overrides the detected mDNS name.
# macOS `hostname` already reports the .local suffix, so only append it when it
# is missing (Linux).
host_local_name() {
    local configured="" name

    if declare -F get_config >/dev/null 2>&1; then
        configured=$(get_config "LAN_HOSTNAME" "")
    fi

    if [[ -n "$configured" ]]; then
        printf '%s\n' "$configured"
        return 0
    fi

    name=$(hostname)
    if [[ "$name" != *.* ]]; then
        name="${name}.local"
    fi
    printf '%s\n' "$name"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
