# Project Guidelines: YOLO Pre-Flight Shell Checker

This file details instructions, project preferences, and coding standards for the `yolo` workspace.

---

## Technical Stack Selection

- **CLI core**: Go standard library (using `flag` package, `crypto/sha256`, and `net/http` for API requests). No external third-party Go dependencies to keep the binary small and compile times rapid.
- **Shell Integrations**:
  - `shell/yolo-setup.bash`: Uses extdebug + DEBUG trap for command validation.
  - `shell/yolo-setup.zsh`: Overrides the interactive `accept-line` widget to hook command execution.

---

## Key Design Principles & Policies

### 1. Fail-Safe Execution Strategy
All runtime failures must fail-safe. If the model or configuration checks error out, the CLI blocks the shell command from running to prevent accidental execution of harmful commands:
- Exit code `0`: Safe to execute command.
- Exit code `1`: Block execution of command.

### 2. Bypass Mechanisms
- **Hash-Based Verification**: We support stateless bypasses via the `-x` flag: `yolo -x <6_char_hash> -c '<command>'`. The hash is the first 6 hex characters of the SHA-256 of the trimmed command string, so it authorizes only the exact command that was reviewed.
- **Interactive TTY Prompt**: When `YOLO_INTERACTIVE=1` is set, `yolo` must read directly from `/dev/tty` using a standard keyboard reader to prompt the user directly.

---

## Coding Standards

- **Error Handling**: Use direct, explicit Go error checks. Propagate system errors to stderr for diagnostic transparency.
- **ASCII & Emojis**: All documentation and standard comments must use ASCII representation. No curly smart quotes, em-dashes, or non-ASCII typography. Emojis are permitted for shell outputs and user-facing terminal signals.
