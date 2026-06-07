# Add the yolo binary to PATH so it can be invoked directly.
export PATH="$HOME/.yolo/bin:$PATH"

# _yolo_active returns 0 (true) if any trigger env var is set.
# Reads YOLO_ENVS (comma-separated list of var names) when present;
# falls back to the built-in defaults otherwise.
_yolo_active() {
    local vars="${YOLO_ENVS:-YOLO_TEST,ROO_ACTIVE,ZOO_ACTIVE,CLAUDE_CODE,OPENCODE}"
    local var
    # Split on commas without modifying IFS globally
    for var in ${(s:,:)vars}; do
        # Indirect expansion via (P) flag: test whether the named variable is non-empty
        if [[ -n "${(P)var}" ]]; then
            return 0
        fi
    done
    return 1
}

_yolo_accept_line() {
    # Re-check dynamically in case trigger vars are unset mid-session
    if ! _yolo_active; then
        zle .accept-line
        return
    fi

    local cmd="${BUFFER}"

    # Skip verifying if empty or if invoking yolo or YOLO prefix
    if [[ -z "${cmd// }" ]] || [[ "$cmd" =~ ^yolo(\ |$) ]] || [[ "$cmd" =~ ^YOLO= ]]; then
        zle .accept-line
        return
    fi

    # Always suspend ZLE so the terminal is in a clean state before yolo runs.
    # zle -I moves the cursor to a new line (emitting one \n) and hands the
    # terminal back to the calling process.
    zle -I

    # Feed the command to yolo on stdin with --check so yolo gates but does not
    # exec -- zle .accept-line runs the command itself on exit 0.
    "$HOME/.yolo/bin/yolo" --check <<< "$cmd"
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        # Redraw prompt and empty buffer or reset prompt so the execution is blocked
        zle reset-prompt
    else
        # zle -I emitted one newline to move past the prompt. Move the cursor
        # back up one line so zle .accept-line redraws the prompt+command
        # in-place rather than on a blank line below it.
        echoti cuu1
        zle .accept-line
    fi
}

# Ensure this hook is only loaded in interactive zsh sessions
if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook

    # Re-bind the widget from a precmd hook so it runs after all startup scripts
    # complete -- including VSCode's shell integration injection, which sources
    # .zshrc mid-init and causes any zle -N calls made during sourcing to be
    # reset before the first prompt is drawn.
    _yolo_bind_widget() {
        zle -N accept-line _yolo_accept_line
        # One-shot: remove itself after the first run.
        add-zsh-hook -d precmd _yolo_bind_widget
        unfunction _yolo_bind_widget 2>/dev/null || true
    }
    add-zsh-hook precmd _yolo_bind_widget
fi

# Set YOLO_INTERACTIVE=1 and prefix the prompt with [yolo] via a precmd hook
# that survives theme resets.
yolo_activate() {
    export YOLO_INTERACTIVE=1
    autoload -Uz add-zsh-hook
    # Precmd hook: strips any existing [yolo] prefix then re-prepends it, so
    # the prefix survives theme resets and VSCode shell-integration rewrites
    # without ever doubling up.
    _yolo_precmd() {
        PROMPT="${PROMPT#\[yolo\] }"
        PROMPT="[yolo] $PROMPT"
    }
    # Only register the hook if it is not already present.
    if ! (( ${precmd_functions[(Ie)_yolo_precmd]} )); then
        add-zsh-hook precmd _yolo_precmd
    fi
    # Apply immediately so the next prompt shows the prefix without waiting.
    PROMPT="${PROMPT#\[yolo\] }"
    PROMPT="[yolo] $PROMPT"
    echo "[yolo] Activated."
}

# Unset YOLO_INTERACTIVE and remove the prompt prefix.
yolo_deactivate() {
    unset YOLO_INTERACTIVE
    add-zsh-hook -d precmd _yolo_precmd 2>/dev/null || true
    PROMPT="${PROMPT#\[yolo\] }"
    unfunction _yolo_precmd 2>/dev/null || true
    echo "[yolo] Deactivated."
}
