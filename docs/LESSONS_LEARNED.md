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
---

## 2026-06-27: Cognee + local MLX LLM — adapter stack impedance mismatch

### The problem
Cognee's `remember` pipeline goes through LiteLLM → Instructor → provider adapter →
OpenAI client. MLX server works via curl but cognee's stack blocks it:
- OpenAI client validates API key format
- LiteLLM expects provider-prefixed model names
- Instructor retries forever on truncated structured output

### What worked
`LLM_PROVIDER=llama_cpp` bypasses LiteLLM, uses `AsyncOpenAI` directly.
Connects to MLX, extracts entities — but `max_tokens` too low for cognee's
structured output schema, causing infinite Instructor retries.

### Key lesson
Cognee env vars override stored config. Always pass PROVIDER/ENDPOINT/MODEL/KEY
as env vars. Don't fight the adapter stack — use Ollama for zero-friction.
See LLM_PROVIDER=ollama with llama3.1:8b in official docs.
---

## 2026-06-27: fastedit `--replace` matches symbol names only, not full text

### The bug

`fastedit edit --replace <symbol> --snippet <new>` matches on parsed **symbol names**
from the file (variable names, function names), NOT on the full text you provide.
Passing `--replace 'export FOO=bar'` will fail with "Symbol not found" because
fastedit doesn't search for the text — it searches for the symbol name `FOO`.

It works via AST-aware parsing: it extracts all identifiers/symbols, then replaces
their declaration. The `--replace` argument must be a single symbol token that
exists in the file's parsed symbol table (listed in the "Available" error message).

### Why it was missed

The `--replace` flag name implies text replacement. Nothing in the name or short
help suggests AST-level matching. The error message ("Symbol '...' not found") is
the only clue, and it only shows up after a failed attempt.

### The fix

Use `--replace <SymbolName>` where `<SymbolName>` is just the bare variable
or function name (e.g., `LLM_PROVIDER` not `export LLM_PROVIDER=llama_cpp`).
The snippet should contain the full declaration including `export`, value, etc.

For bulk rewrites where you need to replace full lines or blocks, use `tee`
with a heredoc instead — it's simpler and doesn't have AST constraints.

### Rule for future fastedit use

1. `--replace` takes a **symbol token** (bare name), not text to find.
2. When rewriting a whole file or block, use `tee << 'EOF'` instead.
3. When only editing a single variable declaration, `--replace` works but
   pass only the variable name.

---

## 2026-06-28: Cognee llama_cpp adapter — max_tokens not passed to API

### The bug

Cognee's `LlamaCppAPIAdapter` (llama_cpp/adapter.py) stores `self.max_completion_tokens`
in `__init__` (default 2048, overridden by `LLM_MAX_COMPLETION_TOKENS` env var, default 16384)
but **never passes it to the API call** in `acreate_structured_output`. The API call uses
`**merged_kwargs` which comes from `self.llm_args` and inline kwargs, but `self.max_completion_tokens`
is not included.

The MLX server (and most OpenAI-compatible servers) defaults `max_tokens` to 512 or 2048
when not specified. Cognee's Instructor layer then retries (doubling tokens each time to
1024, 2048...) but the model wastes tokens echoing the JSON schema ($defs/Node/Edge) in
its output, so even 2048 is often not enough.

### Why it was missed

The OpenAI adapter (`openai/adapter.py`) correctly passes `max_completion_tokens=max_completion_tokens`
in its API call. The llama_cpp adapter was written later and omitted this parameter.
Without end-to-end testing against a real server with large schemas, it looked correct
(the variable existed, the test passed initialization).

### The fix

Pass `max_tokens` via `LLM_ARGS` env var, which gets merged into the API call kwargs
via `**merged_kwargs`:

```bash
export LLM_ARGS='{"max_tokens": 16384}'
```

This works because `merged_kwargs = {**self.llm_args, **kwargs}` and `self.llm_args`
comes from `LLMConfig.llm_args`, which pydantic-settings parses from the `LLM_ARGS` env var.

### Rule for future cognee adapter debugging

1. If Instructor retries forever with "max_tokens length limit" errors from a local server,
   the adapter likely isn't passing `max_tokens` to the API.
2. Check whether `self.max_completion_tokens` is actually used in the adapter's
   `acreate_structured_output` method — it might be set but never referenced.
3. Workaround: use `LLM_ARGS='{"max_tokens": 16384}'` to push the value via kwargs.
4. The model echoing the full JSON schema in output is a separate model-behavior issue —
   `instructor.Mode.JSON` mode causes this with smaller models.

---

## 2026-06-28: Cognee Instructor mode — 8B model needs markdown_json_mode

### The problem

Cognee's llama_cpp adapter defaults to `instructor.Mode.JSON` (`json_mode`), which
expects pure JSON output. The MLX-hosted Llama 3.1 8B model wraps JSON responses
in markdown code blocks:

````
```json
{"content": "..."}
```
````

Instructor's `json_mode` can't parse this — it sees trailing characters (the closing
```` ``` ````) and raises `Invalid JSON: trailing characters at line 15 column 1`.
It retries forever because the model is consistent in its code-block-wrapping behavior.

### Why it was missed

Larger models (GPT-4, Claude 3) reliably output raw JSON without code fences.
The 8B model was never tested with cognee's Instructor pipeline. The mode setting
was left at the adapter default (`JSON`), which works for large commercial models
but not for smaller local ones.

### The fix

Set `LLM_INSTRUCTOR_MODE=markdown_json_mode` (not `md_json` — that's an invalid value).

Valid Instructor modes for local models (from `instructor.Mode` enum):
- `json_mode` — raw JSON only (default, fails with 8B models)
- `markdown_json_mode` — extracts JSON from ` ```json...``` ` blocks (works)
- `json_schema_mode` — JSON schema constrained (also works but schema-heavy)

### Rule for future local LLM + Instructor debugging

1. If Instructor fails with JSON parse errors and the model output contains markdown
   code blocks, switch to `markdown_json_mode`.
2. Valid mode strings are from `instructor.Mode` enum values. Check with:
   `python3 -c "import instructor; print([m.value for m in instructor.Mode])"`
3. Setting is via `LLM_INSTRUCTOR_MODE` env var (picked up by `LLMConfig`).
4. This applies to all smaller local models (8B and below) that tend to
   code-fence their JSON output.
