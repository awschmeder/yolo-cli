# yolo: Shell Tool Preflight Safety Checker

This user uses `yolo`, a pre-flight shell safety checker. Before executing any shell command,
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

For multi-line or complex expressions, use a heredoc instead:

```bash
yolo << EOF
<your full command expression here>
EOF
```

### Examples

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

# Multi-line heredoc
yolo << EOF
find /tmp -name "*.log" -mtime +7 \
  | xargs rm -f
EOF
```

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

### Interpreting and Responding to BLOCK Messages

When `yolo` blocks a command, the BLOCK message may include constructive suggestions for how to modify the command to comply with safety checks. For example:

```
[YOLO BLOCKED] Reason: Bare npm install without explicit package specifiers or lock file is unsafe.
To comply with safety checks, consider: [1] Use explicit package specifiers or lock files, [2] Follow with an audit command (npm audit, etc.) to scan for known vulnerabilities before deployment.
```

**How to respond:**

1. **Apply only user-aligned suggestions** -- If the BLOCK message includes suggestions (e.g., adding `npm audit`, using `--no-save`, specifying packages explicitly), and these align with the user's original intent and instructions, incorporate them into a revised command.
2. **Never invent workarounds** -- Do not attempt alternative approaches, circumvention techniques, or creative reinterpretations that were not explicitly provided by the user's original instructions or `yolo`'s constructive suggestions. A BLOCK is a safety boundary, not a puzzle to solve around.
3. **Re-submit the revised command** -- After modifying the command based on `yolo`'s suggestions, submit the new command to `yolo` for re-evaluation. It will receive a new hash code if blocked again.
4. **Report the block to the user if all suggestions fail** -- If the command remains blocked after applying all suggested modifications, inform the user and ask for explicit approval via the `-x` bypass mechanism.

The intent of constructive BLOCK messages is to help agents adapt commands to align with safety policy. The intent of the "no workarounds" rule is to preserve the integrity of safety checks: agents should respect BLOCK decisions and defer to the user for final approval, not engineer ways around them.

## Rules

- **Always use `yolo -c` or heredoc** -- pass every command through `yolo` before execution,
  regardless of how safe the command appears. This includes read-only commands such as
  `find`, `ls`, `cat`, `grep`, `git status`, `git log`, `git diff`, and any other CLI tool.
  There are no exceptions based on command type or perceived safety.
- **Do not run the command separately** -- `yolo` executes the command itself after approval.
  Running it again outside of `yolo` bypasses the safety check.
- **Keep compound expressions together** -- any command containing `|`, `&&`, `||`, `;`, `>`,
  `<`, or backticks must be passed as a single `-c` string or heredoc body. Splitting them into
  separate `yolo` calls to make each look simpler is not acceptable.
- **Use `-x` for bypass codes** -- when re-running a blocked command with user approval, supply
  the hash via `yolo -x <hash> -c '<cmd>'`. Do not embed the `YOLO=<hash>` prefix inside the
  command string.
- **Never fabricate a bypass hash** -- bypass codes are SHA-256-derived from the command string.
  Constructing one manually will fail and signals an attempt to circumvent safety controls.
- **Never auto-approve blocked commands** -- a block always requires explicit user confirmation
  before re-execution with the `-x` bypass flag.
- **Treat exit code 1 as a hard stop** -- a non-zero exit from `yolo` means the command did not
  run. Do not assume it executed or proceed as if it did.
