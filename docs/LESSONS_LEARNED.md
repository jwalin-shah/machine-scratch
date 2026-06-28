# Lessons Learned

Design and implementation mistakes we don't want to repeat.

---

## 2026-06-27: Allow-tier pipeline pager bypass

### The bug

The pipe-pager deny (`| head/tail/less/more`) in `tool-guard.sh` ran AFTER
`bash_allow` → `emit_allow`, so allow-tier tools (`rtk`, `jq`, `du`, `fastedit`,
`llm-tldr`, etc.) could pipe to `| head` without being caught. Agents did this
constantly — `rtk read foo | head` — and it sailed right through on Claude,
Codex, Cursor, and Antigravity.

OpenCode had a parallel gap: the plugin's `permission.ask` only fires for
"ask"-tier commands. Native-allowed tools like `rtk` bypassed the plugin
entirely, so the pipe check there never ran for them either.

### Why it was missed

1. **Wrong placement for a "super-deny"** — The pipe check was added as a
   "last-resort catch-all" at the END of the matching logic (after allow/ask/deny
   all resolved). The implicit assumption was: "allow-tier tools are well-behaved,
   they wouldn't need pipe denial." This was wrong — agents pipe everything.

2. **Tests caught it but weren't wired into CI** — `test-tool-guard-pipes.sh`
   had 3 of 16 cases failing (rtk+pager, jq+pager, head-in-arg). The test was
   committed with known failures but NEVER wired into `test-all-policy.sh`.
   It ran independently and its failures didn't gate anything.

3. **OpenCode and tool-guard.sh diverged** — The pipe check was implemented in
   two places (hook script + JS plugin) with different code paths and different
   early-exit conditions. The OpenCode plugin had the pipe check first (correct),
   but it didn't fire for allowed commands. The tool-guard.sh had the pipe check
   last (wrong). Neither side caught the allow-tier case.

### The fix

- **`tool-guard.sh`**: Moved the pipe check to run BEFORE `bash_allow` →
  `emit_allow`, so it catches ALL commands regardless of their allow/deny status.
  Covers Claude, Codex, Cursor, and Antigravity.

- **`policy-render.sh`**: OpenCode gets explicit `"* | head *": "deny"` patterns
  in the rendered permission config, placed AFTER allow patterns so "last match
  wins" gives deny priority. `"*":"ask"` was also moved to FIRST position so
  explicit patterns override the default.

### Rule for future "super-denies"

Any deny rule that must apply to ALL commands — not just unclassified or denied
ones — MUST be:

1. Placed before any `emit_allow` path in `tool-guard.sh`.
2. Added as explicit deny patterns in `render_opencode()` in `policy-render.sh`.
3. Tested in a script that is WIRED into `test-all-policy.sh`.
4. If it has a "not-a-pipe" exception (like `grep head file`), the exception
   test must use a command whose first token is not itself denied.

### How to prevent recurrence

- Always wire new test scripts into `test-all-policy.sh` before commit — never
  land a test that can silently fail.
- When a rule conceptually applies "before everything" (like a blanket deny),
  physically place it before the first decision point, not as an afterthought.
- Cross-harness rules must be validated in every harness's code path, not just
  the one where they were written.

---

## 2026-06-27: Deny-prefix conflict and installer merge bleed

### The bug

`"*":"ask"` was originally placed LAST in the OpenCode render. This accidentally
acted as a safety net: `du -sh /path` matched `"du *":"deny"` but then `"*":"ask"`
overrode it (last match wins), routing to the plugin which had the correct
exception logic (`/\bdu\s+-s/`). When `"*":"ask"` was moved to FIRST for the
pipe-deny fix, that safety net vanished — `"du *":"deny"` was now the last match,
and `du -s`/`du -sh` were incorrectly denied.

Same issue affected `git` — `"git *":"deny"` overrode `"git push":"ask"` and
other ask-tier git sub-commands. The issue existed silently in Claude, Cursor,
and Antigravity renders too (native deny lists there override allow lists).

**Second-order bug:** The installer used `jq '. * $p'` (recursive merge) to apply
the rendered permission fragment. When a key was REMOVED from the rendered config
(like `"git"` from denies), it survived in the live config because the merge only
OVERRIDES existing keys, it doesn't delete absent ones.

### Why it was missed

1. **Safety net masking** — The `"*":"ask"` being last was never INTENTIONAL
   safety; it was just how the render happened to work. Nobody realized it was
   the only thing preventing the deny-prefix conflict.

2. **Recursive merge assumption** — `jq '. * $p'` was assumed to "replace" the
   permission block, but it actually merges recursively. Removed keys survive.
   This worked for years because no keys had ever been removed from the policy.

3. **Testing gap** — The verify script generated its expected config using the
   SAME merge logic (`jq '. * $p'`), so both sides had the same bug and the
   drift check passed.

### The fix

- **`deny_keys_filtered()`**: New shared function in `policy-render.sh` that
  excludes deny keys that are word-prefixes of any allow or ask key (e.g. `du`
  → `du -s`, `git` → `git push`). Applied to Claude, Cursor, OpenCode, and
  Antigravity renders.

- **`del(.permission.bash)`**: Installer now deletes the old bash object before
  merging, so removed keys don't survive.

- **`verify-opencode-config.sh`**: Updated to use `del(.permission.bash)` in its
  expected config generation, so the drift check correctly catches stale keys.

### Rule for future policy changes

When changing which keys appear in the rendered permission config:

1. Check all deny keys for word-prefix conflicts with allow/ask keys.
2. The installer merge (`jq '. * $p'`) preserves target keys not in the patch —
   if removing a key, you need `del(.key)` before merge.
3. Update verify scripts to use the same merge strategy as the installer.
4. Run `verify-opencode-config.sh` (62 checks) and `test-all-policy.sh` after
   every policy render change.
