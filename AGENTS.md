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

## Versioning

The version is defined in [`main.go`](main.go) as the `Version` constant and exposed via `yolo --version` / `yolo -v`.

**Version Increment Policy** (triggered on `sendit`):
- **Micro version** (e.g., `0.1.0` -> `0.1.1`): For small updates, bug fixes, documentation improvements, prompt refinements, or non-breaking enhancements
- **Minor version** (e.g., `0.1.0` -> `0.2.0`): For significant new features, architectural changes, new flags, or changes to safety policy
- **Major version** (e.g., `0.1.0` -> `1.0.0`): Reserved for breaking changes, API redesigns, or major stability milestones

When committing via `sendit`, increment the version in [`main.go`](main.go) as part of the commit if the changes justify it. Start with micro increments; reserve minor/major bumps for more substantial work.

---

## Coding Standards

- **Error Handling**: Use direct, explicit Go error checks. Propagate system errors to stderr for diagnostic transparency.
- **ASCII & Emojis**: All documentation and standard comments must use ASCII representation. No curly smart quotes, em-dashes, or non-ASCII typography. Emojis are permitted for shell outputs and user-facing terminal signals.
