#!/usr/bin/env bash
# tool-guard.sh — Claude Code PreToolUse hook that enforces config/tool-policy.json.
#
# Source of truth: <repo>/config/tool-policy.json
# Same policy drives OpenCode (config/opencode/opencode.json `permission` block
# and config/opencode/plugins/tool-guard/index.js). When the JSON changes,
# both adapters change with it — no per-adapter hardcoded lists.
#
# Protocol (Claude Code hooks):
#   stdin: PreToolUse event JSON (tool_name, tool_input, …)
#   stdout (allow, silent):  no output, exit 0
#   stdout (deny):           {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#                                "permissionDecision":"deny",
#                                "permissionDecisionReason":"<msg>"}}
#                            exit 0
#   Exit 2 is reserved for unexpected errors (also blocks, with stderr shown).
#
# Tool gating:
#   Bash       → match against tool-policy bash_allow / bash_deny / bash_ask
#   Read|Grep|Glob|List → blanket deny per native_opencode_deny (use rtk via Bash)
#   Write|StrReplace|Delete|Edit → deny per native_write_deny (use fastedit via Shell)
#   Shell → same policy path as Bash (Cursor harness)

set -euo pipefail

# ---------- resolve policy file ----------
SELF="${BASH_SOURCE[0]}"
# Follow symlink (the installer links ~/bin/tool-guard.sh → repo/bin/tool-guard.sh)
while [ -L "$SELF" ]; do
  TARGET="$(readlink "$SELF")"
  case "$TARGET" in
    /*) SELF="$TARGET" ;;
    *)  SELF="$(cd "$(dirname "$SELF")" && pwd)/$TARGET" ;;
  esac
done
REPO_ROOT="$(cd "$(dirname "$SELF")/.." && pwd)"
POLICY="${TOOL_POLICY_FILE:-$REPO_ROOT/config/tool-policy.json}"

if [ ! -f "$POLICY" ]; then
  # Fail open with a stderr breadcrumb — better than blocking everything.
  echo "tool-guard: policy file not found at $POLICY" >&2
  exit 0
fi

# ---------- read event ----------
INPUT="$(cat)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')"

# ---------- helpers ----------
emit_deny() {
  # $1 = reason
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

emit_allow() { exit 0; }

# Look up a redirect suggestion from policy.redirect (returns empty if none).
redirect_for() {
  jq -r --arg k "$1" '.redirect[$k] // empty' "$POLICY"
}

# Map native write tool names to native_write_deny policy keys (lowercase).
native_write_policy_key() {
  case "$1" in
    Write)      echo write ;;
    StrReplace) echo strreplace ;;
    Delete)     echo delete ;;
    Edit)       echo edit ;;
    *)          echo "" ;;
  esac
}

deny_native_write_if_blocked() {
  local key sug
  key="$(native_write_policy_key "$TOOL")"
  [ -z "$key" ] && return 1
  if jq -e --arg k "$key" '.native_write_deny | index($k)' "$POLICY" >/dev/null; then
    sug="$(redirect_for "$key")"
    [ -z "$sug" ] && sug="fastedit edit via Shell"
    emit_deny "Native ${TOOL} tool is disabled by tool-policy.json (native_write_deny). Use \`$sug\` instead."
  fi
  return 1
}

# ---------- native tool gating (Read / Grep / Glob) ----------
case "$TOOL" in
  Read)
    if jq -e '.native_opencode_deny | index("read")' "$POLICY" >/dev/null; then
      sug="$(redirect_for cat)"
      [ -z "$sug" ] && sug="rtk read"
      emit_deny "Native Read tool is disabled by tool-policy.json (native_opencode_deny). Use Bash with \`$sug\` instead."
    fi
    emit_allow
    ;;
  Grep)
    if jq -e '.native_opencode_deny | index("grep")' "$POLICY" >/dev/null; then
      sug="$(redirect_for grep)"
      [ -z "$sug" ] && sug="rtk grep"
      emit_deny "Native Grep tool is disabled by tool-policy.json (native_opencode_deny). Use Bash with \`$sug\` instead."
    fi
    emit_allow
    ;;
  Glob)
    if jq -e '.native_opencode_deny | index("glob")' "$POLICY" >/dev/null; then
      sug="$(redirect_for find)"
      [ -z "$sug" ] && sug="rtk find"
      emit_deny "Native Glob tool is disabled by tool-policy.json (native_opencode_deny). Use Bash with \`$sug\` instead."
    fi
    emit_allow
    ;;
  List)
    if jq -e '.native_opencode_deny | index("list")' "$POLICY" >/dev/null; then
      sug="$(redirect_for ls)"
      [ -z "$sug" ] && sug="rtk ls"
      emit_deny "Native List tool is disabled by tool-policy.json (native_opencode_deny). Use Bash with \`$sug\` instead."
    fi
    emit_allow
    ;;
  Write|StrReplace|Delete|Edit)
    deny_native_write_if_blocked || emit_allow
    ;;
  Bash|Shell) : ;;      # Shell = Cursor's name for bash; fall through to matcher
  *)    emit_allow ;;   # not our concern
esac

# ---------- Bash policy matching ----------
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"
[ -z "$CMD" ] && emit_allow

# Trim leading whitespace, drop a leading `secret-cache exec -- ` prefix because
# that wrapper passes its tail through (the inner command is what we actually
# care about gating).
TRIMMED="${CMD#"${CMD%%[![:space:]]*}"}"
case "$TRIMMED" in
  "secret-cache exec -- "*) INNER="${TRIMMED#secret-cache exec -- }" ;;
  *)                         INNER="$TRIMMED" ;;
esac

# First token = the binary the agent is invoking.
read -r FIRST _ <<< "$INNER"

# ---------- pipeline pager check (BEFORE bash_allow emit_allow) ----------
# Deny | head/tail/less/more regardless of allow-tier status, so that
#   rtk read x | head    and    jq . f | head
# get caught on Claude/Codex/Cursor/Agy (OpenCode uses a separate mechanism
# in its plugin + native permission deny patterns). Run before bash_allow
# matching so the allow-tier emit_allow never fires for piped commands.
if [[ "$INNER" =~ \|[[:space:]]*(head|tail|less|more)([[:space:]]|$|\|) ]]; then
  pipe_cmd="${BASH_REMATCH[1]}"
  stripped="$(printf '%s' "$INNER" | sed -E 's/[[:space:]]*\|[[:space:]]*(head|tail|less|more)(\ [^|]*)?.*$//')"
  emit_deny "Do not pipe through \`$pipe_cmd\` (head/tail/less/more are denied). Re-run without the pipe: \`$stripped\`"
fi

# Match a command against a list of policy keys, longest-prefix-wins so that
# multi-word entries ("git push", "du -s") take precedence over single-word ones
# ("git", "du"). Returns the matched key on stdout.
#   single-token key  ("git")     → matches if FIRST token equals the key
#   multi-token key   ("git push") → matches only as a full word-prefix of CMD
match_in_list() {
  # $1 = jq path producing keys, $2 = command to test
  local keys cmd k best
  keys="$(jq -r "$1" "$POLICY")"
  cmd="$2"
  best=""
  while IFS= read -r k; do
    [ -z "$k" ] && continue
    if [[ "$k" == *" "* ]]; then
      # multi-token: require full word-prefix match
      case "$cmd " in
        "$k "*) ;;
        *) continue ;;
      esac
    else
      # single-token: only the leading binary
      [ "$k" = "$FIRST" ] || continue
    fi
    # Keep the longest matching key (most specific wins).
    if [ "${#k}" -gt "${#best}" ]; then
      best="$k"
    fi
  done <<< "$keys"
  [ -n "$best" ] && { echo "$best"; return 0; }
  return 1
}

# Precedence (most-specific wins, ask tiers checked before broad denies so that
# e.g. `git push` is captain_confirm instead of generic `git` deny):
#   1. bash_allow
#   2. bash_ask.captain_confirm
#   3. bash_ask.package_managers
#   4. bash_deny (any category)
#   5. default allow

if hit="$(match_in_list '.bash_allow | keys[]' "$INNER")"; then
  if [ "$FIRST" = "rtk" ]; then
    read -r _ RTK_SUB _ <<< "$INNER"
    if [ -n "$RTK_SUB" ] && jq -e --arg sub "$RTK_SUB" '.rtk_invalid_subcommands // [] | index($sub)' "$POLICY" >/dev/null; then
      sug="$(redirect_for "$RTK_SUB")"
      [ -z "$sug" ] && sug="rtk read"
      emit_deny "\`rtk $RTK_SUB\` is not a valid rtk subcommand. Use \`$sug\` instead (rtk output is already condensed — no head/tail piping)."
    fi
  fi
  emit_allow
fi

if hit="$(match_in_list '.bash_ask.captain_confirm[]' "$INNER")"; then
  emit_deny "\`$hit\` requires the captain's confirmation. Tell the captain what you want to run and why, then retry once they approve."
fi

if hit="$(match_in_list '.bash_ask.package_managers[]' "$INNER")"; then
  emit_deny "\`$hit\` (package manager) is in the ask tier. Get the captain's go-ahead before installing/modifying packages, then retry."
fi

if hit="$(match_in_list '[.bash_deny[][]] | .[]' "$INNER")"; then
  sug="$(redirect_for "$hit")"
  [ -z "$sug" ] && sug="$(redirect_for "$FIRST")"
  if [ -n "$sug" ]; then
    emit_deny "\`$FIRST\` is denied by tool-policy.json. Use \`$sug\` instead."
  else
    emit_deny "\`$FIRST\` is denied by tool-policy.json (no redirect configured — ask the captain)."
  fi
fi

# OpenCode's "*": "ask" has no Claude analogue (no ask UI). Anything not
# enumerated falls through to allow — matches the "only gate known-risky" intent.
emit_allow
