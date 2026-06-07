# YOLO (Pre-flight Command Checker)

![yolo](assets/yolo-animated.gif)

`yolo` is designed to combat operator fatigue and automation bias: when an AI agent generates a
high volume of mostly-harmless commands, a human reviewing every one stops reading carefully and
rubber-stamps them.

`yolo` auto-approves and executes routine commands, but blocks the significant ones such as `rm -rf` and `git push --force` with a prompt that triggers the coding agent to elicit human approval. In `--paranoid` mode it only allows read-only commands such as `git log`, `ls`, etc.

## Table of Contents

- [How it works](#how-it-works)
- [Quick Start](#quick-start)
- [Integrating with a Coding Agent](#integrating-with-a-coding-agent)
- [CLI Flags](#cli-flags)
- [Configuration](#configuration)
- [Command Modes & Examples](#command-modes--examples)
  - [Exec Mode (`-c`)](#exec-mode--c)
  - [Heredoc / Stdin Mode](#heredoc--stdin-mode)
  - [Remote Script Installation (`curl | yolo`)](#remote-script-installation-curl--yolo)
  - [Complex Script Analysis](#complex-script-analysis)
  - [Package Installation Safety](#package-installation-safety)
  - [Bypass Codes (`-x`)](#bypass-codes--x)
  - [Paranoid Mode (`--paranoid` / `-p`)](#paranoid-mode---paranoid---p)
  - [Skill/Agent File Scanning (`-s`)](#skillagent-file-scanning--s)
  - [Dry-Run Mode (`--dry-run` / `-t`)](#dry-run-mode---dry-run---t)
- [Interactive Terminal Activation (Experimental)](#interactive-terminal-activation-experimental)
  - [Activation](#activation)

---

## How it works

`yolo` is a Go CLI tool for Bash and Zsh that routes each shell command through an
OpenAI-compatible LLM endpoint for a pre-flight approve/deny check. The preferred model is `gpt-oss-safeguard-120b` or `-20b` variant, but falls back to `gpt-5.4-mini` on OpenAI API which does not provide this model.

By using an LLM-based reasoning model `yolo` can understand the implications of deeply chained and
context-dependent commands needed for infrastructure automation (jump hosts, `ssh` tunnels,
`aws ssm` sessions, `kubectl exec`, redirects, piped commands, etc.).

**Not a security tool:** `yolo` is a convenience filter, not a security boundary. It relies on
best-effort LLM judgment, trusts the caller to cooperate, and uses a keyless, easily-reproduced
bypass code by design. Do not rely on it to contain untrusted code or stop a malicious actor. Use
sandboxing, least-privilege accounts, and OS-level controls for those needs.

---

## Quick Start

1. Clone this project.
2. Run the installer for your provider. Each builds the binary, installs the shell hooks to
   `~/.yolo/`, and prints the config to add to your environment:
   ```bash
   ./install-cborg.sh    # LBNL CBORG users (built-in default endpoint)
   ./install-openai.sh   # OpenAI users
   ```
Agents route commands through `yolo -c '<command>'`, so no shell profile changes are required.

---

## Integrating with a Coding Agent

To route an agent's commands through `yolo`, tell it to call `yolo -c '<command>'` instead of
running commands directly. [`INSTALL-AGENTS.md`](INSTALL-AGENTS.md) contains a ready-to-paste
instruction block.

1. Copy the full contents of [`INSTALL-AGENTS.md`](INSTALL-AGENTS.md) into your agent global instructions and/or project instructions.

 - **OpenAI Codex / generic agents**: project `AGENTS.md`
 - **Claude Code**: project `CLAUDE.md` (or `~/.claude/CLAUDE.md` for all projects)
 - **Cursor**: a rule under `.cursor/rules/`
 - **Other agents**: that agent's global or project-level rules insertion point

Once integrated, `yolo` can be the sole auto-approved command -- you are prompted only for the
commands the policy flags. For all projects, paste into your global agent rules file instead.

---

## CLI Flags

```
yolo [flags]

  -c <expr>     Check and execute a command expression. Preferred for all agent use and
                compound commands (pipes, chains, redirects).
  -x <hash>     6-char hex bypass code to authorize a previously blocked command.
  -s <file>     Scan a skill/agent definition file for embedded malicious instructions.
  --paranoid    Allow only strictly read-only commands. Shorthand: -p
  --dry-run     Check without executing; print verdict to stderr, always exit 0. Shorthand: -t
  --check       Check without executing; exit 0 (allow) or 1 (block), no output on allow.
                Used by shell hook integrations. Shorthand: -n
  -d <secs>     Delay N seconds before submitting the command for safety check. Supports
                fractions (e.g. 0.5). Skipped on -x bypass. Shorthand for --delay.
  --delay <N>   Same as -d.
  --version     Print version and exit.

Stdin / pipe mode (yolo reads the command or script from stdin when stdin is not a terminal):
  yolo << EOF          # heredoc: check and exec a command block
  <command>
  EOF

  curl <url> | yolo    # pipe: check and exec a remote install script
```

---

## Configuration

Set these in your shell profile or session:

| Variable | Description |
|---|---|
| `YOLO_BASE_URL` | OpenAI-compatible endpoint base URL. Falls back to `CBORG_BASE_URL`, then `https://api.cborg.lbl.gov`. |
| `YOLO_MODEL` | Model for command safety checks. Falls back to `CBORG_DEFAULT_MODEL`, then `cborg-safeguard-high`. |
| `YOLO_SKILL_MODEL` | Model for skill/agent file scans (`-s`). Falls back to `YOLO_MODEL`, then the above chain. |
| `YOLO_API_KEY` | Bearer key for authorization. Falls back to `CBORG_API_KEY`. |
| `YOLO_INTERACTIVE` | `1` to use interactive TTY prompts (`y/N`) instead of hash bypass codes. |
| `YOLO_PARANOID` | `1` to enable paranoid mode (same as `--paranoid`). |
| `YOLO_ENVS` | Comma-separated env var **names** that activate the hook. Defaults to `YOLO_TEST,ROO_ACTIVE,ZOO_ACTIVE,CLAUDE_CODE,OPENCODE`. |
| `YOLO_DEBUG` | `1` to print debug output to stderr. |
| `YOLO_SLEEP` | Seconds to delay before the safety check. Supports fractions (e.g. `0.5`). Non-numeric or negative values are an error (fail closed). Overridden by `--delay`/`-d`. Skipped on `-x` bypass. |

---

## Command Modes & Examples

### Exec Mode (`-c`)

`yolo -c` checks the command and, if approved, runs it directly in the current shell. This is the
required form for agents and any compound expression. Do not run the command again afterward.

```bash
yolo -c 'rm -rf ./dist'
yolo -c 'git add . && git commit -m "fix: update config"'
yolo -c 'cat files.txt | xargs rm -f'

# Multi-line commands: pass as a single quoted string
yolo -c 'find /tmp -name "*.log" -mtime +7 | xargs rm -f'
```

### Heredoc / Stdin Mode

When stdin is not an interactive terminal, `yolo` reads the command body from stdin and, if
approved, executes it. This mirrors `sh` behavior: `sh << EOF`. Multi-line bodies are supported;
the entire block is submitted to the LLM as a single expression.

```bash
# Heredoc -- check and exec
yolo << EOF
find /tmp -name "*.log" -mtime +7 | xargs rm -f
EOF

# Herestring (bash/zsh) -- check and exec
yolo <<< 'rm -rf ./dist'

# Pipe -- check and exec
echo 'git status' | yolo

# Gate-only (shell hook use): check, exit 0/1, do not exec
yolo --check << EOF
find /tmp -name "*.log" -mtime +7 | xargs rm -f
EOF
```

### Remote Script Installation (`curl | yolo`)

`yolo` is a drop-in replacement for `bash` in the common `curl <url> | bash` install pattern.
Pipe the remote script into `yolo` instead -- the full script body is submitted to the LLM for
a safety check before any of it executes. If it looks fine, `yolo` runs it. If it looks
problematic, `yolo` blocks it and prints the reason.

```bash
# Instead of:
curl -fsSL https://example.com/install.sh | bash

# Use:
curl -fsSL https://example.com/install.sh | yolo
```

The entire script is evaluated as a single unit, so multi-step scripts (those that set variables,
define functions, and then call them) are analyzed in full context.

As with all `yolo` usage, this is best-effort -- a guard against accidentally running something
obviously dangerous, not a vulnerability scanner or security guarantee.

### Complex Script Analysis

When a multi-line script or compound pipeline is submitted, `yolo` traces data flow across all
steps rather than evaluating each command in isolation. A pipeline that collects system data in
one step and transmits it to a remote host in a later step is flagged even if no individual
command looks dangerous.

When executing a local script file with a high-impact name (e.g., `bash deploy.sh`,
`./migrate.sh`), `yolo` may block and suggest re-submitting the script contents via heredoc for
full inspection:

```bash
# If 'yolo -c './deploy.sh'' is blocked, re-submit contents for analysis:
yolo << EOF
$(cat ./deploy.sh)
EOF
```

This lets agents resolve the block automatically without user interaction.

> **Note:** `yolo` does not automatically block execution of scripts with harmless-sounding
> filenames (e.g., `check.sh`, `build.py`, `lint.sh`). A script named `check.sh` that contains
> destructive operations will pass this heuristic unless its contents are submitted for inline
> analysis. [`--paranoid` mode](#paranoid-mode---paranoid---p) uses best-effort blocking of
> opaque script execution, but this is LLM-evaluated and not a hard guarantee.

> **Warning:** `yolo` evaluates shell syntax and command semantics, but it cannot fully reason
> about the consequences of executing compiled binaries, native extensions, or obfuscated
> payloads. It does not perform CVE scanning, supply-chain provenance checks, or signature
> verification. It is not a substitute for dependency auditing tools (e.g., `npm audit`,
> `pip audit`, `trivy`) or a secure software supply-chain process.

### Package Installation Safety

Package installation commands are high-value supply-chain attack vectors. `yolo` applies stricter
scrutiny to `npm install`, `pip install`, `apt install`, and similar commands.

Bare installs without explicit package specifiers are blocked. When blocked, `yolo` includes
constructive suggestions in the BLOCK message so agents can self-correct and retry:

```bash
# Blocked -- bare install is opaque:
npm install

# Compliant -- explicit specifier + audit:
npm install lodash && npm audit
```

```bash
# Blocked -- bare npm install (lifecycle scripts execute arbitrary code):
npm install

# Compliant -- suppress lifecycle scripts, then audit:
npm install lodash --ignore-scripts && npm audit
# Or use a lock file:
npm ci --ignore-scripts && npm audit
```

```bash
# Blocked -- bare pip install (setup.py and .pth files execute arbitrary code):
pip install

# Compliant -- hash-verified lock file, no build isolation, then audit:
pip install --require-hashes --no-build-isolation -r requirements.txt && pip audit
```

> **Note:** Both `npm install` and `pip install` execute arbitrary code on the host at install
> time -- npm via `preinstall`/`postinstall` lifecycle scripts, pip via `.pth` files and
> `setup.py`. Use `--ignore-scripts` (npm) and `--require-hashes` (pip) for higher-assurance
> environments.

### Bypass Codes (`-x`)

A blocked command exits `1` and prints a SHA-256-derived 6-char hash:

```
[YOLO BLOCKED] Reason: <explanation>
ERROR: ...re-execute using: yolo -x 3fa8b1 -c '<cmd>'
```

After explicit user approval, re-run with `-x`:

```bash
yolo -x 3fa8b1 -c 'rm -rf ./dist'
```

The code is derived from the exact command string, so it authorizes only what was reviewed. This
is a drift check, not a security guarantee -- the code is keyless and reproducible. If the command
changes, the old code no longer matches and `yolo` prints a new one, prompting fresh approval.

### Paranoid Mode (`--paranoid` / `-p`)

Restricts execution to verified read-only operations.

- A local fast-path allows read-only commands (`ls`, `pwd`, `cd`, `cat`, `grep`, `find`, `echo`,
  `head`, `tail`, `less`, `more`, `du`, `df`, `free`, `ps`, and read-only git subcommands:
  `status`, `diff`, `log`, `show`, `branch`) with no LLM call.
- Commands with shell metacharacters (`>`, `<`, `|`, `;`, `&`, `$`, `` ` ``) are forwarded to the
  LLM under the paranoid policy.
- Everything else is blocked.
- Opaque script execution is blocked regardless of filename -- any script file whose contents
  are not submitted inline (e.g., `bash deploy.sh`, `./run.sh`, `python migrate.py`) will be
  rejected. The LLM will suggest re-submitting contents via heredoc for inline analysis.
- If inline script contents are unusually long or use highly complex logic, paranoid mode treats
  this as elevated risk: the LLM may be unable to fully trace all execution paths, and incomplete
  analysis of a long script is itself a safety hazard. Paranoid mode will attempt to block such scripts with a
  recommendation to review manually.

### Skill/Agent File Scanning (`-s`)

Scans a file for embedded malicious instructions before an agent trusts or loads it, using a
deep-analysis prompt for supply-chain and tool-poisoning attacks. Exit `0` = safe, `1` = threat
or scan error. Use `YOLO_SKILL_MODEL` to scan with a different model.

```bash
yolo -s AGENTS.md
```

Detects: prompt injection / jailbreak, data exfiltration, social engineering, cyberattack
facilitation, supply-chain / tool poisoning, and obfuscation / evasion.

### Dry-Run Mode (`--dry-run` / `-t`)

Performs the safety check without executing. Prints the verdict to stderr and exits `0`
regardless of the result.

```bash
yolo --dry-run -c 'rm -rf /'
# stderr: [YOLO DRY-RUN] ALLOW: rm -rf /   (or BLOCK)
# exit: 0
```

---

## Interactive Terminal Activation (Experimental)

> **Experimental feature -- not recommended.** The interactive shell hooks are experimental and
> intended only for manual terminal testing. Agents route commands through `yolo -c '<command>'`
> and do not need this. Most users should skip it.

Installed by sourcing the shell integration (zsh or bash) from your shell profile:

```bash
# ~/.bashrc or ~/.bash_profile
source "$HOME/.yolo/shell/yolo-setup.bash"

# ~/.zshrc
source "$HOME/.yolo/shell/yolo-setup.zsh"
```

### Activation

The hook runs only when at least one variable named in `YOLO_ENVS` is non-empty; otherwise
commands pass through with no overhead. Defaults: `YOLO_TEST`, `ROO_ACTIVE`, `ZOO_ACTIVE`,
`CLAUDE_CODE`, `OPENCODE`. To activate for a custom context:

```bash
export YOLO_ENVS=MY_AGENT_VAR,ANOTHER_AGENT_VAR
```

Interactively typed commands are captured via native hooks (`DEBUG` traps in Bash, a custom
`accept-line` widget in Zsh).

`yolo` mode can be activated manually:

```bash
yolo_activate    # enable YOLO_INTERACTIVE=1, prefix prompt with [yolo]
yolo_deactivate  # disable it and restore the prompt
```

Use with YOLO_INTERACTIVE=1 to elicit y/N approval from /dev/tty. This mode is primarily for testing but also works with the ZooCode VSCode Extension when terminal integration is disabled (VSCode terminal injection).

