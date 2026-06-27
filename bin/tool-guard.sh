#!/usr/bin/env bash
# tool-guard.sh — PreToolUse hook that DENIES suboptimal tool usage
# Reads JSON from stdin (tool_name + tool_input) and outputs a deny message
# with agent-optimal alternatives.
#
# Agent-optimal principle: only the agent reads output, so use tools designed
# for LLM consumption (rtk subcommands) over tools designed for human terminals.
# Never cd — harnesses have workdir/cwd parameters. Use absolute paths.
#
# Install in .claude/settings.json like:
#   "PreToolUse": [{
#     "matcher": "Bash|Read",
#     "hooks": [{
#       "type": "command",
#       "command": "/Users/jwalinshah/bin/tool-guard.sh",
#       "timeout": 3,
#       "statusMessage": "Checking tool choice..."
#     }]
#   }]
#
# Returns:
#   exit 0 + systemMessage → BLOCKED (agent receives the message)
#   exit 0 + no output     → ALLOWED (pass through)

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // .tool_input.file_path // ""')

# Skip non-Bash tools
[ "$TOOL" != "Bash" ] && exit 0

# Extract first command word (bash builtin only)
read -r RAW _ <<< "$CMD"

# Scan the FULL command for banned tools anywhere (after &&, ||, ;, |)
# This catches compound commands like `cd foo && ls -la`
BANNED_TOOLS=""
for BANNED in cat ls grep find rm; do
  # Match the banned tool as a standalone word (not substring of another word)
  if echo "$CMD" | grep -Eq "(^|\||\|\||\&\&|;|\|&)\s*${BANNED}(\s|$|&&|\|\||;|\|)"; then
    BANNED_TOOLS="$BANNED_TOOLS $BANNED"
  fi
done

SUGGESTION=""

case "$RAW" in
  cd)
    # Strip leading whitespace and get target path
    CD_TARGET="${CMD#"${CMD%%[![:space:]]*}"}"
    CD_TARGET="${CD_TARGET#cd }"
    SUGGESTION="Never \`cd\`. Use absolute paths or the harness workdir/cwd parameter instead."
    ;;
  awk)
    SUGGESTION="Use \`jq\` for structured data or \`rtk grep\` for text instead of awk."
    ;;
  bat)
    SUGGESTION="Use \`rtk read\` instead of bat — intelligent filtering, token-optimized."
    ;;
  cat)
    SUGGESTION="Use \`rtk read\` instead of cat — reads the relevant parts, not the whole file."
    ;;
  ls)
    SUGGESTION="Use \`rtk ls\` instead of ls — token-optimized. Or \`rtk tree\` for tree view."
    ;;
  find)
    SUGGESTION="Use \`fd\` or \`rtk find\` instead of find — faster, .gitignore-aware."
    ;;
  grep)
    SUGGESTION="Use \`rtk grep\` instead of grep — wraps rg for speed, compresses output."
    ;;
  du)
    if echo "$CMD" | grep -Eq '(^|\||;\s*)\s*du\s+-s'; then
      # du -sh or du -s — allow, already efficient
      :
    else
      SUGGESTION="Use \`du -s\` instead of bare du — one line, raw bytes (parseable)."
    fi
    ;;
  curl)
    SUGGESTION="Use the WebFetch tool instead of curl — strips HTML to markdown, saves tokens."
    ;;
  gh)
    SUGGESTION="Use \`gh-axi\` instead of gh — token-optimized GitHub CLI wrapper."
    ;;
  sed)
    SUGGESTION="Use \`fastedit edit\` instead of sed — AST-aware, symbol-based, no fragile line numbers."
    ;;
  rm)
    SUGGESTION="\`rm\` needs the captain's permission. Tell the captain what you want to delete and why, then retry."
    ;;
  wc)
    SUGGESTION="Use \`rtk wc\` instead of wc — strips paths and padding, compresses output."
    ;;
  python3|python)
    if echo "$CMD" | grep -Eq '\s+-c\s'; then
      SUGGESTION="Don't write ad-hoc Python scripts. Use \`jq\` for JSON, \`rtk grep\` or \`llm-tldr search\` for text, \`fastedit\` for edits."
    fi
    ;;
  head|tail)
    SUGGESTION="Use \`rtk read\` instead of $RAW — reads relevant slices with intelligent filtering."
    ;;
  git)
    case "$CMD" in
      *"git status"*) SUGGESTION="Use \`rtk git status\` — compact, 1 line instead of 20." ;;
      *"git diff"*)   SUGGESTION="Use \`rtk git diff\` or \`rtk diff\` — only changed lines." ;;
      *"git log"*)    SUGGESTION="Use \`rtk git log\` — hashes + messages only." ;;
    esac
    ;;
  echo)
    SUGGESTION="Don't use \`echo\` for file creation or debug output. Use \`fastedit\` for files, or just state what you're doing directly."
    ;;
  export)
    SUGGESTION="\`export\` can leak secrets. Ask the captain to set env vars instead."
    ;;
  pip)
    SUGGESTION="Use \`uv pip\` instead of pip — faster, simpler."
    ;;
  pytest)
    SUGGESTION="Use \`rtk pytest\` instead of pytest — compact output, failures only."
    ;;
  security)
    SUGGESTION="\`security\` accesses the macOS Keychain. Ask the captain for approval first."
    ;;
  sudo)
    SUGGESTION="\`sudo\` is blocked. Ask the captain to handle this manually."
    ;;
  diff)
    SUGGESTION="Use \`rtk diff\` instead of diff — only changed lines, compresses output."
    ;;
esac

# If a specific tool was blocked but the agent used a compound command,
# also mention any additional banned tools found in the chain
if [ -n "$SUGGESTION" ] && [ -n "$BANNED_TOOLS" ]; then
  SUGGESTION="$SUGGESTION (Also found banned tools in the chain: $BANNED_TOOLS)"
fi

if [ -n "$SUGGESTION" ]; then
  echo "{\"systemMessage\": \"❌ BLOCKED: $SUGGESTION\"}"
  exit 0
fi
