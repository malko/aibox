#!/bin/bash

# The login shell is the one whose rc file must be updated, even when setup
# itself runs from another shell (or from the web console).
detect_login_shell() {
    local shell="${SHELL:-}"

    if [[ -z "$shell" ]] && command -v getent >/dev/null 2>&1; then
        shell=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)
    fi
    if [[ -z "$shell" ]] && [[ "$(uname -s)" == "Darwin" ]]; then
        shell=$(dscl . -read "/Users/$(id -un)" UserShell 2>/dev/null | awk '{print $2}')
    fi

    printf '%s\n' "${shell##*/}"
}

install_bash_completion() {
    local rc="$HOME/.bashrc"

    if grep -qF '# aibox shell completion' "$rc" 2>/dev/null; then
        print_info "Bash completion is already installed in $rc."
        return 0
    fi
    if grep -qF 'aibox --completion' "$rc" 2>/dev/null; then
        print_info "Bash completion is already configured in $rc."
        return 0
    fi

    touch "$rc"
    cat >> "$rc" <<'EOF'

# aibox shell completion (added by aibox setup)
if [ -r "$HOME/.local/bin/aibox" ]; then
    source <("$HOME/.local/bin/aibox" --completion bash)
fi
EOF

    print_success "Bash completion enabled!"
    echo "Run 'source ~/.bashrc' or restart your terminal"
}

install_zsh_completion() {
    local dir="$HOME/.zsh/completions"
    local rc="$HOME/.zshrc"

    mkdir -p "$dir"
    "$SCRIPT_DIR/aibox" --completion zsh > "$dir/_aibox"

    if grep -qF '# aibox shell completion' "$rc" 2>/dev/null; then
        print_info "Zsh completion is already installed in $rc."
    else
        touch "$rc"
        cat >> "$rc" <<'EOF'

# aibox shell completion (added by aibox setup)
fpath=("$HOME/.zsh/completions" $fpath)
if [[ -r "$HOME/.zsh/completions/_aibox" ]]; then
    if ! (( $+functions[compdef] )); then
        autoload -Uz compinit && compinit
    fi
    autoload -Uz _aibox
    compdef _aibox aibox
fi
EOF

        print_success "Zsh completion enabled!"
        echo "Run 'source ~/.zshrc' or restart your terminal"
    fi
    echo "Completion installed to $dir/_aibox"
}

step_cli() {
    ADD_TO_PATH=$(prompt_config_yes_no "ADD_TO_PATH" "Add 'aibox' command to your PATH?" "yes")
    save_config "ADD_TO_PATH" "$ADD_TO_PATH"

    SCRIPT_DIR_ABS="$(cd "$SCRIPT_DIR" && pwd)"
    BIN_DIR="$HOME/.local/bin"

    mkdir -p "$BIN_DIR"
    ln -sf "$SCRIPT_DIR_ABS/aibox" "$BIN_DIR/aibox"
    print_success "Linked 'aibox' to $BIN_DIR/aibox"

    # The command was linked in a previous run, in the old location.
    OLD_LINK="$HOME/bin/aibox"
    if [[ -L "$OLD_LINK" ]]; then
        OLD_TARGET=$(resolve_symlinks "$OLD_LINK" 2>/dev/null || true)
        if [[ "$OLD_TARGET" == "$SCRIPT_DIR_ABS/aibox" ]]; then
            rm -f "$OLD_LINK"
            print_info "Removed the old link '$OLD_LINK'."
        fi
    fi

    if [[ "$ADD_TO_PATH" == "yes" ]]; then
        # The PATH is only touched when the command cannot be found already.
        hash -r 2>/dev/null || true
        AIBOX_FOUND=$(command -v aibox 2>/dev/null || true)
        if [[ "$AIBOX_FOUND" == "$BIN_DIR/aibox" ]]; then
            print_info "'aibox' is already in your PATH, no change made."
        elif [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
            print_info "'$BIN_DIR' is already in your PATH, no change made."
        else
            RC_FILE="$HOME/.profile"
            case "$(detect_login_shell)" in
                zsh)  RC_FILE="$HOME/.zshrc" ;;
                bash) RC_FILE="$HOME/.bashrc" ;;
            esac

            if ! grep -qF 'export PATH="$HOME/.local/bin:$PATH"' "$RC_FILE" 2>/dev/null; then
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC_FILE"
                print_info "Added '$BIN_DIR' to your PATH in $RC_FILE"
                echo "Run 'source $RC_FILE' or restart your terminal"
            else
                print_info "'$BIN_DIR' is already in your PATH in $RC_FILE, no change made."
                echo "Run 'source $RC_FILE' or restart your terminal"
            fi
        fi
    else
        print_info "Skipped PATH configuration."
    fi

    # Completion is independent of the PATH choice: the command is linked
    # above and the rc line uses its absolute path. It is installed for the
    # login shell, not necessarily the shell running setup.
    ADD_COMPLETION=$(get_config "ADD_COMPLETION" "yes")
    if [[ "$ADD_COMPLETION" != "yes" ]]; then
        print_info "Shell completion disabled in the configuration (ADD_COMPLETION=no)."
        return 0
    fi

    USER_SHELL=$(detect_login_shell)
    case "$USER_SHELL" in
        zsh)
            install_zsh_completion
            ;;
        bash)
            install_bash_completion
            ;;
        *)
            print_info "Shell completion is only available for bash and zsh (detected: ${USER_SHELL:-unknown})."
            ;;
    esac
}
