#!/usr/bin/env bash
# verify-rtk-stack.sh — smoke test rtk, fastedit, llm-tldr on PATH.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
pass=0
fail=0

check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '  ok   %s\n' "$label"
    pass=$((pass + 1))
  else
    printf '  FAIL %s\n' "$label"
    fail=$((fail + 1))
  fi
}

echo "== rtk subcommands =="
check "rtk read" rtk read README.md
check "rtk grep" rtk grep -l "machine-scratch" README.md
check "rtk ls" rtk ls .
check "rtk find" rtk find -name 'tool-policy.json'
check "rtk git status" rtk git status --short
if command -v tree >/dev/null 2>&1; then
  check "rtk tree" rtk tree -L 2 .
else
  printf '  skip rtk tree (GNU tree not installed — brew install tree)\n'
fi

echo "== llm-tldr =="
check "llm-tldr doctor" llm-tldr doctor

echo "== fastedit =="
check "fastedit doctor" fastedit doctor
if tldr references --help >/dev/null 2>&1; then
  check "fastedit read" fastedit read README.md
  tmp="${ROOT}/.verify-fastedit-smoke.py"
  printf 'def hello():\n    return 1\n' > "$tmp"
  if fastedit edit --replace hello --snippet 'def hello():\n    return 2\n' "$tmp" >/dev/null 2>&1; then
    printf '  ok   fastedit edit smoke\n'
    pass=$((pass + 1))
  else
    printf '  FAIL fastedit edit smoke\n'
    fail=$((fail + 1))
  fi
  rm -f "$tmp"
else
  printf '  skip fastedit edit (tldr references missing — run bin/install-tldr-code.sh)\n'
fi

echo
printf 'Passed: %s   Failed: %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
