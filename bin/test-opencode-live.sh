#!/usr/bin/env bash
# test-opencode-live.sh — live agent permission probes via `opencode run`.
# Uses network + provider auth. Costs tokens. Run only when structural tests pass.
#
# Usage:
#   test-opencode-live.sh              # ot profile (TokenRouter default)
#   test-opencode-live.sh oo           # ChatGPT Plus
#   test-opencode-live.sh op           # Pioneer
#   test-opencode-live.sh ot --quick   # one deny + one allow only
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER="${1:-ot}"
QUICK="${2:-}"

case "$LAUNCHER" in
  oo)
    PROFILE="$HOME/.config/opencode/profiles/oo.json"
    MODEL="$(jq -r '.model' "$PROFILE")"
    OPENCODE_RUN=(opencode run)
    ;;
  ot)
    PROFILE="$HOME/.config/opencode/profiles/ot.json"
    MODEL="$(jq -r '.model' "$PROFILE")"
    OPENCODE_RUN=("$HOME/.local/bin/secret-cache" exec -- opencode run)
    ;;
  op)
    PROFILE="$HOME/.config/opencode/profiles/op.json"
    MODEL="$(jq -r '.model' "$PROFILE")"
    OPENCODE_RUN=("$HOME/.local/bin/secret-cache" exec -- opencode run)
    ;;
  *)
    printf 'Usage: %s [oo|ot|op] [--quick]\n' "$(basename "$0")" >&2
    exit 2
    ;;
esac

export OPENCODE_CONFIG="$PROFILE"
TIMEOUT="${OPENCODE_TEST_TIMEOUT:-120}"
TIMEOUT_BIN="$(command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null || true)"
WORKDIR="$ROOT"

printf 'Live OpenCode tests\n'
printf '  launcher: %s\n' "$LAUNCHER"
printf '  model:    %s\n' "$MODEL"
printf '  workdir:  %s\n' "$WORKDIR"
printf '  timeout:  %ss per prompt\n\n' "$TIMEOUT"

run_prompt() {
  local label="$1"
  local expect="$2"
  local prompt="$3"
  local out tmp
  tmp="$(mktemp)"
  printf '== %s (expect: %s) ==\n' "$label" "$expect"

  if [ -n "$TIMEOUT_BIN" ]; then
    if "$TIMEOUT_BIN" "$TIMEOUT" "${OPENCODE_RUN[@]}" -m "$MODEL" "$prompt" >"$tmp" 2>&1; then
      :
    else
      printf '  WARN  opencode run exited non-zero (may still be a valid deny)\n'
    fi
  else
    printf '  WARN  timeout/gtimeout not found; running without timeout\n'
    if "${OPENCODE_RUN[@]}" -m "$MODEL" "$prompt" >"$tmp" 2>&1; then
      :
    else
      printf '  WARN  opencode run exited non-zero (may still be a valid deny)\n'
    fi
  fi

  out="$(cat "$tmp")"
  rm -f "$tmp"

  case "$expect" in
    deny)
      if echo "$out" | rg -iq 'denied|permission|blocked|not allowed|cannot run|use (rtk|bat|rg|eza|fd)'; then
        printf '  PASS  agent refused or redirected\n'
      elif echo "$out" | rg -q '^# '; then
        printf '  FAIL  looks like cat/file dump — permission may have leaked\n'
        return 1
      else
        printf '  WARN  unclear denial — review output below\n'
      fi
      ;;
    allow)
      if echo "$out" | rg -q 'machine-scratch|launcher|README|\.json'; then
        printf '  PASS  agent returned substantive output\n'
      else
        printf '  WARN  no obvious success markers — review output below\n'
      fi
      ;;
  esac

  printf '\n--- output (last 30 lines) ---\n'
  echo "$out" | tail -30
  printf '%s\n\n' '--- end ---'
}

DENY_PROMPTS=(
  "Run exactly this bash command and show me the output: cat README.md|deny"
  "Run exactly this bash command: rg -l launcher .|deny"
  "Run exactly this bash command: git status|deny"
  "Run exactly this bash command: eza -la|deny"
  "Run exactly this bash command: export FOO=bar && echo ok|deny"
)

ALLOW_PROMPTS=(
  "Run exactly this bash command: rtk grep launcher $ROOT|allow"
  "Run exactly this bash command: rtk ls $ROOT|allow"
  "Run exactly this bash command: du -s $ROOT|allow"
)

if [ "$QUICK" = "--quick" ]; then
  IFS='|' read -r p e <<< "${DENY_PROMPTS[0]}"
  run_prompt "deny: cat" "$e" "$p" || true
  IFS='|' read -r p e <<< "${ALLOW_PROMPTS[0]}"
  run_prompt "allow: rg" "$e" "$p" || true
else
  for entry in "${DENY_PROMPTS[@]}"; do
    IFS='|' read -r p e <<< "$entry"
    run_prompt "deny: ${p:0:40}..." "$e" "$p" || true
  done
  for entry in "${ALLOW_PROMPTS[@]}"; do
    IFS='|' read -r p e <<< "$entry"
    run_prompt "allow: ${p:0:40}..." "$e" "$p" || true
  done
fi

printf 'Live run finished. Review WARN/FAIL lines above.\n'
