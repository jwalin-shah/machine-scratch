# Global Agent Contract

Behavioral rules for every coding agent on this machine.
Source of truth: `~/projects/machine-scratch/agent-rules/`.

---

## Section 1: Tool Hierarchy — use in order, stop when sufficient

1. **Structure first.** If `llm-tldr` is installed, use `llm-tldr structure <repo>` before opening more than 2 files in an unfamiliar repo. If not installed, use `rtk find`, `rtk grep`, and targeted `rtk read` slices.
2. **File ops** — use **`rtk`** subcommands first: `rtk read`, `rtk grep`, `rtk ls`, `rtk find`, `rtk git`, `rtk gh`, `rtk diff`, `rtk test`. Do **not** call raw `rg`, `eza`, `fd`, `bat`, `git`, or `gh` in bash — policy denies them. Use `du -s` for disk usage (not `dust`, which is human-oriented). Use `jq` / `yq` for structured data mutation, and `rtk json/read` for displaying JSON to the agent. Use `gtimeout`/`timeout` only to bound live smoke tests. See TOOL_REGISTRY.md.
3. **GitHub** — use `gh-axi` if installed; otherwise `gh` with compact JSON and narrow queries.
4. **Public code examples** — use `githits` (CLI) for indexed open-source search.
5. **Raw exact output** — `git` for local ops, `jq`, `yq`, small command outputs.

---

## Section 2: Reading Discipline

- Don't dump full large files. Start with structure.
- Read only relevant slices.
- macOS `head -n -N` outputs NOTHING (BSD behavior). Use `tail -n +N` or `sed`.

---

## Section 3: Editing Discipline

- Keep changes scoped to the assigned task.
- Match existing style.
- Don't add docstrings, comments, or error handling beyond what was asked.
- Remove imports/vars/functions YOUR changes made unused.
- Every changed line must trace to the user request.

---

## Section 4: Validation Discipline

- Run the smallest test that proves the change works.
- Prefer `rtk test <command>` for all test/verification scripts; use direct test commands only when `rtk test` cannot run them.
- **Counter wiring rule**: a counter that reads 0 after N>0 calls is NOT wired. Prove wiring: record before → fire action → record after → assert delta > 0.

---

## Section 5: LLM Coding Behavior

- State assumptions before implementing. Uncertain → ask.
- Multiple interpretations → present them. No silent pick.
- Minimum code that solves the problem. Nothing speculative.
- No features beyond ask. No abstractions for single-use code.
- Touch only what you must.

---

## Section 6: Collaboration Style

Direct, opinionated, one recommendation. Not every option.
Surface confusion. Don't hide it.

---

## Section 7: Secret And Provider Policy

- Provider keys come from Infisical through `secret-cache exec -- <command>`.
- Do not export provider keys globally or write them to shell startup files.
- If a required tool is not installed, say so and use the reviewed fallback.

---

## Section 8: Launchers

Short names. Use these instead of bare `opencode`, `claude`, `codex`, or `cursor-agent`.

### Claude Code (via `claude-launch`)

| Command | Route | Notes |
|---|---|---|
| `ca` | Account A (OAuth Pro) | Primary — start here |
| `ct` | TokenRouter gateway | API key resolved at launch |
| `ccp` | Pioneer gateway | Claude Code via Pioneer API |

OAuth account A needs `/login` once in `~/.claude-a`.

### OpenCode (global policy + per-profile overlay)

Global: `~/.config/opencode/opencode.json` — permissions, instructions, tool-guard, API providers.

Each launcher sets `OPENCODE_CONFIG` to a profile that overrides **model only** (config merges):

| Command | Auth | Default model | Profile |
|---|---|---|---|
| `oo` | ChatGPT Plus (OpenAI OAuth) | `openai/gpt-5.5` | `profiles/oo.json` |
| `ot` | TokenRouter API key | `deepseek/deepseek-v4-flash` | `profiles/ot.json` + secret-cache |
| `op` | Pioneer API key | `pioneer/auto` | `profiles/op.json` + secret-cache |

Global config lists **58 TokenRouter** and **56 Pioneer** models for mid-session switching in the TUI model picker. Profiles only set the startup default.

`oo` does **not** use TokenRouter. It uses the OpenAI OAuth login already in `~/.local/share/opencode/auth.json`. Run `opencode providers login` if not logged in.

### Other agents

| Command | Tool | Secrets |
|---|---|---|
| `cx` | Codex CLI | None by default |
| `cu` | Cursor Agent CLI | Cursor account auth |
| `agy` | Antigravity CLI | Own auth |

### How secrets work (current policy)

- **Launchers do not inject secrets.** Use bare commands above.
- **`secret-cache`** exists for when we add secret-scoped variants later.
- **`claude-launch`** (ca/ct/ccp) resolves profile keys from Infisical at launch — not via `secret-cache exec`.
- Do not export provider keys globally.

---

## Section 9: Known Issues

Read `~/.agent-rules/KNOWN_ISSUES.md` before any bash-heavy session.

---

## Section 10: Active vs Planned Tools

**Active now:** `rtk`, `jq`, `yq`, `du -s`, `llm-tldr`, `fastedit`, `uv`, `gh-axi`, `lavish-axi`, `chrome-devtools-axi`, `ctx7`, `cognee-cli`, `cocoindex-code`, `treehouse`, `githits`, `inf`, `pioneer`, `gtimeout`/`timeout` for bounded tests, `secret-cache`, launchers above.

**Skills (`~/.agents/skills/`):** `find-docs` (Context7), `tool-policy`, `pioneer-api`, `inference-net`. The skill catalog is injected into every OpenCode session.

**Installed infra (agents must not call directly — use rtk):** `rg`, `fd`, `eza`, `bat`, `gh`, `git`, `bun`.

**Policy: no MCP servers.** Context7, GitHits, and Inference.net all have CLI/skills modes — we use those, not their MCP variants.

**Partial / caveat:** `fastedit` — MLX+model installed; `edit` blocked until parcadei `tldr references` is on PATH (see KNOWN_ISSUES.md).

**Not installed:** `fm-tasks`.

**Deprecated names (use base CLI instead):** `githits-axi` → `githits`, `coco-axi` → `cocoindex-code`, `cognee-axi` → `cognee-cli`, `context7`/`c7` → `ctx7`.
