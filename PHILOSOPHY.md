# Machine Philosophy

> How we build and why.

## Core principles

### 1. Compose, don't build

Existing tools are better than custom builds. We wire together `llm-tldr`, `rtk`, `fastedit`, `cocoindex`, `cognee` — we don't rewrite them. Our value is in the composition layer: the guard, the router, the memory, the permission model.

A new tool must earn its place. Every binary on the machine has a documented reason. If a tool doesn't compose — if it duplicates what another tool already does — it goes.

### 2. Right tool, not fashionable tool

Bash for a stdin-filter hook. Go for a daemon. Python for data pipelines. The choice serves the problem, not a preference. If `jq` + a case switch is enough, that beats a 300-line Go rewrite. If we need persistence and state, Go is the right call.

The philosophy is not "rewrite in a compiled language." It's "use what works."

### 3. Deny by default, prove why you need it

Every tool is blocked until explicitly allowed. The model must ask for permission to use anything outside the allowlist. This applies to tool choice (what can execute) and to destructive operations (rm, sudo, keychain access).

The permission model is:
- **Allow by default** — read-only tools, analysis tools, token-efficient wrappers
- **Ask the captain** — destructive operations, secret access, network operations
- **Redirect** — suboptimal tools get redirected to their efficient alternatives

### 4. Token efficiency is a first-class constraint

Every output line costs tokens. Default schemas are 3-4 fields, not 10. Content is truncated with `--full` escape hatches. Aggregates are pre-computed so the model doesn't need follow-up calls.

Tools use AXI (Agent eXperience Interface) conventions: TOON output, contextual disclosure, definitive empty states, structured errors on stdout.

### 5. Validate with data, not intuition

Every design choice gets challenged against the session database. 1.96 million tool calls across 18,569 sessions is evidence, not opinion. We ask: do models actually use the suggested alternatives? Do they ask permission when blocked? Do redirects reduce friction or add it?

If the data contradicts the design, the design changes.

### 6. Minimum viable surface area

Models don't need 50 tools. They need 5-7 well-designed tools that compose. The core set is:

- `llm-tldr` — code analysis (structure, search, impact, diagnostics)
- `rtk` — token-efficient wrappers (ls, read, grep, find, diff, curl, wc, git, test, pip, npm)
- `fastedit` — AST-aware editing (edit, rename, delete, move)
- `coco-axi` + `cognee-axi` — code index and session memory (combined as `context`)
- `gh-axi` — GitHub interaction

Everything else is a fallback or infra.

### 7. The harness is the boundary

The guard intercepts at the harness level, not the prompt level. It's wired into PreToolUse hooks for Claude, Codex, Cursor, OpenCode. A model *cannot* bypass it by choosing a different wording — it runs before every Bash execution.

For destructive operations (rm, sudo, security, export), the guard blocks and tells the model to ask the captain. This is prompt-level enforcement, which is weaker than harness-level. We acknowledge this gap and will close it with proper permission-check middleware when the orchestration layer exists.

### 8. Iterate, don't over-spec

We design enough to build, then we test. The guard was designed in an afternoon and wired the same day. Issues and design docs capture decisions, but they're living documents — they change when real usage proves them wrong.

"More work" is not a constraint. "Normal timelines" don't exist. We do the right thing and move fast.

### 9. One command to bootstrap

A new Mac goes from clean to fully operational with one command. The bootstrap script installs brew, packages, CLIs, tools, configs, LaunchAgents, secrets, and the guard. Every tool has a reason. Nothing is installed without being in the manifest.

After bootstrap, the only manual steps are:
- Open System Settings → Privacy → Automation (grant terminal permissions)
- `infisical init` (link secrets project)
- `gh auth login` (GitHub auth)

Everything else is automated.
