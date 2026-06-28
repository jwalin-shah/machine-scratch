#!/usr/bin/env bash
# install-tldr-code.sh — Install parcadei tldr-code v0.4.0 and a PATH dispatcher
# that routes fastedit-facing subcommands (references, definition, …) to tldr-code
# and llm-tldr subcommands (tree, structure, …) to llm-tldr.
set -euo pipefail

VERSION="${TLDR_CODE_VERSION:-0.4.0}"
ARCH="${TLDR_CODE_ARCH:-aarch64-apple-darwin}"
ASSET="tldr-cli-${ARCH}.tar.xz"
BASE_URL="https://github.com/parcadei/tldr-code/releases/download/v${VERSION}"
LOCAL_BIN="${HOME}/.local/bin"
TLDR_CODE="${LOCAL_BIN}/tldr-code"
TLDR_DISPATCH="${LOCAL_BIN}/tldr"
LLM_TLDR="${LOCAL_BIN}/llm-tldr"

mkdir -p "$LOCAL_BIN"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "== download tldr-code ${VERSION} (${ARCH}) =="
curl -fsSL -o "${tmpdir}/${ASSET}" "${BASE_URL}/${ASSET}"
tar -xJf "${tmpdir}/${ASSET}" -C "$tmpdir"
extracted="${tmpdir}/tldr-cli-${ARCH}"
install -m 755 "${extracted}/tldr" "$TLDR_CODE"
if [ -f "${extracted}/tldr-daemon" ]; then
  install -m 755 "${extracted}/tldr-daemon" "${LOCAL_BIN}/tldr-daemon"
fi

if ! command -v "$LLM_TLDR" >/dev/null 2>&1; then
  echo "error: llm-tldr not found at $LLM_TLDR" >&2
  exit 1
fi

if [ -e "$TLDR_DISPATCH" ] && [ ! -f "${TLDR_DISPATCH}.llm-tldr.bak" ]; then
  if grep -q 'tldr-code dispatcher' "$TLDR_DISPATCH" 2>/dev/null; then
    echo "dispatcher already installed at $TLDR_DISPATCH"
  else
    echo "== backup existing tldr -> tldr.llm-tldr.bak =="
    cp -p "$TLDR_DISPATCH" "${TLDR_DISPATCH}.llm-tldr.bak"
  fi
elif [ -e "$TLDR_DISPATCH" ] && [ -f "${TLDR_DISPATCH}.llm-tldr.bak" ]; then
  echo "backup already exists: ${TLDR_DISPATCH}.llm-tldr.bak"
fi

cat > "$TLDR_DISPATCH" << 'DISPATCH'
#!/usr/bin/env bash
# tldr-code dispatcher — routes subcommands between parcadei tldr-code and llm-tldr.
set -euo pipefail
TLDR_CODE="${HOME}/.local/bin/tldr-code"
LLM_TLDR="${HOME}/.local/bin/llm-tldr"
sub="${1:-}"

case "$sub" in
  -h|--help|help|"")
    exec "$TLDR_CODE" --help
    ;;
  -V|--version|version)
    exec "$TLDR_CODE" --version
    ;;
esac

case "$sub" in
  tree|t|extract|e|context|cfg|dfg|slice|arch|imports|importers|change-impact|warm|w|semantic|daemon|doctor|doc|calls|c|impact|i|dead|d|diagnostics|diag)
    exec "$LLM_TLDR" "$@"
    ;;
  structure|s)
    # fastedit uses `tldr structure --format compact` (tldr-code only)
    exec "$TLDR_CODE" "$@"
    ;;
  references|refs|definition|def|search)
    exec "$TLDR_CODE" "$@"
    ;;
  *)
    if "$TLDR_CODE" "$sub" --help >/dev/null 2>&1; then
      exec "$TLDR_CODE" "$@"
    fi
    exec "$LLM_TLDR" "$@"
    ;;
esac
DISPATCH
chmod +x "$TLDR_DISPATCH"

echo "== verify =="
"$TLDR_CODE" --version
"$TLDR_DISPATCH" references --help >/dev/null
echo "installed: $TLDR_CODE"
echo "dispatcher: $TLDR_DISPATCH -> tldr-code + llm-tldr"
