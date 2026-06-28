#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.mode silent
# @raycast.packageName Agent Launchers

# Optional parameters:
# @raycast.currentDirectoryPath ~
# @raycast.title ccp
# @raycast.subtitle Claude Code - Pioneer gateway
# @raycast.icon rocket
# @raycast.keyword claude
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/_ghostty-tab.sh" ~/bin/ccp
