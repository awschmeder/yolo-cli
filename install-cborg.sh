#!/usr/bin/env bash

# YOLO Installation Script (CBORG variant)
# Builds the Go binary, installs the CLI and shell hooks to ~/.yolo/, and prints
# configuration guidance for users of the CBORG OpenAI-compatible endpoint.

set -e

# Define installation paths
INSTALL_DIR="$HOME/.yolo"
BIN_DIR="$INSTALL_DIR/bin"
SHELL_DIR="$INSTALL_DIR/shell"

echo -e "\033[34m[YOLO Installer] Starting installation (CBORG)...\033[0m"

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

echo -e "\n\033[33mCBORG configuration (these are the built-in defaults; set only to override):\033[0m"
echo -e "  export YOLO_BASE_URL=\"https://api.cborg.lbl.gov\""
echo -e "  export YOLO_MODEL=\"cborg-safeguard-high\""
echo -e "  export YOLO_API_KEY=\"your_cborg_key_here\""
echo -e "  export YOLO_DEBUG=1         # Optional: print debugging info"
echo -e "  export YOLO_PARANOID=1      # Optional: apply strict allow-read-only commands"
echo -e "  export YOLO_INTERACTIVE=1   # Optional: enable interactive (y/N) prompts on tty"
echo -e "\nTo activate the checker, ensure at least one of these trigger environment variables is set:"
echo -e "  YOLO_TEST, ROO_ACTIVE, ZOO_ACTIVE, CLAUDE_CODE, or OPENCODE"
echo ""
