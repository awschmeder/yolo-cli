# Add the yolo binary to PATH so it can be invoked directly.
export PATH="$HOME/.yolo/bin:$PATH"

# _yolo_active returns 0 (true) if any trigger env var is set.
# Reads YOLO_ENVS (comma-separated list of var names) when present;
# falls back to the built-in defaults otherwise.
_yolo_active() {
    local IFS=','
    local vars="${YOLO_ENVS:-YOLO_TEST,ROO_ACTIVE,ZOO_ACTIVE,CLAUDE_CODE,OPENCODE}"
    local var
    for var in $vars; do
        # Indirect expansion: test whether the named variable is non-empty
        if [ -n "${!var}" ]; then
            return 0
        fi
    done
    return 1
}

_yolo_preexec_trap() {
    # Re-check dynamically in case trigger vars are unset mid-session
    if ! _yolo_active; then
        return 0
    fi

    # Skip verifying if empty or if invoking the yolo command itself (to prevent infinite recursion)
    if [ -z "$BASH_COMMAND" ] || [[ "$BASH_COMMAND" =~ ^yolo(\ |$) ]] || [[ "$BASH_COMMAND" =~ ^YOLO= ]]; then
        return 0
    fi

    # Feed the command to yolo on stdin with --check so yolo gates but does not
    # exec -- the shell's DEBUG trap mechanism runs the command itself on exit 0.
    "$HOME/.yolo/bin/yolo" --check <<< "$BASH_COMMAND"
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        return 1 # Returns non-zero to block execution of BASH_COMMAND
    fi
    return 0
}

# Enable extdebug and register the DEBUG trap unconditionally so that
# yolo_activate / yolo_deactivate can toggle checking at any time without
# needing to re-source this file. _yolo_active() gates each invocation.
shopt -s extdebug
trap '_yolo_preexec_trap' DEBUG

# Set YOLO_INTERACTIVE=1, prefix the prompt with [yolo], and register a
# PROMPT_COMMAND hook that keeps the prefix in place across prompt resets.
yolo_activate() {
    export YOLO_INTERACTIVE=1
    # Save the current PS1 (strip any existing prefix to avoid doubling).
    _YOLO_SAVED_PS1="${PS1#\[yolo\] }"
    PS1="[yolo] $_YOLO_SAVED_PS1"
    # Keep the prefix alive even if other PROMPT_COMMAND entries reset PS1.
    _yolo_prompt_prefix() {
        [[ "$PS1" != \[yolo\]* ]] && PS1="[yolo] $PS1"
    }
    PROMPT_COMMAND="_yolo_prompt_prefix${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
    echo "[yolo] Activated."
}

# Unset YOLO_INTERACTIVE and restore the original prompt.
yolo_deactivate() {
    unset YOLO_INTERACTIVE
    # Restore saved PS1 if available; otherwise just strip the prefix.
    if [[ -n "${_YOLO_SAVED_PS1+x}" ]]; then
        PS1="$_YOLO_SAVED_PS1"
        unset _YOLO_SAVED_PS1
    else
        PS1="${PS1#\[yolo\] }"
    fi
    # Remove the prompt-prefix hook from PROMPT_COMMAND.
    PROMPT_COMMAND="${PROMPT_COMMAND//_yolo_prompt_prefix; /}"
    PROMPT_COMMAND="${PROMPT_COMMAND//_yolo_prompt_prefix/}"
    unset -f _yolo_prompt_prefix 2>/dev/null || true
    echo "[yolo] Deactivated."
}
