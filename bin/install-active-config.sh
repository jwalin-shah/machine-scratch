#!/usr/bin/env bash
# install-active-config.sh — install machine-scratch as the active config for
# every agent harness on this machine (Claude, OpenCode, Cursor, Codex, …).
#
# Architecture:
#   1. config/tool-policy.json is the SINGLE source of truth for tool
#      permissions (allow / deny / ask).
#   2. bin/policy-render.sh renders that policy into per-harness JSON
#      fragments. Each harness has its own permission schema; the renderer
#      knows the translation.
#   3. This installer:
#        a. runs policy-render.sh once,
#        b. merges each fragment into the live config file (preserving
#           non-policy keys like OAuth, model selection, theme),
#        c. wires the PreToolUse hook (tool-guard.sh) into every harness
#           that supports hooks, for the residual smart-routing the native
#           permission schemas can't express (custom redirect messages,
#           secret-cache exec unwrap, captain-confirm tier),
#        d. copies launchers, agent-rules, etc.
#
# Layered defense: native permissions catch ~95% of cases instantly without
# spawning a script; the hook catches the remaining 5% with richer feedback.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p \
  "$HOME/.config/opencode/plugins/tool-guard" \
  "$HOME/.local/bin" \
  "$HOME/bin" \
  "$HOME/.claude/logs" \
  "$HOME/.claude-a" \
  "$HOME/.claude-b" \
  "$HOME/.claude-token" \
  "$HOME/.claude-pioneer" \
  "$HOME/.codex" \
  "$HOME/.cursor" \
  "$HOME/Library/LaunchAgents"

# Render the policy ONCE. Subsequent steps slice keys out of this blob.
POLICY_OUT="$(mktemp)"
trap 'rm -f "$POLICY_OUT"' EXIT
"$ROOT/bin/policy-render.sh" all > "$POLICY_OUT"

# ---------- helpers ----------

# Merge a JSON object into a target file, preserving keys not in the patch.
# If the target doesn't exist, create it from the patch alone.
#
#   merge_json <target> <patch_json_string>
merge_json() {
  local target="$1" patch="$2"
  local tmp
  tmp="$(mktemp)"
  if [ -f "$target" ]; then
    jq --argjson p "$patch" '. * $p' "$target" > "$tmp"
  else
    printf '%s' "$patch" | jq '.' > "$tmp"
  fi
  mv "$tmp" "$target"
}

# Merge the per-account Claude shared settings (hooks block + dangerous-perm
# skip flag) into a target settings.json. Then layer the rendered Claude
# native permissions on top.
merge_claude_settings() {
  local target="$1"
  local shared="$ROOT/config/claude/shared-settings.json"
  local claude_perms
  claude_perms="$(jq -c '.claude' "$POLICY_OUT")"

  if [ ! -f "$target" ]; then
    cp "$shared" "$target"
  fi
  # Layer 1: hooks + skipDangerousModePermissionPrompt + verbose
  local tmp1
  tmp1="$(mktemp)"
  jq -s '.[0] * .[1]' "$target" "$shared" > "$tmp1"
  # Layer 2: native permissions from tool-policy.json
  local tmp2
  tmp2="$(mktemp)"
  jq --argjson p "$claude_perms" '. * $p' "$tmp1" > "$tmp2"
  mv "$tmp2" "$target"
  rm -f "$tmp1"
}

# ---------- agent rules ----------
ln -sfn "$ROOT/agent-rules" "$HOME/.agent-rules"

# ---------- OpenCode ----------
mkdir -p "$HOME/.config/opencode/profiles"
# Copy the base opencode.json (model, providers, profiles, etc.) then merge in
# the rendered permission block so tool-policy.json wins on permissions.
cp "$ROOT/config/opencode/opencode.json" "$HOME/.config/opencode/opencode.json"
opencode_perms="$(jq -c '.opencode' "$POLICY_OUT")"
merge_json "$HOME/.config/opencode/opencode.json" "$opencode_perms"
cp "$ROOT/config/opencode/plugins/tool-guard/index.js" "$HOME/.config/opencode/plugins/tool-guard/index.js"
# Silence Node's MODULE_TYPELESS_PACKAGE_JSON warning for the ESM tool-guard plugin.
printf '%s\n' '{"type":"module"}' > "$HOME/.config/opencode/package.json"
cp "$ROOT/config/opencode/profiles/"*.json "$HOME/.config/opencode/profiles/"

# ---------- secret-scoped and provider launchers (~/.local/bin) ----------
for launcher in oo ot op cx; do
  cp "$ROOT/config/launchers/$launcher" "$HOME/.local/bin/$launcher"
  chmod 755 "$HOME/.local/bin/$launcher"
done

# ---------- Claude (claude-launch stack + account launchers) ----------
for f in claude-launch agentlib.py claude-endpoints.toml log_setup.py; do
  cp "$ROOT/config/claude/$f" "$HOME/bin/$f"
done
chmod 755 "$HOME/bin/claude-launch"

for launcher in ca cb ct ccp cu agy; do
  cp "$ROOT/config/launchers/$launcher" "$HOME/bin/$launcher"
  chmod 755 "$HOME/bin/$launcher"
done

# Claude settings — global + 4 per-account. Each gets hooks + native perms.
merge_claude_settings "$HOME/.claude/settings.json"
for account_dir in .claude-a .claude-b .claude-token .claude-pioneer; do
  merge_claude_settings "$HOME/$account_dir/settings.json"
done

# ---------- tool guard symlink (the hook every harness calls) ----------
ln -sf "$ROOT/bin/tool-guard.sh" "$HOME/bin/tool-guard.sh"

# ---------- Cursor (native perms + v1 hooks) ----------
cursor_perms="$(jq -c '.cursor' "$POLICY_OUT")"
merge_json "$HOME/.cursor/cli-config.json" "$cursor_perms"
ln -sf "$ROOT/bin/tool-guard-cursor.sh" "$HOME/bin/tool-guard-cursor.sh"
cursor_hooks="$(jq -c '.cursor_hooks_json' "$POLICY_OUT")"
printf '%s' "$cursor_hooks" | jq '.' > "$HOME/.cursor/hooks.json"
if ! jq -e '(.version == 1) and (.hooks.beforeShellExecution | length > 0)' "$HOME/.cursor/hooks.json" >/dev/null; then
  echo "install-active-config: invalid Cursor hooks.json" >&2
  exit 1
fi

# ---------- Codex (hook only — native perms unverified) ----------
codex_hooks="$(jq -c '.codex.hooks_json' "$POLICY_OUT")"
printf '%s' "$codex_hooks" | jq '.' > "$HOME/.codex/hooks.json"
if ! jq -e '.hooks.PreToolUse | length > 0' "$HOME/.codex/hooks.json" >/dev/null; then
  echo "install-active-config: invalid Codex hooks.json (expected .hooks.PreToolUse)" >&2
  exit 1
fi


# ---------- agent skills (~/.agents/skills/) ----------
mkdir -p "$HOME/.agents/skills"
for skill in pioneer-api inference-net tool-policy; do
  ln -sfn "$ROOT/skills/$skill" "$HOME/.agents/skills/$skill"
done

# ---------- secret-cache refresh LaunchAgent ----------
cp "$ROOT/config/launchd/com.jwalinshah.secret-cache-refresh.plist" \
  "$HOME/Library/LaunchAgents/com.jwalinshah.secret-cache-refresh.plist"
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.jwalinshah.secret-cache-refresh.plist" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.jwalinshah.secret-cache-refresh.plist"

echo "active config installed from $ROOT"
echo "  policy version: $(jq -r .version "$ROOT/config/tool-policy.json")"
echo "  harnesses:      claude, opencode, cursor, codex"
