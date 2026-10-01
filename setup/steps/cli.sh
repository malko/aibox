#!/bin/bash

step_cli() {
    ADD_TO_PATH=$(prompt_config_yes_no "ADD_TO_PATH" "Add 'aibox' command to your PATH?" "yes")
    save_config "ADD_TO_PATH" "$ADD_TO_PATH"

    if [[ "$ADD_TO_PATH" != "yes" ]]; then
        print_info "Skipped PATH configuration."
        return 0
    fi

    SCRIPT_DIR_ABS="$(cd "$SCRIPT_DIR" && pwd)"
    BIN_DIR="$HOME/bin"

    mkdir -p "$BIN_DIR"
    ln -sf "$SCRIPT_DIR_ABS/aibox" "$BIN_DIR/aibox"

    # macOS default shells are zsh; write to the matching rc file.
    USER_SHELL="${SHELL##*/}"
    if [[ "$USER_SHELL" == "zsh" ]]; then
        RC_FILE="$HOME/.zshrc"
    else
        RC_FILE="$HOME/.bashrc"
    fi

    if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$RC_FILE" 2>/dev/null; then
        printf '\n# Added by aibox setup\nexport PATH="$HOME/bin:$PATH"\n' >> "$RC_FILE"
    fi

    print_success "Added 'aibox' to $BIN_DIR/aibox"
    echo "Make sure '$HOME/bin' is in your PATH (added to ~/${RC_FILE##*/})"
    echo "Run 'source ~/${RC_FILE##*/}' or restart your terminal"

    ADD_COMPLETION=$(prompt_config_yes_no "ADD_COMPLETION" "Enable shell completion for aibox?" "yes")
    save_config "ADD_COMPLETION" "$ADD_COMPLETION"

    if [[ "$ADD_COMPLETION" != "yes" ]]; then
        return 0
    fi

    if [[ "$USER_SHELL" == "zsh" ]]; then
        ZSH_COMPLETION_DIR="$HOME/.zsh/completions"
        mkdir -p "$ZSH_COMPLETION_DIR"
        "$SCRIPT_DIR/aibox" --completion zsh > "$ZSH_COMPLETION_DIR/_aibox"

        if ! grep -q 'fpath=(~/.zsh/completions' "$HOME/.zshrc" 2>/dev/null; then
            {
                echo ''
                echo '# Added by aibox setup'
                echo 'fpath=(~/.zsh/completions $fpath)'
                echo 'autoload -Uz compinit && compinit'
            } >> "$HOME/.zshrc"
        fi

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
