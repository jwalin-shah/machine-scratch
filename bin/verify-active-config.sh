#!/usr/bin/env bash
# verify-active-config.sh — structural checks that every harness matches tool-policy.
# No tokens, no live agent sessions. Run after install-active-config.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PASS=0

ok() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n== %s ==\n' "$1"; }

POLICY="$ROOT/config/tool-policy.json"
POLICY_VER="$(jq -r .version "$POLICY")"

section "Source of truth"
[ -f "$POLICY" ] && ok "tool-policy.json exists (v$POLICY_VER)" || bad "tool-policy.json missing"

section "Agent rules"
if [ "$(readlink "$HOME/.agent-rules" 2>/dev/null)" = "$ROOT/agent-rules" ]; then
  ok "~/.agent-rules → machine-scratch/agent-rules"
else
  bad "~/.agent-rules symlink wrong or missing"
fi

section "Tool guard"
if [ -x "$HOME/bin/tool-guard.sh" ] && [ "$(readlink "$HOME/bin/tool-guard.sh" 2>/dev/null || echo "$HOME/bin/tool-guard.sh")" = "$ROOT/bin/tool-guard.sh" ] || cmp -s "$HOME/bin/tool-guard.sh" "$ROOT/bin/tool-guard.sh" 2>/dev/null; then
  ok "tool-guard.sh installed"
else
  bad "tool-guard.sh missing or not linked from repo"
fi
if [ -x "$HOME/bin/tool-guard-cursor.sh" ]; then
  ok "tool-guard-cursor.sh installed"
else
  bad "tool-guard-cursor.sh missing"
fi

section "Claude (native + hook)"
for f in "$HOME/.claude/settings.json" "$HOME/.claude-a/settings.json"; do
  base="$(basename "$(dirname "$f")")"
  if jq -e '.permissions.deny | index("Read")' "$f" >/dev/null 2>&1; then
    ok "$base permissions deny Read"
  else
    bad "$base permissions missing Read deny"
  fi
  if jq -e '.hooks.PreToolUse[0].hooks[0].command | test("tool-guard")' "$f" >/dev/null 2>&1; then
    ok "$base PreToolUse hook wired"
  else
    bad "$base PreToolUse hook missing"
  fi
done

section "Codex hooks"
RENDERED_CODEX="$(mktemp)"
trap 'rm -f "$RENDERED_CODEX" "$RENDERED_CURSOR"' EXIT
"$ROOT/bin/policy-render.sh" codex | jq -c '.hooks_json' > "$RENDERED_CODEX"
if [ -f "$HOME/.codex/hooks.json" ]; then
  if jq -S . "$RENDERED_CODEX" | cmp -s - <(jq -S . "$HOME/.codex/hooks.json"); then
    ok "Codex hooks.json matches rendered policy"
  else
    bad "Codex hooks.json drift"
  fi
  if jq -e '.hooks.PreToolUse | length > 0' "$HOME/.codex/hooks.json" >/dev/null; then
    ok "Codex hooks.PreToolUse present"
  else
    bad "Codex hooks.PreToolUse missing"
  fi
else
  bad "Codex hooks.json missing"
fi

section "Cursor (cli-config + v1 hooks)"
RENDERED_CURSOR="$(mktemp)"
"$ROOT/bin/policy-render.sh" cursor-hooks > "$RENDERED_CURSOR"
if [ -f "$HOME/.cursor/cli-config.json" ]; then
  if jq -e '.permissions.deny | index("Shell(cat)")' "$HOME/.cursor/cli-config.json" >/dev/null; then
    ok "Cursor cli-config denies Shell(cat)"
  else
    bad "Cursor cli-config missing Shell(cat) deny"
  fi
  if jq -e '.approvalMode == "allowlist"' "$HOME/.cursor/cli-config.json" >/dev/null; then
    ok "Cursor approvalMode allowlist"
  else
    bad "Cursor approvalMode not allowlist"
  fi
else
  bad "Cursor cli-config.json missing"
fi
if [ -f "$HOME/.cursor/hooks.json" ]; then
  if jq -S . "$RENDERED_CURSOR" | cmp -s - <(jq -S . "$HOME/.cursor/hooks.json"); then
    ok "Cursor hooks.json matches rendered policy"
  else
    bad "Cursor hooks.json drift"
  fi
  if jq -e '(.version == 1) and (.hooks.beforeShellExecution | length > 0)' "$HOME/.cursor/hooks.json" >/dev/null; then
    ok "Cursor beforeShellExecution hook present"
  else
    bad "Cursor beforeShellExecution missing"
  fi
  if jq -e '.hooks.beforeReadFile | length > 0' "$HOME/.cursor/hooks.json" >/dev/null; then
    ok "Cursor beforeReadFile hook present"
  else
    bad "Cursor beforeReadFile missing"
  fi
else
  bad "Cursor hooks.json missing"
fi

section "OpenCode (delegate)"
if command -v opencode >/dev/null 2>&1; then
  if "$ROOT/bin/verify-opencode-config.sh" >/tmp/verify-opencode.out 2>&1; then
    ok "OpenCode verify-opencode-config.sh passed"
  else
    bad "OpenCode verify failed — see output below"
    tail -15 /tmp/verify-opencode.out | sed 's/^/    /'
  fi
else
  printf '  skip  opencode not on PATH\n'
fi

section "Summary"
printf '  %d passed, %d failed (policy v%s)\n' "$PASS" "$FAIL" "$POLICY_VER"
[ "$FAIL" -eq 0 ] || { printf '\nFix failures, then: bin/install-active-config.sh\n'; exit 1; }
printf '\nStructural checks passed for all installed harnesses.\n'
printf 'Next: rtk test bin/test-all-policy.sh\n'
