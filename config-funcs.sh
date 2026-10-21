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

    if [[ "${AIBOX_ASSUME_YES:-0}" == "1" ]]; then
        printf '%s\n' "$current_value"
        return 0
    fi

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

    if [[ "${AIBOX_ASSUME_YES:-0}" == "1" ]]; then
        case "$current_value" in
            yes|y|Y) printf '%s\n' "yes" ;;
            no|n|N|"") printf '%s\n' "no" ;;
            *) printf '%s\n' "$current_value" ;;
        esac
        return 0
    fi

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
            local tmp
            escaped_value=$(printf '%s' "$shell_value" | sed -e 's/[&|\\]/\\&/g')
            tmp=$(mktemp "${CONFIG_FILE}.XXXXXX") || return 1
            if sed "s|^${key}=.*|${key}=\"${escaped_value}\"|" "$CONFIG_FILE" > "$tmp"; then
                mv "$tmp" "$CONFIG_FILE"
            else
                rm -f "$tmp"
                return 1
            fi
        else
            printf '%s\n' "${key}=\"${shell_value}\"" >> "$CONFIG_FILE"
        fi
    fi
}

unset_config() {
    local key="$1" tmp rc

    [[ -n "$key" && -f "$CONFIG_FILE" ]] || return 0
    mkdir -p "$(dirname "$CONFIG_FILE")" || return 1
    tmp=$(mktemp "${CONFIG_FILE}.XXXXXX") || return 1

    if grep -vE "^${key}=" "$CONFIG_FILE" > "$tmp"; then
        mv "$tmp" "$CONFIG_FILE"
    else
        rc=$?
        if [[ "$rc" -eq 1 ]]; then
            # No line matched the key: the filtered file is valid and empty.
            mv "$tmp" "$CONFIG_FILE"
        else
            rm -f "$tmp"
            return 1
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
