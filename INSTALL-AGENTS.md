# Agent Shell Safety Instructions

This project uses `yolo`, a pre-flight shell safety checker. Before executing any shell command,
you must submit the full command expression to `yolo` for safety evaluation. When invoked with
`-c`, `yolo` is responsible for both checking **and** running the command -- do not execute the
command separately.

### How to Execute Shell Commands

Use the `-c` flag to pass the entire command expression as a single string:

```
yolo -c '<your full command expression here>'
```

`yolo` will evaluate the command for safety and, if approved, execute it in the current user
shell. You do not need to run the command again after calling `yolo -c`.

The `-c` flag mirrors the `sh -c` convention and is the preferred form for all commands. It
ensures that shell operators (`|`, `&&`, `;`, `>`, etc.) are passed to `yolo` as part of the
command string rather than being interpreted by the shell before `yolo` can evaluate them.

#### Examples

```bash
# Simple command
yolo -c 'rm -rf ./dist'

# Chained commands
yolo -c 'git add . && git commit -m "fix: update config"'

# Piped pipeline
yolo -c 'cat files.txt | xargs rm -f'

# SSH remote command
yolo -c 'ssh mybox rm -rf /tmp/old-data'

# Semicolon-separated sequence
yolo -c 'mkdir -p ./out; cp build/* ./out/'
```

#### Heredoc Form (for commands with complex quoting)

When the command itself contains single quotes, use a heredoc to avoid quoting conflicts:

```bash
yolo -c "$(cat <<'EOF'
find /tmp -name '*.log' -mtime +7 | xargs rm -f
EOF
)"
```

The heredoc form is the most reliable option when the command contains a mix of single and
double quotes that would otherwise require complex escaping.

### What Happens When a Command Is Blocked

If `yolo` blocks a command, it exits with code `1` and prints a message like:

```
[YOLO BLOCKED] Reason: <explanation>
ERROR: This command requires explicit approval from the user. Use an elicitation tool to prompt
the user for their approval, and if they confirm then re-execute the command using:
yolo -x 3fa8b1 -c '<cmd>'
```

When this happens:

1. **Stop** -- do not attempt to re-run the command on your own.
2. **Elicit user approval** -- use your available tool to ask the user whether they approve the
   blocked command. Show them the exact command that was blocked and the reason given.
3. **If the user approves** -- re-run using the `-x` flag with the hash code printed in the
   error message. `yolo` will verify the hash and execute the command if it matches:
   ```bash
   yolo -x 3fa8b1 -c 'ssh mybox rm -rf /tmp/old-data'
   ```
   For heredoc form:
   ```bash
   yolo -x 3fa8b1 -c "$(cat <<'EOF'
   find /tmp -name '*.log' -mtime +7 | xargs rm -f
   EOF
   )"
   ```
4. **If the user declines** -- do not execute the command. Abandon the step or propose an
   alternative approach.

The bypass hash is derived from the exact command string. If the command is modified between
approval and re-execution, the old code no longer matches and `yolo` prints a new one, requiring
a fresh round of user approval. The resubmitted command must match exactly.

## Rules

- **Always use `yolo -c`** -- pass every command through `yolo -c '...'` before execution,
  regardless of how safe the command appears.
- **Do not run the command separately** -- when using `-c`, `yolo` executes the command itself
  after approval. Running it again outside of `yolo` bypasses the safety check.
- **Always use `-c` for compound expressions** -- any command containing `|`, `&&`, `||`, `;`,
  `>`, `<`, or backticks must use the `-c` flag. Without it, the shell parses those operators
  before `yolo` runs, bypassing the safety check entirely.
- **Use `-x` for bypass codes** -- when re-running a blocked command with user approval, supply
  the hash via `yolo -x <hash> -c '<cmd>'`. Do not embed the `YOLO=<hash>` prefix inside the
  command string.
- **Never fabricate a bypass hash** -- bypass codes are SHA-256-derived from the command string.
  Constructing one manually will fail and signals an attempt to circumvent safety controls.
- **Never auto-approve blocked commands** -- a block always requires explicit user confirmation
  before re-execution with the `-x` bypass flag.
- **Treat exit code 1 as a hard stop** -- a non-zero exit from `yolo` means the command did not
  run. Do not assume it executed or proceed as if it did.
- **Do not split compound commands to avoid review** -- breaking `cmd1 && cmd2` into two
  separate `yolo -c` calls to make each look simpler is not acceptable. Submit the full intended
  expression as a single invocation so the combined effect is evaluated.

---

