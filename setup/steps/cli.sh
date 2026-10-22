#!/bin/bash

step_cli() {
    ADD_TO_PATH=$(prompt_config_yes_no "ADD_TO_PATH" "Add 'aibox' command to your PATH?" "yes")
    save_config "ADD_TO_PATH" "$ADD_TO_PATH"

    if [[ "$ADD_TO_PATH" != "yes" ]]; then
        print_info "Skipped PATH configuration."
        return 0
    fi

    SCRIPT_DIR_ABS="$(cd "$SCRIPT_DIR" && pwd)"
    BIN_DIR="$HOME/.local/bin"

    mkdir -p "$BIN_DIR"
    ln -sf "$SCRIPT_DIR_ABS/aibox" "$BIN_DIR/aibox"

    print_success "Added 'aibox' to $BIN_DIR/aibox"

    # The command was linked in a previous run, in the old location.
    OLD_LINK="$HOME/bin/aibox"
    if [[ -L "$OLD_LINK" ]]; then
        OLD_TARGET=$(readlink -f "$OLD_LINK" 2>/dev/null || true)
        if [[ "$OLD_TARGET" == "$SCRIPT_DIR_ABS/aibox" ]]; then
            rm -f "$OLD_LINK"
            print_info "Removed the old link '$OLD_LINK'."
        fi
    fi

    # The PATH is only touched when the command cannot be found already.
    hash -r 2>/dev/null || true
    AIBOX_FOUND=$(command -v aibox 2>/dev/null || true)
    if [[ "$AIBOX_FOUND" == "$BIN_DIR/aibox" ]]; then
        print_info "'aibox' is already in your PATH, no change made."
    elif [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
        print_info "'$BIN_DIR' is already in your PATH, no change made."
    else
        RC_FILE="$HOME/.profile"
        case "${SHELL##*/}" in
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

    ADD_COMPLETION=$(prompt_config_yes_no "ADD_COMPLETION" "Enable shell completion for aibox?" "yes")
    save_config "ADD_COMPLETION" "$ADD_COMPLETION"

    if [[ "$ADD_COMPLETION" != "yes" ]]; then
        return 0
    fi

    USER_SHELL="${SHELL##*/}"

    if [[ "$USER_SHELL" == "zsh" ]]; then
        ZSH_COMPLETION_DIR="$HOME/.zsh/completions"
        mkdir -p "$ZSH_COMPLETION_DIR"
        "$SCRIPT_DIR/aibox" --completion zsh > "$ZSH_COMPLETION_DIR/_aibox"
        print_success "Zsh completion enabled!"
        echo "Completion installed to ~/.zsh/completions/_aibox"
    else
        if ! grep -q 'source <(aibox --completion)' "$HOME/.bashrc" 2>/dev/null; then
            echo 'source <(aibox --completion)' >> "$HOME/.bashrc"
        fi
        print_success "Bash completion enabled!"
        echo "Run 'source ~/.bashrc' or restart your terminal"
    fi
}
