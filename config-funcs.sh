#!/bin/bash

get_config() {
    local key="$1"
    local default="$2"
    local value

    value="${!key}"

    if [[ -z "$value" && -n "$default" ]]; then
        echo "$default"
    elif [[ -n "$value" ]]; then
        echo "$value"
    else
        echo ""
    fi
}

prompt_config() {
    local key="$1"
    local prompt_text="$2"
    local default="$3"
    local result

    local current_value
    current_value=$(get_config "$key" "$default")

    if [[ -n "$current_value" ]]; then
        read -p "$prompt_text [$current_value]: " result
        result="${result:-$current_value}"
    else
        read -p "$prompt_text: " result
    fi

    echo "$result"
}

prompt_config_yes_no() {
    local key="$1"
    local prompt_text="$2"
    local default="$3"
    local current_value
    local result

    current_value=$(get_config "$key" "$default")

    while true; do
        if [[ "$current_value" == "yes" || "$current_value" == "y" ]]; then
            read -p "$prompt_text [Y/n]: " result
            result="${result:-y}"
        else
            read -p "$prompt_text [y/N]: " result
            result="${result:-n}"
        fi
        case "$result" in
            y|Y) echo "yes"; return 0 ;;
            n|N) echo "no"; return 0 ;;
        esac
    done
}

save_config() {
    local key="$1"
    local value="$2"

    mkdir -p "$(dirname "$CONFIG_FILE")"

    if [[ -n "$key" && -n "$value" ]]; then
        # The config file is later sourced, so first escape the value for the
        # double-quoted assignment, then escape the characters sed treats
        # specially in the replacement ('|' delimiter, '&' whole match, '\').
        local shell_value escaped_value
        shell_value=$(printf '%s' "$value" | sed -e 's/[\\"$`]/\\&/g')

        if grep -qE "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
            escaped_value=$(printf '%s' "$shell_value" | sed -e 's/[&|\\]/\\&/g')
            sed -i "s|^${key}=.*|${key}=\"${escaped_value}\"|" "$CONFIG_FILE"
        else
            printf '%s\n' "${key}=\"${shell_value}\"" >> "$CONFIG_FILE"
        fi
    fi
}

init_config_file() {
    local config_dir
    config_dir=$(dirname "$CONFIG_FILE")
    mkdir -p "$config_dir"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        touch "$CONFIG_FILE"
    fi

    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
}
