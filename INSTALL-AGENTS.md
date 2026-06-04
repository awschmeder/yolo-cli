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

#### Multi-line or Complex Commands

Do not use heredoc form (`$(cat <<'EOF' ... EOF)`). Tool parsers that match on `yolo -c` as
the command prefix are confused by multi-line strings and heredoc syntax.

Instead, collapse the command onto a single line using `\n` as the line separator within the
single-quoted string:

```bash
yolo -c 'line one\nline two\nline three'
```

For SSH remote commands with inner double quotes, escape them as `\"` inside the single-quoted
string is not possible -- use `\n`-separated lines and avoid inner double quotes by using
single quotes on the remote side where the shell allows it, or restructure the remote command
to avoid quoting conflicts.

Prefer `\n`-joined single-line form over heredoc whenever the command spans multiple logical
steps, since heredoc requires multi-line input that tool parsers cannot handle.

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
   For multi-line commands, collapse with `\n`:
   ```bash
   yolo -x 3fa8b1 -c 'find /tmp -name "*.log" -mtime +7\n| xargs rm -f'
   ```
4. **If the user declines** -- do not execute the command. Abandon the step or propose an
   alternative approach.

### Hash Binding and Command Integrity

The bypass hash is computed from the **exact command string** that was blocked. This means:

- The hash for `cat files.txt | xargs rm -f` differs from `cat files.txt | xargs rm -rf`.
- If you modify the command after receiving a bypass code, the old code is invalid.
- `yolo` will detect the mismatch and print a new hash for the modified command:
  ```
  ERROR: Invalid or mismatched YOLO hash code. If you have modified the command, the old code
  is expired. Use an elicitation tool to prompt the user for their approval of this modified
  command, and if they confirm then re-execute the command using: yolo -x df21ab -c '<new_cmd>'
  ```
- A modified command requires a fresh round of user approval before using the new hash.

## Rules

- **Always use `yolo -c`** -- pass every command through `yolo -c '...'` before execution,
  regardless of how safe the command appears. This includes read-only commands such as
  `find`, `ls`, `cat`, `grep`, `git status`, `git log`, `git diff`, and any other CLI tool.
  There are no exceptions based on command type or perceived safety.
- **Do not run the command separately** -- when using `-c`, `yolo` executes the command itself
  after approval. Running it again outside of `yolo` bypasses the safety check.
- **Never use heredoc form** -- do not use `yolo -c "$(cat <<'EOF' ... EOF)"`. Tool parsers
  match on `yolo -c` as the command prefix and are broken by multi-line heredoc syntax. Instead,
  collapse multi-step commands onto a single line using `\n` as the separator within the
  single-quoted string: `yolo -c 'step one\nstep two'`.
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


