#!/usr/bin/env bash

# YOLO Installation Script (CBORG variant)
# Builds the Go binary and installs it to ~/.local/bin, then prints
# configuration guidance for users of the CBORG OpenAI-compatible endpoint.

set -e

BIN_DIR="$HOME/.local/bin"

echo -e "\033[34m[YOLO Installer] Starting installation (CBORG)...\033[0m"

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
