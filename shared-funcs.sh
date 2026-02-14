#!/bin/bash

print_ascii_logo() {
    local CYAN='\033[0;36m'
    local NC='\033[0m'
    echo -e "${CYAN}"
    cat << 'EOF'
       d8888 d8b 888888b.                    
      d88888 Y8P 888  °88b                   
     d88P888     888  .88P                   
    d88P 888 888 8888888K.   .d88b.  888  888
   d88P  888 888 888  ¨Y88b d88°°88b ¨Y8bd8P¨
  d88P   888 888 888    888 888  888   X88K  
 d8888888888 888 888   d88P Y88..88P .d8¨¨8b.
d88P     888 888 8888888P"   "Y88P"  888  888
EOF
    echo -e "${NC}"
}

print_info() { echo -e "\033[0;34mℹ️  $1\033[0m"; }
print_success() { echo -e "\033[0;32m✅ $1\033[0m"; }
print_warn() { echo -e "\033[1;33m⚠️  $1\033[0m"; }
print_error() { echo -e "\033[0;31m❌ $1\033[0m" >&2; }

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

check_command() {
    if ! command -v "$1" &>/dev/null; then
        print_error "Command '$1' not found. Install it and try again."
        exit 1
    fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
