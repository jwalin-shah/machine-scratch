# Issue #1: Tool Set Design — Catalog & Ground Rules

> Status: DRAFT — grill before merge
> Research consumed: oh-my-pi hashline edits, mini-SWE-agent stateless bash, tldr-code AST analysis, AXI/TOON, Command Code tool set, Agentic Design Patterns (Gulli Ch5: Tool Use), "The New SDLC with Vibe Coding" harness engineering, Primeagen "55" workflow (7-phase, implement→revert→report cycle)

## Core principle

**A tool is a capability. A permission is a policy. The enforcement is the boundary between them.**

Every agent gets a default tool set. If it needs something outside that set, it must:
1. Request the tool
2. State the specific reason
3. Get denied or granted based on policy + context

No tool is available by default except those we explicitly design and approve.

## Primeagen constraint

**"Agents left alone produce horse crap."** — Primeagen

Every session phase has a human gate. No phase proceeds without captain approval of the previous phase's output. The dry-run phase (Primeagen Phase 4) exists specifically to catch the 20% of subtle failures that agents introduce when left to their own devices. The deviation report makes the gap visible before any code lands.

This is not anti-autonomy. It's pro-quality. The captain gates every phase, but the agent does all the work within each phase. The human provides judgment; the machine provides execution.

---

## Complete tool catalog

Organized by function. Each gets a spec: name, purpose, input schema, output format, AXI compliance level, alternatives considered, failure modes, verification gate.

### File reading

| Tool | Current | Research says | Design direction |
|---|---|---|---|
| `read` | `bat` with TOON | tldr-code extracts structure (functions, classes, imports) as separate fields, not raw lines | **Combine**: bat for full-file, tldr-code for structural extraction. AXI TOON output with pre-computed entity count. |
| `list` | `eza` with TOON | AXI principle: pre-compute aggregates (file count, dir vs file breakdown, total size) | **rtk ls** → eza + AXI enrichment. Show tree or flat, pre-compute. |
| `find` | `fd` with TOON | Simple. fd is already fast. | **rtk find** → fd TOON wrapper. Minimal. |

### Search

| Tool | Current | Research says | Design direction |
|---|---|---|---|
| `search` | `rg` with TOON | AXI: pre-compute match count, suggest narrowing query if >50 results | **rtk grep** → rg TOON wrapper. Contextual disclosure: "50+ matches, narrow with --pattern" |
| `structure` | `llm-tldr` | tldr-code is Rust, 18 languages, daemon mode, AST + call graph + data flow + taint | **Replace** llm-tldr with tldr-code wrapper. Add daemon mode for caching. |
| `impact` | `llm-tldr impact` | tldr-code has `impact` + `calls` + `whatbreaks` | **Keep** as tldr-code subcommand. |
| `semantic` | `llm-tldr semantic` | tldr-code has `semantic` with fastembed + ONNX | **Keep** as tldr-code subcommand. |

### Edit & Write

| Tool | Current | Research says | Design direction |
|---|---|---|---|
| `edit` | `fastedit` (str_replace) | oh-my-pi hashline edits: 61% fewer output tokens. Model tags lines with content hash, edits by reference. Stale anchors reject before corruption. | **Both available**. Default hashline for simple changes, str_replace for complex multi-line. Model chooses. |
| `write` | `write_file` | Standard. AXI: content truncation with size hint, `--full` escape hatch. | **AXI-compliant write**. Truncate preview, show total size, offer `--full` |

### Execution

| Tool | Current | Research says | Design direction |
|---|---|---|---|
| `shell` | `bash` | mini-SWE-agent: `subprocess.run`, stateless. Command Code: sandboxed, directory-scoped, timeout. | **Sandboxed shell**: directory-scoped, timeout (default 30s, max 600s), no network by default, no interactive processes. Output truncated at 5K tokens with `--full` escape. |
| `shell-background` | — | Long-running processes (build, deploy, test suite) | **Separate tool**: background execution with status polling. Progress pings to surface. |

### Verification

| Tool | Current | Research says | Design direction |
|---|---|---|---|
| `dry-run` | — | Primeagen Phase 4: implement → verify → revert → report deviations | **New tool**: runs the full implement → test → revert → report cycle. Input: spec + to-dos + test harness. Output: deviation report listing every place the implementation broke from the plan. |
| `verify-type` | — | tldr-code `diagnostics` wraps pyright/tsc/go vet/rustc/clippy | **New tool**: run type checker for project language. Fail if errors. |
| `verify-lint` | — | llm-tldr diagnostics wraps ruff/golangci-lint/checkstyle | **New tool**: run linter. Fail if errors above threshold. |
| `verify-test` | — | Run test suite for project | **New tool**: run `rtk pytest` / `cargo test` / `go test`. Collect results. |
| `verify-review` | — | LLM-based review layer | **New tool**: pass diff + context to review model. Return findings. |
| `verify-invariant` | — | Primeagen Phase 5: invariants — constraints that must hold after every change | **New tool**: run user-defined invariant checks (e.g. "no logic in UI layer", "all errors handled"). LLMs are bad at this — make it deterministic. |

### Context & Orchestration

| Tool | Current | Research says | Design direction |
|---|---|---|---|
| `inject-context` | — | Thread injection: summary + last 3 outcomes + tldr-code structure | **New tool**: assemble context payload for a session phase. Takes thread state, phase type, returns formatted context ≤budget. |
| `thread-status` | — | Thread state: sessions, phases, alerts, dependencies | **New tool**: query thread state. AXI TOON with pre-computed aggregates (active vs done, blockers). |
| `task` | `fm-task` | Existing. Needs labels + dependencies. | **Upgrade**: add `outcome`, `depends-on`, `label` (success/failure/unknown) |

### Enforcement

| Tool | Current | Research says | Design direction |
|---|---|---|---|
| `permission-check` | `tool-guard plugin` | **Deny by default**. Model must ask and prove need. Policy-driven. | **New tool**: atomic permission check. Input: tool name + context + justification. Output: allow/deny + reason. Used by every other tool before execution. |
| `banned-tools` | `[cat, ls, grep, find, du]` | Expand to all unapproved tools. Whitelist-only. | **Config file**: `tools.allowlist` and `tools.blocklist`. Default: deny all, allow only designed tools. |

---

## Design process per tool

Every tool follows this sequence:

1. **Spec**: name, purpose, input schema, output format, failure modes, AXI compliance level
2. **Review**: adversarial — "why this schema? why this format? what's the failure case?"
3. **Build**: implement in Zig or Go
4. **Verify**: test against spec — does it produce correct output for normal, edge, and failure inputs?
5. **Wire**: register in the tool registry, add to allowlist

**Gate**: no tool enters the system without all 5 steps completed and documented.

---

## Output format standard

All tools produce TOON by default, JSON on `--json` flag, plain text on `--text`.

AXI compliance:
- Token-efficient output (TOON) — 40% savings vs JSON
- Minimal default schemas (3-4 fields per list)
- Content truncation (preview + size hint + `--full`)
- Pre-computed aggregates (counts, summaries)
- Definitive empty states (explicit "0 results")
- Structured errors on stdout (actionable)
- Contextual disclosure (next-step suggestions)

---

## Enforcement model: deny by default, prove to unlock

### Root cause of current enforcement failure

The adversarial review (pass 2) found: **agent-level permissions override global permissions in opencode.json.**

```json
// Global: cat/ls/grep/find/du = deny ← this is correct
// Agent build: "bash": "allow" ← this OVERRIDES the global
```

Fix: remove all agent-level `"permission"` blocks from opencode.json. The global bans then take effect. No harness-level hooks needed for OpenCode — just correct config.

For Claude Code, Codex, and Cursor, the fix is **harness-level PreToolUse hooks** (Command Code pattern). The tool-guard.sh script intercepts before any tool executes.

### The permission-check flow

```
┌─────────────────────────────────────────────────────┐
│                permission-check                      │
│                                                     │
│  Input: tool_call { name, args, context }           │
│                                                     │
│  1. Is tool in allowlist?                           │
│     YES → allow (no overhead)                       │
│     NO  → continue                                  │
│                                                     │
│  2. Is tool in blocklist?                           │
│     YES → deny + suggest alternative                │
│     NO  → continue                                  │
│                                                     │
│  3. Model provided justification?                   │
│     YES → evaluate against policy                   │
│     NO  → deny: "no justification provided"         │
│                                                     │
│  4. Policy evaluation:                              │
│     ┌─────────────────────────┐                     │
│     │  Tool      │ Policy      │                    │
│     ├─────────────────────────┤                     │
│     │ git push  │ allow w/ PR │                    │
│     │ rm        │ deny always │                    │
│     │ curl      │ allow w/ URL allowlist │          │
│     │ npm       │ allow w/ registry allowlist │     │
│     └─────────────────────────┘                     │
│                                                     │
│  Output: { decision, reason, suggestion }           │
└─────────────────────────────────────────────────────┘
```

---

## Session Lifecycle: The Primeagen Cycle

Our G→P→E→V→R model is updated with Primeagen's "55" 7-phase workflow. The core innovation is Phase 4: **implement → verify → revert → report deviations**. This is not just verification — it's a **feedback loop that validates the spec itself**.

### The full lifecycle

```
THREAD (e.g. "voice latency")
  └─ TASK (e.g. "profile regression")
       │
       ├─ GRILL session ──────────────────────────────────────
       │  Input: captain intent + thread summary
       │  Output: challenged assumptions, sharpened spec
       │  Gate: captain approves spec
       │  Primeagen Phase 0-1: research + data structure definitions
       │
       ├─ PLAN session ───────────────────────────────────────
       │  Input: grill output
       │  Output: interface stubs, to-dos at every change point
       │  Gate: captain approves to-dos
       │  Primeagen Phase 2-3: interface stubs + to-do placement
       │
       ├─ DRY-RUN session (NEW — Primeagen Phase 4) ──────────
       │  Input: interfaces + to-dos
       │  Output: deviation report
       │
       │  1. Implement: follow to-dos, write the code
       │  2. Verify: run test harness (JSON mode, test suite)
       │  3. REVERT: undo ALL changes — code never lands
       │  4. REPORT: "Where did I have to break from the plan?"
       │     └─ to-dos were wrong → fix them
       │     └─ interfaces were wrong → fix them
       │     └─ structures were wrong → fix them
       │     └─ unexpected complexity found → flag it
       │
       │  Gate: deviation report accepted. If deviations found,
       │        loop back to GRILL or PLAN with findings.
       │        If clean, proceed to real implementation.
       │
       │  Primeagen: "This is the best phase. Even hand-coding
       │  it and seeing what happens — it goes 'here's all the
       │  places I had to break it.' Great way to get info back."
       │
       ├─ IMPLEMENT session ──────────────────────────────────
       │  Input: corrected spec + deviation report + to-dos
       │  Output: working code
       │  Primeagen Phase 5-6: invariants + actual implementation
       │
       ├─ VERIFY session ─────────────────────────────────────
       │  Input: code + test harness
       │  Output: pass/fail per verification layer
       │  Layers:
       │    Layer 0: llm-tldr diagnostics (non-LLM — type checkers)
       │    Layer 1: Test suite passes
       │    Layer 2: Review checks test quality (LLM)
       │    Layer 3: Reflection — what did review assume? (LLM)
       │    Layer 4: Intent — matches captain's original ask? (LLM)
       │
       └─ REPORT session ─────────────────────────────────────
          Output: PR + findings back to captain surface
```

### Key insight: DRY-RUN is the most important phase

Primeagen's Phase 4 solves the **80% problem** (the whitepaper's term for agents getting 80% right and 20% wrong in subtle ways). Instead of trying to catch that 20% in review, the agent **discovers it during the dry run** and reports it before any code lands.

The dry run:
- **Validates the spec** — if the implementation doesn't match the plan, the plan was wrong
- **Surfaces hidden complexity** — the agent finds edge cases in the spec that the captain didn't think of
- **No bad code ever lands** — the revert means every attempt is disposable
- **Teaches the captain** — the deviation report makes the captain a better spec-writer

### Two outcomes of DRY-RUN

1. **Clean**: no deviations → proceed to IMPLEMENT with confidence
2. **Deviations found** → loop back to GRILL or PLAN phase, incorporate findings, re-run DRY-RUN

No code skips the dry run. No implementation happens without a clean dry run first.

```
Phase 1: permission-check (the gate)
Phase 2: read, list, search, find (the readers)
Phase 3: edit, write (the writers)  
Phase 4: shell (the executor)
Phase 5: dry-run (implement → verify → revert → report — Primeagen Phase 4)
Phase 6: verify-type, verify-lint, verify-test (the verifiers)
Phase 7: inject-context, thread-status, task upgrade (the orchestrators)
Phase 8: verify-review, verify-invariant (the review layer)
```

Phase 1 must exist before any other tool can run — it's the gate.

---

## Show your work

For every design decision in every tool spec, we document:
- **Claim**: "hashline edits reduce output tokens by 61% vs str_replace"
- **Evidence**: oh-my-pi blog post, Can Bölük, Feb 2026 (cited)
- **Verdict**: adopt as default edit method, fall back to str_replace for complex changes
- **Verification gate**: benchmark before/after on 10 edits

No claim accepted without evidence. "I think" is not evidence.
