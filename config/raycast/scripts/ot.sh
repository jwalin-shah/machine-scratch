#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.mode silent
# @raycast.packageName Agent Launchers

# Optional parameters:
# @raycast.currentDirectoryPath ~
# @raycast.title ot
# @raycast.subtitle OpenCode - TokenRouter
# @raycast.icon large-blue-circle
# @raycast.keyword opencode
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/_ghostty-tab.sh" ~/.local/bin/ot
