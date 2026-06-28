# Known Issues

## macOS / BSD

- `head -n -N` outputs nothing on macOS (BSD head). Use `tail -n +N` instead.
- `sed -i` requires an extension argument: `sed -i '' 's/old/new/' file`.

## Agent Config

- OpenCode instructions load from `~/.agent-rules/` (symlink to machine-scratch).
- Claude/Codex hooks → `~/bin/tool-guard.sh`. Cursor hooks → `~/bin/tool-guard-cursor.sh`.
- Per-account Claude OAuth requires `/login` in `~/.claude-a` once.

## fastedit edit (tldr-code `references`)

MLX backend and mlx-8bit model are installed (`fastedit doctor` green for mlx + model).
`fastedit read` / `doctor` work. `edit` / `rename` call `tldr references`, which
**llm-tldr 1.5.2 does not provide** — install parcadei **tldr-code** via:

```bash
bin/install-tldr-code.sh   # ~/.local/bin/tldr-code + dispatcher at ~/.local/bin/tldr
tldr references --help   # must succeed
fastedit edit --replace hello --snippet '…' /tmp/test.py
```

Until `references` works, agents should use normal patch/edit tools for writes.
See `docs/COMPLETION_CHECKLIST.md`.

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

Native **Write** / **StrReplace** / **Delete** are blocked in `preToolUse` (use `fastedit edit` via Shell). **Restart Cursor** after install so hooks reload.

`python3` / `python` are denied in Shell (script-interpreter bypass for file writes) — use `fastedit edit` or `uv` for package ops, not heredocs.

## Codex hooks

Codex `PreToolUse` currently fires for **Bash only** — native Read/Grep are not hookable in
Codex yet. Bash policy (`cat`, `rg`, `git`, …) is enforced via `~/.codex/hooks.json`.
Schema: `{ "hooks": { "PreToolUse": [...] } }` (PascalCase, not `preToolUse`).


## Antigravity (`agy`) hooks + run_command allowlist

After `bin/install-active-config.sh`, Antigravity PreToolUse runs via named block `tool-guard` in
`~/.gemini/config/hooks.json` and `~/bin/tool-guard-antigravity.sh` (maps `list_dir` / `read_file` /
`run_command` to tool-guard). Native `run_command` auto-approve comes from
`~/.gemini/antigravity-cli/settings.json` (rendered from `tool-policy.json` `bash_allow` as
`command(rtk)`, etc.). **Restart `agy` after install** so settings reload. Verify with
`rtk test bin/test-antigravity-hooks.sh`. Live: `rtk ls` should not prompt; `list_dir` should deny.

## rtk output — no head/tail piping

`rtk read`/`grep`/etc. already return condensed output. Policy denies `head`, `tail`, `less`, and `more`
and rejects invalid `rtk` subcommands (`rtk head`, `rtk cat`, …). Agents must use slice options on
`rtk read` or re-run rtk with tighter scope — never pipe rtk through pagers.


## Pipeline pager deny (WIP — 2026-06-27)

Partial fix shipped: `bin/tool-guard.sh` and `config/opencode/plugins/tool-guard/index.js`
deny pipeline pagers (`| head/tail/less/more`) with redirect:
`Re-run without the pipe: <stripped command>`. Do **not** auto-run the stripped command
(ask-tier commands like `pmset` still need harness approval).

### What works today

- `pmset -g | head -30` → deny + strip hint
- Multi-pipe, subshells, redirects before pipe, `secret-cache exec --` wrapper
- OpenCode plugin catches allowed-first-token + pager (pipe check before first-token logic)

### Known gaps (fix later)

1. **Allow-tier bypass in tool-guard.sh** — pipeline check runs *after* `bash_allow` emit_allow.
   `rtk read x | head` and `jq . f | head` **ALLOW** on Cursor/Claude/Codex/Agy.
   OpenCode plugin does not have this bug. Fix: run pipeline check before every `emit_allow`.

2. **Bypass variants not matched** — ALLOW: `| /usr/bin/head`, `| command head`,
   `| HEAD` (case-sensitive), `| ghead`. Extend regex or normalize before match.

3. **Truncator pivot** — agents may use `| sed -n`, `| awk NR<=`, `| cut` instead.

4. **OpenCode allow-tier + plugin (unverified live)** — unit test denies rtk+pager; TUI may differ.

5. **Meta** — guarded Shell blocks command strings containing pipeline pagers (incl. test code).

6. **Permission flow instructions** — GLOBAL.md lacks ask-vs-deny-vs-chat guidance.

### Test matrix

```bash
rtk test bin/test-tool-guard-pipes.sh   # 16 cases; 13 pass / 3 fail (2026-06-27)
rtk test bin/test-tool-guard.sh
```

Drive fixes from failures: rtk+pager and jq+pager (allow-tier bypass).

After edits: `bin/install-active-config.sh`

### Later checklist

- [ ] Pipeline check before all `emit_allow` in tool-guard.sh
- [ ] Regex: absolute path, command wrapper, case-insensitive, ghead
- [ ] Plugin pipe cases in test-opencode-permissions.sh
- [ ] Wire test-tool-guard-pipes.sh into test-all-policy.sh
- [ ] Live TUI smoke
- [ ] GLOBAL.md permission-flow section
- [ ] Optional: pmset/system_profiler in bash_allow
