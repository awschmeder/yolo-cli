#!/usr/bin/env bash

# YOLO Installation Script (OpenAI variant)
# Builds the Go binary, installs the CLI and shell hooks to ~/.yolo/, and prints
# configuration guidance for users of the OpenAI API.

set -e

# Define installation paths
INSTALL_DIR="$HOME/.yolo"
BIN_DIR="$INSTALL_DIR/bin"
SHELL_DIR="$INSTALL_DIR/shell"

echo -e "\033[34m[YOLO Installer] Starting installation (OpenAI)...\033[0m"

# 1. Check dependencies
if ! command -v go &> /dev/null; then
    echo -e "\033[31mError: Go is not installed or not in PATH.\033[0m"
    exit 1
fi

# 2. Create directory structures
mkdir -p "$BIN_DIR"
mkdir -p "$SHELL_DIR"

# 3. Build Go binary
echo -e "\033[34m[YOLO Installer] Compiling Go utility...\033[0m"
go build -o "$BIN_DIR/yolo" main.go

# 4. Copy Shell Hooks
echo -e "\033[34m[YOLO Installer] Setting up shell hooks...\033[0m"
cp -f shell/yolo-setup.bash "$SHELL_DIR/yolo-setup.bash"
cp -f shell/yolo-setup.zsh "$SHELL_DIR/yolo-setup.zsh"

# 5. Output installation confirmation and usage details
echo -e "\033[32m\n[YOLO Installer] Installation completed successfully!\033[0m"
echo -e "Files installed to: $INSTALL_DIR\n"

echo -e "\033[33mOptional EXPERIMENTAL interactive terminal hooks (most users should skip these;\033[0m"
echo -e "\033[33magents call 'yolo -c' and do not need them). To enable, append to your profile:\033[0m"
echo -e "\n\033[1mFor Bash (~/.bashrc or ~/.bash_profile):\033[0m"
echo -e "  source \"\$HOME/.yolo/shell/yolo-setup.bash\""

echo -e "\n\033[1mFor Zsh (~/.zshrc):\033[0m"
echo -e "  source \"\$HOME/.yolo/shell/yolo-setup.zsh\""

# The built-in default endpoint is CBORG; OpenAI users must set these explicitly.
# OpenAI does not offer gpt-oss-safeguard, so a general-purpose model is used instead.
echo -e "\n\033[33mOpenAI configuration (required; the built-in default endpoint is CBORG):\033[0m"
echo -e "  export YOLO_BASE_URL=\"https://api.openai.com/v1\""
echo -e "  export YOLO_MODEL=\"gpt-5.4-mini\""
echo -e "  export YOLO_API_KEY=\"your_openai_key_here\""
echo -e "  export YOLO_DEBUG=1         # Optional: print debugging info"
echo -e "  export YOLO_PARANOID=1      # Optional: apply strict allow-read-only commands"
echo -e "  export YOLO_INTERACTIVE=1   # Optional: enable interactive (y/N) prompts on tty"
echo -e "\nTo activate the checker, ensure at least one of these trigger environment variables is set:"
echo -e "  YOLO_TEST, ROO_ACTIVE, ZOO_ACTIVE, CLAUDE_CODE, or OPENCODE"
echo ""
