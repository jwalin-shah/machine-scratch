#!/usr/bin/env bash
# test-opencode-ask.sh — prove ask-gated commands actually prompt.
#
# Strategy: run the same prompt twice.
#   pass A: opencode run …                          (no auto-approve)
#   pass B: opencode run --dangerously-skip-permissions …
#
# An ask-gated command (e.g. webfetch, unlisted bash) should:
#   pass A: stall waiting for approval (timeout) or report "permission required"
#   pass B: run to completion with output
#
# Deny-listed commands should fail in BOTH passes (no flag bypasses deny).
# Allow-listed commands should succeed in BOTH passes (no prompt either way).
#
# Usage: test-opencode-ask.sh [ot|oo|op]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER="${1:-ot}"
PROFILE="$HOME/.config/opencode/profiles/${LAUNCHER}.json"
[ -f "$PROFILE" ] || { echo "missing profile: $PROFILE" >&2; exit 2; }
MODEL="$(jq -r '.model' "$PROFILE")"
TIMEOUT="${OPENCODE_ASK_TIMEOUT:-45}"

export OPENCODE_CONFIG="$PROFILE"

run_pair() {
  local label="$1" prompt="$2" expect="$3"
  local out_a out_b code_a code_b
  printf '\n== %s (expect: %s) ==\n' "$label" "$expect"

  out_a="$(timeout "$TIMEOUT" opencode run -m "$MODEL" "$prompt" 2>&1 || true)"
  code_a=$?

  out_b="$(timeout "$TIMEOUT" opencode run --dangerously-skip-permissions -m "$MODEL" "$prompt" 2>&1 || true)"
  code_b=$?

  local marker='machine-scratch|launcher|README|HTTP/|<html|http'
  local has_a has_b
  echo "$out_a" | rg -iq "$marker" && has_a=1 || has_a=0
  echo "$out_b" | rg -iq "$marker" && has_b=1 || has_b=0

  printf '  no-flag output markers : %s\n' "$has_a"
  printf '  skip-perm output markers: %s\n' "$has_b"

  case "$expect" in
    ask)
      if [ "$has_a" = "0" ] && [ "$has_b" = "1" ]; then
        printf '  PASS  ask gated — no output without approval, output with skip\n'
      else
        printf '  WARN  expected ask-gate behavior (0 then 1); got %s then %s\n' "$has_a" "$has_b"
      fi
      ;;
    allow)
      if [ "$has_a" = "1" ] && [ "$has_b" = "1" ]; then
        printf '  PASS  allowed in both passes\n'
      else
        printf '  WARN  expected allow in both; got %s then %s\n' "$has_a" "$has_b"
      fi
      ;;
    deny)
      if [ "$has_a" = "0" ] && [ "$has_b" = "0" ]; then
        printf '  PASS  denied in both passes (deny is not bypassable)\n'
      else
        printf '  WARN  expected deny in both; got %s then %s\n' "$has_a" "$has_b"
      fi
      ;;
  esac

  printf '\n--- no-flag tail ---\n%s\n' "$(echo "$out_a" | tail -8)"
  printf '\n--- skip-perm tail ---\n%s\n' "$(echo "$out_b" | tail -8)"
}

printf 'Verifying ask/allow/deny enforcement\n'
printf '  launcher: %s\n' "$LAUNCHER"
printf '  model:    %s\n' "$MODEL"
printf '  timeout:  %ss per run\n' "$TIMEOUT"

run_pair "ALLOW: rtk grep" "allow" \
  "Run exactly this bash command and show the output: rtk grep launcher $ROOT/bin"

run_pair "DENY: rg" "deny" \
  "Run exactly this bash command and show the output: rg -l launcher $ROOT"

run_pair "ASK: brew --version" "ask" \
  "Run exactly this bash command and show the output: brew --version"

run_pair "ASK: webfetch example.com" "ask" \
  "Fetch the URL https://example.com using the WebFetch tool and show the HTML title."

printf '\nDone.\n'
