#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.mode silent
# @raycast.packageName Agent Launchers

# Optional parameters:
# @raycast.currentDirectoryPath ~
# @raycast.title cx
# @raycast.subtitle Codex CLI - macOS
# @raycast.icon keyboard
# @raycast.keyword codex
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/_ghostty-tab.sh" ~/.local/bin/cx
