#!/usr/bin/env bash
# test-codex-hooks.sh — validate rendered Codex hooks.json schema.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIVE="$HOME/.codex/hooks.json"
RENDERED="$(mktemp)"
trap 'rm -f "$RENDERED"' EXIT

"$ROOT/bin/policy-render.sh" codex | jq -c '.hooks_json' > "$RENDERED"

fail=0
check() {
  if "$@"; then
    echo "  ok   $*"
  else
    echo "  FAIL $*"
    fail=1
  fi
}

echo "== Rendered Codex hooks schema =="
check jq -e '.hooks.PreToolUse | length > 0' "$RENDERED"
check jq -e '.hooks.PreToolUse[0].matcher | test("Bash")' "$RENDERED"
check jq -e '.hooks.PreToolUse[0].hooks[0].type == "command"' "$RENDERED"
check jq -e '.hooks.PreToolUse[0].hooks[0].command | length > 0' "$RENDERED"
if jq -e 'has("preToolUse")' "$RENDERED" >/dev/null 2>&1; then
  echo "  FAIL must not have top-level preToolUse"
  fail=1
else
  echo "  ok   no top-level preToolUse"
fi

if [ -f "$LIVE" ]; then
  echo "== Live ~/.codex/hooks.json =="
  if jq -S . "$RENDERED" | cmp -s - <(jq -S . "$LIVE"); then
    echo "  ok   live matches rendered"
  else
    echo "  FAIL live drift — run: bin/install-active-config.sh"
    fail=1
  fi
else
  echo "  skip live hooks.json (not installed)"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "Codex hooks schema OK"
else
  echo "Codex hooks schema FAILED"
  exit 1
fi
