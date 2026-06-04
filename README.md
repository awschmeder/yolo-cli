# YOLO (Pre-Flight Shell Command Helper)

`yolo` is a fast, lightweight pre-flight convenience tool written in Go that integrates into
Bash or Zsh. It passes each command through an OpenAI-compatible endpoint that flags ones that
look risky, and pauses those for operator approval.

Its main purpose is to combat operator fatigue and automation bias. When an AI agent or workflow
generates a high volume of shell commands -- the vast majority of which are harmless -- a human
asked to review every one quickly stops reading carefully and rubber-stamps them. `yolo` filters
out the routine commands automatically so the operator only has to focus their attention on the
small fraction that actually warrant a second look.

`yolo` uses LLM judgment rather than regex-based allow-lists because allow-lists are inadequate
for infrastructure automation in complex systems. Real-world operational commands are often
deeply chained and context-dependent -- for example, calls routed through jump hosts, `ssh`
tunnels, AWS SSM sessions (`aws ssm start-session`, `aws ssm send-command`), `kubectl exec`,
or nested `sh -c` wrappers. A pattern-matching allow-list either rejects these legitimate
commands outright or is widened until it no longer means anything. A language model can reason
about the actual effect of a chained command -- including what it does on a remote or external
system -- in a way a static regex cannot.

> **Not a security tool.** `yolo` is a convenience filter, not a security boundary or a
> defense-in-depth control. It relies on a best-effort LLM judgment and trusts the caller to
> cooperate. It does not, and is not intended to, stop a determined or adversarial process from
> running any command -- the bypass mechanism is keyless and easily reproduced by design. Do not
> rely on `yolo` to contain untrusted code, enforce policy, or protect against malicious actors.
> Use proper sandboxing, least-privilege accounts, and OS-level controls for those needs.

---

## Key Features

- **Shell Interception Hooks**: Uses lightweight native interception strategies (`DEBUG` traps in
  Bash, custom `accept-line` widgets in Zsh) to capture commands typed interactively.
- **Agent Exec Mode (`-c`)**: When invoked with `-c`, `yolo` is responsible for both checking
  and running the command -- the preferred form for AI agents and compound expressions.
- **Stateless Bypass Codes (`-x`)**: When a command is blocked, `yolo` prints a SHA-256-based
  6-character hash. Re-submitting with `-x <hash> -c '<cmd>'` bypasses the check after explicit
  user approval, with no local state or key files required.
- **Paranoid Mode (`--paranoid`)**: Restricts execution to verified read-only operations. Basic
  commands like `ls`, `pwd`, `cd`, and read-only git operations pass via a local fast-path;
  everything else is forwarded for policy inspection.
- **Skill/Agent File Scanning (`-s`)**: Scans skill definition files, AGENTS.md files, plugin
  manifests, and similar documents for embedded malicious instructions, prompt injection, data
  exfiltration payloads, and supply-chain attacks.
- **Dry-Run Mode (`--dry-run`)**: Performs the safety check without executing the command,
  printing the verdict and exiting cleanly. Useful for testing policy without side effects.
- **Interactive Prompt Option**: If `YOLO_INTERACTIVE=1` is set, the checker falls back to
  interactive confirmations (`Are you sure? y/N`) on `/dev/tty` instead of hash-based bypasses.
- **Conditional Activation**: The pre-flight check only runs when at least one trigger variable
  is set (controlled by `YOLO_ENVS`), so standard interactive developer sessions are unaffected.

---

## Installation

1. Clone or download this project to your machine.
2. Run the installer for your provider. Both build the binary, install the shell
   hooks to `~/.yolo/`, and print the configuration to add to your environment:
   ```bash
   # CBORG users (built-in default endpoint)
   ./install-cborg.sh

   # OpenAI users
   ./install-openai.sh
   ```
3. Add the setup hook to your shell profile.

### Bash Hook Integration
Add to `~/.bashrc` or `~/.bash_profile`:
```bash
source "$HOME/.yolo/shell/yolo-setup.bash"
```

### Zsh Hook Integration
Add to `~/.zshrc`:
```zsh
source "$HOME/.yolo/shell/yolo-setup.zsh"
```

---

## Integrating with a Coding Agent

To route a coding agent's shell commands through `yolo`, give the agent instructions telling it
to call `yolo -c '<command>'` instead of running commands directly. The file
[`INSTALL-AGENTS.md`](INSTALL-AGENTS.md) contains a ready-to-use block of those instructions.

1. Open [`INSTALL-AGENTS.md`](INSTALL-AGENTS.md) and copy its full contents.
2. Paste that content into the agent's rules / instructions file. The correct location depends on
   the agent:
   - **OpenAI Codex / generic agents**: the project's `AGENTS.md` file.
   - **Claude Code**: the project's `CLAUDE.md` file (or `~/.claude/CLAUDE.md` for all projects).
   - **Cursor**: a rule under `.cursor/rules/`.
   - **Other agents**: whatever global or project-level "rules" / "custom instructions" insertion
     point that agent reads at the start of a session.
3. Ensure the agent's environment sets one of the trigger variables in `YOLO_ENVS` (see
   [Activation Check](#1-activation-check)) so the shell hook is active in that session.

For instructions that apply to every project, paste the content into your global agent rules file
rather than a per-project one. After integration, the agent submits each command to `yolo` for a
pre-flight check, and you are prompted only for the commands the policy flags.

After the `yolo` agent instructions have been provided, the `yolo` command can be added as the sole auto-approved command.

---

## Toggling Interactive Mode

After sourcing the shell integration, use the built-in macros to toggle interactive yolo mode
on or off for the current session:

```bash
yolo_activate    # enable YOLO_INTERACTIVE=1 and prefix the prompt with [yolo]
yolo_deactivate  # disable YOLO_INTERACTIVE and restore the original prompt
```

---

## Configuration Variables

Set these in your shell profile or active session:

| Variable | Description |
|---|---|
| `YOLO_BASE_URL` | Base URL of the OpenAI-compatible endpoint (e.g., `https://api.openai.com/v1`). Falls back to `CBORG_BASE_URL`, then `https://api.cborg.lbl.gov`. |
| `YOLO_MODEL` | Model identifier to use for command safety checks (e.g., `gpt-oss-safeguard-120b`). Falls back to `CBORG_DEFAULT_MODEL`, then `cborg-safeguard-high`. |
| `YOLO_SKILL_MODEL` | Model identifier to use for skill/agent file scans (`-s`). Falls back to `YOLO_MODEL`, then `CBORG_DEFAULT_MODEL`, then `cborg-safeguard-high`. |
| `YOLO_API_KEY` | Bearer key for authorization. Falls back to `CBORG_API_KEY`. |
| `YOLO_INTERACTIVE` | Set to `1` to use interactive TTY prompts (`y/N`) instead of hash-based bypass codes. |
| `YOLO_PARANOID` | Set to `1` to enable paranoid mode (equivalent to the `--paranoid` flag). |
| `YOLO_ENVS` | Comma-separated list of environment variable **names** that activate the hook. If any named variable is non-empty, the hook runs. Defaults to `YOLO_TEST,ROO_ACTIVE,ZOO_ACTIVE,CLAUDE_CODE,OPENCODE`. |
| `YOLO_DEBUG` | Set to `1` to print debug output to stderr (LLM queries, verdicts, bypass resolution). |

---

## CLI Flags

```
yolo [flags] [command...]

Flags:
  -c <expr>     Command expression to check and execute. Preferred for all agent use,
                compound commands (pipes, chains, redirects), and heredoc invocations.
  -x <hash>     6-character hex bypass code to authorize a previously blocked command.
  -s <file>     Scan a skill/agent definition file for embedded malicious instructions.
                Exits 0 if safe, 1 if a threat is detected.
  --paranoid    Enable paranoid mode: only strictly read-only commands are allowed.
  -p            Shorthand for --paranoid.
  --dry-run     Check the command without executing it; prints the verdict and exits 0.
  -t            Shorthand for --dry-run.
```

---

## Mechanics & Workflow

### 1. Activation Check

The hook only runs when at least one variable named in `YOLO_ENVS` is non-empty. When no
trigger variable is set, commands pass through immediately with no overhead.

Default trigger variables:
- `YOLO_TEST`
- `ROO_ACTIVE`
- `ZOO_ACTIVE`
- `CLAUDE_CODE`
- `OPENCODE`

To activate for a custom agent context:
```bash
export YOLO_ENVS=MY_AGENT_VAR,ANOTHER_AGENT_VAR
```

### 2. Agent Exec Mode (`-c`)

When invoked with `-c`, `yolo` checks the command and, if approved, executes it directly in
the current shell. This is the required form for AI agents:

```bash
# Simple command
yolo -c 'rm -rf ./dist'

# Chained commands
yolo -c 'git add . && git commit -m "fix: update config"'

# Piped pipeline
yolo -c 'cat files.txt | xargs rm -f'

# Heredoc form (for commands containing single quotes)
yolo -c "$(cat <<'EOF'
find /tmp -name '*.log' -mtime +7 | xargs rm -f
EOF
)"
```

Do not run the command again after `yolo -c` -- `yolo` executes it after approval.

### 3. Bypass Codes (`-x`)

When a command is blocked, `yolo` exits with code `1` and prints:

```
[YOLO BLOCKED] Reason: <explanation>
ERROR: This command requires explicit approval from the user. Use an elicitation tool to prompt
the user for their approval, and if they confirm then re-execute the command using:
yolo -x 3fa8b1 -c '<cmd>'
```

After obtaining explicit user approval, re-run with the `-x` flag:

```bash
yolo -x 3fa8b1 -c 'rm -rf ./dist'
```

The bypass code is derived from the **exact command string**, so it authorizes only the command
that was actually reviewed. This is a drift check, not a security guarantee: the code is keyless
and reproducible, so its sole job is to catch the case where the command changes between approval
and execution. If the command is modified, the old code no longer matches and `yolo` prints a
new one, prompting a fresh approval:

```
ERROR: Invalid or mismatched YOLO hash code. If you have modified the command, the old code
is expired. Use an elicitation tool to prompt the user for their approval of this modified
command, and if they confirm then re-execute the command using: yolo -x df21ab -c '<new_cmd>'
```

### 4. Paranoid Mode

Enable with `--paranoid` / `-p` or `YOLO_PARANOID=1`. In this mode:

- A local fast-path immediately allows strictly read-only commands (`ls`, `pwd`, `cd`, `cat`,
  `grep`, `find`, `echo`, `head`, `tail`, `less`, `more`, `du`, `df`, `free`, `ps`, and
  read-only git subcommands: `status`, `diff`, `log`, `show`, `branch`) with no LLM call.
- Any command containing shell metacharacters (`>`, `<`, `|`, `;`, `&`, `$`, `` ` ``) bypasses
  the fast-path and is forwarded to the LLM with the paranoid policy prompt.
- Everything else is blocked.

### 5. Skill/Agent File Scanning (`-s`)

The `-s` flag scans a file for embedded malicious instructions before it is trusted or loaded
by an agent. It uses a specialized deep-analysis prompt targeting supply-chain and tool-poisoning
attacks that simpler classifiers miss.

```bash
yolo -s AGENTS.md
yolo -s path/to/skill.md
```

Threat categories detected:
- **Prompt injection / jailbreak**: Instructions to override or ignore system roles
- **Data exfiltration**: Attempts to extract credentials, API keys, or system prompts
- **Social engineering**: False authority claims, urgency framing, deceptive context-setting
- **Cyberattack facilitation**: Malware, exploit code, phishing templates
- **Supply-chain / tool poisoning**: Shell commands embedded in docs that transmit local data
  (e.g., `uname -a`, `~/.ssh/id_rsa`) to attacker-controlled endpoints via `curl`, `wget`, etc.
- **Obfuscation / evasion**: Encoding tricks, character substitution, language switching

Exit codes: `0` = safe, `1` = threat detected or scan error.

Use `YOLO_SKILL_MODEL` to specify a different model for file scans than for command checks.

### 6. Dry-Run Mode (`--dry-run` / `-t`)

Performs the safety check without executing the command. Prints the verdict to stderr and exits
with code `0` regardless of the result. Useful for testing whether a command would be allowed
or blocked without any side effects:

```bash
yolo --dry-run -c 'rm -rf /'
# stderr: [YOLO DRY-RUN] ALLOW: rm -rf /   (or BLOCK, depending on policy)
# exit: 0
```

---

## Project Layout

```
.
+-- main.go                # Go CLI: safety check, bypass verification, exec mode, skill scan
+-- main_test.go           # Unit tests for hash, bypass, and fast-path logic
+-- go.mod                 # Go module definition (no external dependencies)
+-- install-cborg.sh       # Builds binary, installs to ~/.yolo/, prints CBORG config
+-- install-openai.sh      # Builds binary, installs to ~/.yolo/, prints OpenAI config
+-- AGENTS.md              # Instructions for AI agents using this project
+-- INSTALL-AGENTS.md      # Copyable agent instructions to paste into AGENTS.md / CLAUDE.md
+-- shell/
    +-- yolo-setup.bash    # Bash DEBUG trap hook
    +-- yolo-setup.zsh     # Zsh accept-line widget hook
```
