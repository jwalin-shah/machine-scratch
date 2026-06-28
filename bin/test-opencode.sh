#!/usr/bin/env bash
# test-opencode.sh — run all automatable OpenCode checks (no TUI, no tokens by default).
#
# Usage:
#   test-opencode.sh              # install + verify + permissions + profiles
#   test-opencode.sh --no-install # skip install-active-config.sh
#   test-opencode.sh --live       # also run test-opencode-live.sh ot --quick
#   test-opencode.sh --live oo    # live tests for a specific launcher
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DO_INSTALL=1
DO_LIVE=0
LIVE_LAUNCHER="ot"

while [ $# -gt 0 ]; do
  case "$1" in
    --no-install) DO_INSTALL=0 ;;
    --live) DO_LIVE=1 ;;
    oo|ot|op) LIVE_LAUNCHER="$1"; DO_LIVE=1 ;;
    -h|--help)
      sed -n '2,8p' "$0" | tr -d '#'
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

if [ "$DO_INSTALL" -eq 1 ]; then
  printf '== install active config ==\n'
  "$ROOT/bin/install-active-config.sh"
fi

printf '\n== structural verify ==\n'
"$ROOT/bin/verify-opencode-config.sh"

printf '\n== permission layers ==\n'
"$ROOT/bin/test-opencode-permissions.sh"

printf '\n== profiles + model catalogs ==\n'
"$ROOT/bin/test-opencode-profiles.sh"

if [ "$DO_LIVE" -eq 1 ]; then
  printf '\n== live agent probes (network + tokens) ==\n'
  "$ROOT/bin/test-opencode-live.sh" "$LIVE_LAUNCHER" --quick
fi

printf '\nAll requested checks finished.\n'
