#!/usr/bin/env bash
# install-azd-ext.sh — Build and install a local azd extension + core azd binary,
# and configure environment variables for local agent template development.
#
# Usage:
#   install-azd-ext.sh                    # builds azure.ai.agents extension only
#   install-azd-ext.sh --core             # also builds and installs core azd
#   install-azd-ext.sh <extension-dir>    # builds a specific extension directory
#
# Environment variables set globally (in shell profile):
#   AZD_AGENT_TEMPLATES_PATH  — points to local foundry-samples templates.json
#   AZD_AGENT_CLONE_SKILLS    — enables Copilot skills download during init

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
if [[ -z "$REPO_ROOT" ]]; then
  echo "ERROR: not inside a git repo" >&2
  exit 1
fi

AZD_DIR="$REPO_ROOT/cli/azd"
DEFAULT_EXT="azure.ai.agents"
BUILD_CORE=false
EXT_DIR=""

for arg in "$@"; do
  case "$arg" in
    --core) BUILD_CORE=true ;;
    *) EXT_DIR="$arg" ;;
  esac
done

if [[ -z "$EXT_DIR" ]]; then
  EXT_DIR="$AZD_DIR/extensions/$DEFAULT_EXT"
fi

# Resolve extension ID from directory name
EXT_ID="$(basename "$EXT_DIR")"
# Convention: dots → dashes for binary name
EXT_BIN_NAME="$(echo "$EXT_ID" | tr '.' '-')-darwin-arm64"
INSTALL_DIR="$HOME/.azd/extensions/$EXT_ID"

echo "==> Extension: $EXT_ID"
echo "    Source:    $EXT_DIR"
echo "    Install:   $INSTALL_DIR/$EXT_BIN_NAME"

# Step 1: Ensure extension is registered (install from registry if needed)
if [[ ! -d "$INSTALL_DIR" ]]; then
  echo "==> Extension not installed, registering via azd extension install..."
  azd extension install "$EXT_ID"
fi

# Step 2: Build core azd if requested
if $BUILD_CORE; then
  echo "==> Building core azd..."
  (cd "$AZD_DIR" && go build)
  cp "$AZD_DIR/azd" /opt/homebrew/bin/azd
  xattr -d com.apple.quarantine /opt/homebrew/bin/azd 2>/dev/null || true
  codesign -s - -f /opt/homebrew/bin/azd 2>/dev/null || true
  echo "    Installed core azd to /opt/homebrew/bin/azd"
fi

# Step 3: Build the extension
echo "==> Building extension..."
(cd "$EXT_DIR" && GOOS=darwin GOARCH=arm64 go build -o "bin/$EXT_BIN_NAME" .)

# Step 4: Install the extension binary
cp "$EXT_DIR/bin/$EXT_BIN_NAME" "$INSTALL_DIR/$EXT_BIN_NAME"
chmod +x "$INSTALL_DIR/$EXT_BIN_NAME"

# Step 5: Set environment variables globally
TEMPLATES_PATH="$HOME/working/foundry-samples/templates.json"
SHELL_PROFILE=""

if [[ -f "$HOME/.zshrc" ]]; then
  SHELL_PROFILE="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
  SHELL_PROFILE="$HOME/.bashrc"
elif [[ -f "$HOME/.bash_profile" ]]; then
  SHELL_PROFILE="$HOME/.bash_profile"
fi

if [[ -n "$SHELL_PROFILE" ]]; then
  CHANGED=false

  if ! grep -q 'AZD_AGENT_TEMPLATES_PATH' "$SHELL_PROFILE" 2>/dev/null; then
    echo "" >> "$SHELL_PROFILE"
    echo "# azd ai agent local development" >> "$SHELL_PROFILE"
    echo "export AZD_AGENT_TEMPLATES_PATH=\"$TEMPLATES_PATH\"" >> "$SHELL_PROFILE"
    CHANGED=true
  fi

  if ! grep -q 'AZD_AGENT_CLONE_SKILLS' "$SHELL_PROFILE" 2>/dev/null; then
    echo "export AZD_AGENT_CLONE_SKILLS=true" >> "$SHELL_PROFILE"
    CHANGED=true
  fi

  if $CHANGED; then
    echo "==> Added env vars to $SHELL_PROFILE"
    echo "    Run: source $SHELL_PROFILE"
  else
    echo "==> Env vars already in $SHELL_PROFILE"
  fi
fi

# Also export for current session
export AZD_AGENT_TEMPLATES_PATH="$TEMPLATES_PATH"
export AZD_AGENT_CLONE_SKILLS=true

echo "==> Done! Extension $EXT_ID installed from local build."
