#!/usr/bin/env bash
# test-all-policy.sh — run every automatable policy test (no live agent tokens).
#
# Usage:
#   test-all-policy.sh              # hook + harness structural tests
#   test-all-policy.sh --opencode   # also run full OpenCode verify stack
#   test-all-policy.sh --live ot    # also run OpenCode live probes (costs tokens)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DO_OPENCODE=0
DO_LIVE=0
LIVE_LAUNCHER="ot"

while [ $# -gt 0 ]; do
  case "$1" in
    --opencode) DO_OPENCODE=1 ;;
    --live) DO_LIVE=1; DO_OPENCODE=1 ;;
    oo|ot|op) LIVE_LAUNCHER="$1"; DO_LIVE=1; DO_OPENCODE=1 ;;
    -h|--help)
      sed -n '2,7p' "$0" | tr -d '#'
      exit 0
      ;;
    *) printf 'Unknown: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

printf '== install active config ==\n'
"$ROOT/bin/install-active-config.sh"

printf '\n== tool-guard hook logic ==\n'
"$ROOT/bin/test-tool-guard.sh"

printf '\n== pipeline pager deny ==\n'
"$ROOT/bin/test-tool-guard-pipes.sh"

printf '\n== Codex hooks schema ==\n'
"$ROOT/bin/test-codex-hooks.sh"

printf '\n== Cursor hooks + adapter ==\n'
"$ROOT/bin/test-cursor-hooks.sh"
"$ROOT/bin/test-antigravity-hooks.sh"

printf '\n== all harness structural verify ==\n'
VERIFY_ARGS=()
if [ "$DO_OPENCODE" -eq 0 ]; then
  # verify-active-config delegates to opencode verify only if opencode exists;
  # skip opencode section by temporarily hiding opencode if not requested
  if ! command -v opencode >/dev/null 2>&1; then
    :
  fi
fi
"$ROOT/bin/verify-active-config.sh"

if [ "$DO_OPENCODE" -eq 1 ] && command -v opencode >/dev/null 2>&1; then
  printf '\n== OpenCode full stack ==\n'
  "$ROOT/bin/test-opencode.sh" --no-install
fi

if [ "$DO_LIVE" -eq 1 ]; then
  printf '\n== OpenCode live probes (tokens) ==\n'
  "$ROOT/bin/test-opencode-live.sh" "$LIVE_LAUNCHER" --quick
fi

printf '\nAll requested policy tests finished.\n'
printf 'Manual live checks still needed for: ca (Claude), cx (Codex bash), cu (Cursor IDE — restart Cursor after hook changes).\n'
