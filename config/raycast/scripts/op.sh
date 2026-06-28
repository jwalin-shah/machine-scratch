#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.mode silent
# @raycast.packageName Agent Launchers

# Optional parameters:
# @raycast.currentDirectoryPath ~
# @raycast.title op
# @raycast.subtitle OpenCode - Pioneer AI
# @raycast.icon large-purple-circle
# @raycast.keyword opencode
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/_ghostty-tab.sh" ~/.local/bin/op
