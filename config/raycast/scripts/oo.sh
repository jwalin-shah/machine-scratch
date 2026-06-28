#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.mode silent
# @raycast.packageName Agent Launchers

# Optional parameters:
# @raycast.currentDirectoryPath ~
# @raycast.title oo
# @raycast.subtitle OpenCode - ChatGPT Plus (GPT 5.5)
# @raycast.icon large-green-circle
# @raycast.keyword opencode
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/_ghostty-tab.sh" ~/.local/bin/oo
