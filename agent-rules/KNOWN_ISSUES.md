# Known Issues

## macOS / BSD

- `head -n -N` outputs nothing on macOS (BSD head). Use `tail -n +N` instead.
- `sed -i` requires an extension argument: `sed -i '' 's/old/new/' file`.

## Agent Config

- OpenCode instructions load from `~/.agent-rules/` (symlink to machine-scratch).
- Claude/Codex hooks → `~/bin/tool-guard.sh`. Cursor hooks → `~/bin/tool-guard-cursor.sh`.
- Per-account Claude OAuth requires `/login` in each of `~/.claude-a`, `~/.claude-b` once.

## fastedit edit (MLX not installed)

`fastedit read` / `search` / `doctor` work. `fastedit edit` needs:

```bash
uv tool install "fastedits[mlx]" --force
fastedit pull --model mlx-8bit
mkdir -p ~/.fastedit/backups
```

Until then, agents should use normal patch/edit tools for writes.

## Missing / Planned Tools

These are in policy but not yet on PATH. Use fallbacks from TOOL_REGISTRY.md:
`fm-tasks`.

## coreutils / `gtimeout`

Homebrew `coreutils` is installed so live smoke tests can use `gtimeout` on macOS. Do not add `/opt/homebrew/opt/coreutils/libexec/gnubin` to agent PATH: GNU aliases like `gcat`, `gls`, `ggrep`, and `gfind` bypass the policy intent. Agents may use only `gtimeout`/`timeout` to bound tests or live agent probes.

## OpenCode ESM plugin warning

`config/opencode/plugins/tool-guard/index.js` is an ES module. The installer writes `~/.config/opencode/package.json` with `{ "type": "module" }` to avoid Node's `MODULE_TYPELESS_PACKAGE_JSON` warning. If the warning returns, rerun `bin/install-active-config.sh`.

## cursor-agent (`cu`) — install via official curl, NOT Homebrew

Install `cursor-agent` with the official installer, never the Homebrew cask:

```bash
curl https://cursor.com/install -fsS | bash
```

This lands at `~/.local/bin/cursor-agent` (symlink into
`~/.local/share/cursor-agent/versions/<v>/`), and the `cu` launcher points there.

Why not the `cursor-cli` Homebrew cask: the cask ships unsigned native modules
(e.g. `merkle-tree-napi.darwin-arm64.node`) and stamps every file with
`com.apple.quarantine`. The module loads fine at rest, but the first time
`cursor-agent` `dlopen`s it, Gatekeeper/XProtect blocks the unsigned binary and
removes it. Symptom: reinstall "succeeds", then `cu` immediately dies with
`dlopen(...merkle-tree-napi.darwin-arm64.node) ... (no such file)` for a file that
visibly existed seconds earlier. Reinstalling just restarts the loop. The curl
installer writes via curl/tar, which does not set quarantine, so it is not affected.

If the cask ever gets reinstalled and you must keep it, strip quarantine before the
first run: `xattr -dr com.apple.quarantine <dist-package-dir>` — but prefer the curl
installer so this does not recur.

## Examples (not active)

Reference repos live under `~/projects/examples/`. Do not point active config there.
Promote pieces into machine-scratch before using.

## Cursor hooks

After `bin/install-active-config.sh`, **restart Cursor IDE** so `~/.cursor/hooks.json` reloads.
Hooks use Cursor v1 schema (`beforeShellExecution`, `beforeReadFile`, `preToolUse`) via
`~/bin/tool-guard-cursor.sh`. Verify with `rtk test bin/test-cursor-hooks.sh`.

## Codex hooks

Codex `PreToolUse` currently fires for **Bash only** — native Read/Grep are not hookable in
Codex yet. Bash policy (`cat`, `rg`, `git`, …) is enforced via `~/.codex/hooks.json`.
Schema: `{ "hooks": { "PreToolUse": [...] } }` (PascalCase, not `preToolUse`).
