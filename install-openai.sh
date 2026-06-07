#!/usr/bin/env bash

# YOLO Installation Script (OpenAI variant)
# Builds the Go binary and installs it to ~/.local/bin, then prints
# configuration guidance for users of the OpenAI API.

set -e

BIN_DIR="$HOME/.local/bin"

echo -e "\033[34m[YOLO Installer] Starting installation (OpenAI)...\033[0m"

# Check for Go
if ! command -v go &> /dev/null; then
    echo -e "\033[31mError: Go is not installed or not in PATH.\033[0m"
    exit 1
fi

# Ensure the target bin directory exists
mkdir -p "$BIN_DIR"

# Build and install the binary
echo -e "\033[34m[YOLO Installer] Compiling Go binary...\033[0m"
BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
BUILD_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
go build -ldflags "-X main.BuildDate=$BUILD_DATE -X main.BuildCommit=$BUILD_COMMIT" -o "$BIN_DIR/yolo" .

echo -e "\033[32m\n[YOLO Installer] Installed: $BIN_DIR/yolo\033[0m"

# Warn if the install directory is not on PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo -e "\033[33m\nWarning: $BIN_DIR is not in your PATH.\033[0m"
    echo -e "Add the following line to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
    echo -e "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

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
