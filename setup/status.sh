#!/bin/bash
# Installation status detection for setup steps.
#
# Sourced by setup.sh when --status is used. The probe is best-effort: a
# missing VM or an unreachable guest reports "unknown" instead of failing.

declare -A STATUS_STEP_STATUS=()
declare -A STATUS_STEP_REASON=()
declare -A STATUS_WEB_RUNNABLE=()

STATUS_VM_EXISTS=false
STATUS_VM_RUNNING=false
STATUS_VM_STATE="unknown"
STATUS_VM_IP=""
STATUS_GUEST_REACHABLE=false
STATUS_GUEST_PROBE=""

status_config_key() {
    case "$1" in
        deps) echo "INSTALL_DEPS" ;;
        sshd) echo "DISABLE_PASSWORD_AUTH" ;;
        git) echo "CONFIGURE_GIT" ;;
        hosts) echo "CONFIGURE_HOST_ACCESS" ;;
        motd) echo "CONFIGURE_MOTD" ;;
        docker) echo "INSTALL_DOCKER" ;;
        vscode) echo "INSTALL_VSCODE" ;;
        dsh) echo "INSTALL_DSH" ;;
        claude) echo "INSTALL_CLAUDE" ;;
        update-check) echo "INSTALL_UPDATE_CHECK" ;;
        virtiofs) echo "CONFIGURE_VIRTIOFS" ;;
        cli) echo "ADD_TO_PATH" ;;
        tunnel) echo "INSTALL_TUNNEL" ;;
        *) echo "" ;;
    esac
}

status_is_configured_off() {
    local key="${1:-}"
    [[ -n "$key" ]] || return 1
    [[ "$(get_config "$key" "")" == "no" ]]
}

status_self_needs_sudo() {
    case "$1" in
        deps|sshd|hosts|motd|docker|opencode|dsh) return 0 ;;
        *) return 1 ;;
    esac
}

status_needs_sudo_with_deps() {
    local step="$1" dep

    status_self_needs_sudo "$step" && return 0
    for dep in ${SETUP_STEP_DEPS[$step]:-}; do
        status_needs_sudo_with_deps "$dep" && return 0
    done
    return 1
}

status_is_web_runnable() {
    case "$1" in
        vm|ssh|vscode|virtiofs) return 1 ;;
        *) return 0 ;;
    esac
}

status_web_reason() {
    case "$1" in
        vm) echo "VM creation is CLI-only" ;;
        ssh) echo "SSH setup may ask for a password" ;;
        vscode) echo "vscode-server asks for a password" ;;
        virtiofs) echo "modifies the host libvirt configuration" ;;
        *) echo "" ;;
    esac
}

status_probe_guest() {
    [[ "$STATUS_GUEST_REACHABLE" == "true" ]] || return 0

    local output
    output=$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$GUEST_USER@$STATUS_VM_IP" 'bash -s' 2>/dev/null <<'PROBE'
set -u

export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh" >/dev/null 2>&1 || true
fi

check() {
    if eval "$2" >/dev/null 2>&1; then
        echo "$1=installed"
    else
        echo "$1=missing"
    fi
}

check scripts 'test -f "$HOME/scripts/update-check.sh"'
check deps 'command -v node && command -v npm && command -v opencode'
check sshd 'grep -qs "^PasswordAuthentication no" /etc/ssh/sshd_config.d/00-aibox.conf'
check git 'test -n "$(git config --global user.name 2>/dev/null)"'
check dirs 'test -d "$HOME/git/opencode/agents"'
check hosts 'grep -q "aibox-host" /etc/hosts'
check motd 'test -x /etc/profile.d/motd.sh'
check docker 'command -v docker'
check vscode 'test -f "$HOME/vscode-server/docker-compose.yml"'
check opencode 'systemctl --user cat opencode.service'
check dsh 'command -v dsh && systemctl --user cat dsh-web.service'
check claude 'command -v claude'
check update-check 'systemctl --user cat aibox-update-check.timer'
check virtiofs 'test "$(findmnt -n -o FSTYPE "$HOME/git" 2>/dev/null)" = virtiofs'
PROBE
) || output=""

    local line key value
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        key="${line%%=*}"
        value="${line#*=}"
        STATUS_GUEST_PROBE["$key"]="$value"
    done <<< "$output"
}

status_guest_value() {
    local key="$1"
    if [[ "$STATUS_VM_RUNNING" != "true" ]]; then
        echo "unknown"
        return 0
    fi
    if [[ "$STATUS_GUEST_REACHABLE" != "true" ]]; then
        echo "unknown"
        return 0
    fi
    echo "${STATUS_GUEST_PROBE[$key]:-unknown}"
}

status_collect() {
    source "$SCRIPT_DIR/host/vm.sh"

    setup_ensure_host_context

    STATUS_VM_EXISTS=false
    STATUS_VM_RUNNING=false
    STATUS_VM_STATE="unknown"
    STATUS_VM_IP=""
    STATUS_GUEST_REACHABLE=false
    STATUS_GUEST_PROBE=()

    if vm_exists "$VM_NAME"; then
        STATUS_VM_EXISTS=true
        STATUS_VM_STATE=$(vm_state "$VM_NAME")
        if [[ "$STATUS_VM_STATE" == "running" ]]; then
            STATUS_VM_RUNNING=true
            STATUS_VM_IP=$(vm_ip "$VM_NAME")
            if [[ -z "$STATUS_VM_IP" ]]; then
                load_vm_info "$VM_NAME"
                STATUS_VM_IP="$GUEST_IP"
            fi
            if [[ -n "$STATUS_VM_IP" ]] && nc -z -w 1 "$STATUS_VM_IP" 22 &>/dev/null; then
                STATUS_GUEST_REACHABLE=true
            fi
        fi
    fi

    status_probe_guest

    local step status reason key
    for step in "${SETUP_STEP_ORDER[@]}"; do
        case "$step" in
            vm)
                if [[ "$STATUS_VM_EXISTS" == "true" ]]; then
                    status="installed"
                else
                    status="missing"
                fi
                ;;
            ssh)
                if [[ "$STATUS_GUEST_REACHABLE" == "true" ]]; then
                    status="installed"
                elif [[ "$STATUS_VM_RUNNING" == "true" ]]; then
                    status="missing"
                else
                    status="unknown"
                fi
                ;;
            cli)
                if [[ -L "$HOME/.local/bin/aibox" || -x "$HOME/.local/bin/aibox" \
                   || -L "$HOME/bin/aibox" || -x "$HOME/bin/aibox" ]]; then
                    status="installed"
                else
                    status="missing"
                fi
                ;;
            tunnel)
                if "$SCRIPT_DIR/cmd/tunnel" installed >/dev/null 2>&1; then
                    status="installed"
                else
                    status="missing"
                fi
                ;;
            *)
                status=$(status_guest_value "$step")
                ;;
        esac

        key=$(status_config_key "$step")
        if [[ "$status" == "missing" ]] && status_is_configured_off "$key"; then
            status="disabled"
        fi

        reason=$(status_web_reason "$step")
        if [[ -z "$reason" ]]; then
            if [[ "$status" == "disabled" ]]; then
                reason="disabled in config"
            elif [[ "$status" == "unknown" && "$step" != "ssh" ]]; then
                reason="VM is not running or not reachable"
            fi
        fi

        STATUS_STEP_STATUS["$step"]="$status"
        STATUS_STEP_REASON["$step"]="$reason"
        if status_is_web_runnable "$step"; then
            STATUS_WEB_RUNNABLE["$step"]=true
        else
            STATUS_WEB_RUNNABLE["$step"]=false
        fi
    done
}

setup_status_json() {
    status_collect

    local tmp step web_json reason needs_sudo
    tmp=$(mktemp) || return 1

    for step in "${SETUP_STEP_ORDER[@]}"; do
        web_json=false
        [[ "${STATUS_WEB_RUNNABLE[$step]:-false}" == "true" ]] && web_json=true
        reason="${STATUS_STEP_REASON[$step]:-}"
        needs_sudo=false
        needs_sudo_with_deps=false
        status_self_needs_sudo "$step" && needs_sudo=true
        status_needs_sudo_with_deps "$step" && needs_sudo_with_deps=true

        jq -n \
            --arg name "$step" \
            --arg description "${SETUP_STEP_DESC[$step]}" \
            --arg status "${STATUS_STEP_STATUS[$step]}" \
            --argjson web_runnable "$web_json" \
            --argjson needs_sudo "$needs_sudo" \
            --argjson needs_sudo_with_deps "$needs_sudo_with_deps" \
            --arg reason "$reason" \
            '{
                name: $name,
                description: $description,
                status: $status,
                web_runnable: $web_runnable,
                needs_sudo: $needs_sudo,
                needs_sudo_with_deps: $needs_sudo_with_deps,
                reason: (if $reason == "" then null else $reason end)
            }' >> "$tmp"
    done

    local steps_json
    steps_json=$(jq -s '.' "$tmp")
    rm -f "$tmp"

    jq -n \
        --arg vm_name "$VM_NAME" \
        --argjson vm_exists "$STATUS_VM_EXISTS" \
        --argjson vm_running "$STATUS_VM_RUNNING" \
        --arg vm_state "$STATUS_VM_STATE" \
        --arg vm_ip "$STATUS_VM_IP" \
        --argjson steps "$steps_json" \
        '{
            vm: {
                name: $vm_name,
                exists: $vm_exists,
                running: $vm_running,
                state: $vm_state,
                ip: (if $vm_ip == "" then null else $vm_ip end)
            },
            steps: $steps
        }'
}

setup_status_human() {
    status_collect

    echo "Setup status:"
    printf '  %-14s %-11s %s\n' "vm" "${STATUS_STEP_STATUS[vm]}" "${STATUS_STEP_DESC[vm]}"

    local step
    for step in "${SETUP_STEP_ORDER[@]}"; do
        [[ "$step" == "vm" ]] && continue
        printf '  %-14s %-11s %s\n' \
            "$step" \
            "${STATUS_STEP_STATUS[$step]}" \
            "${SETUP_STEP_DESC[$step]}"
    done
}
