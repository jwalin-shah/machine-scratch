# Research Sources Index

> Evidence trail for every design decision. Every claim challenged. Nothing accepted on intuition.

---

## Source 1: Agentic Design Patterns (Gulli, 2026)

**Type:** Book (424 pages, 21 patterns)
**Author:** Antonio Gulli, Google CTO Office
**Link:** ~/Downloads/Agentic_Design_Patterns.pdf
**Consumed:** Full TOC, Ch1-2 (Prompt Chaining + Routing), Context Engineering section

### Key findings used

| Pattern | Our use | Evidence level |
|---|---|---|
| Prompt Chaining (Ch1) | G→P→E→V→R lifecycle with explicit I/O schemas per phase | Theorized (validated by Primeagen "55" in practice) |
| Routing (Ch2) | fm-brief.sh LLM-based routing with rule-based fallback | Theorized |
| Context Engineering | Per-phase context stripping, static vs dynamic context | Benchmark (Liu et al. "Lost in the Middle") |
| Human-in-the-Loop (Ch13) | Captain Q&A cycle — one focused conversation at a time | Theorized |
| Guardrails (Ch18) | Tool enforcement as deterministic harness layer | Benchmarked (Command Code PreToolUse hooks) |
| Memory Management (Ch8) | Thread context injection with layered summarization | Theorized |
| Exploration & Discovery (Ch21) | Scout mode for when captain doesn't know the scope | Theorized |

### Gaps / unproven
- No chapter directly validates multi-agent orchestration at thread level
- Patterns assume single-agent-per-task, not our phase-as-session model

---

## Source 2: "The New SDLC with Vibe Coding" (Google whitepaper, May 2026)

**Type:** Whitepaper (49 pages)
**Authors:** Addy Osmani, Shubham Saboo, Sokratis Kartakis — Google
**Link:** ~/Downloads/Day_1_v3.pdf
**Consumed:** Full paper

### Key findings used

| Finding | Our use | Evidence level |
|---|---|---|
| Agent = Model + Harness | Entire P1-P7 harness-first approach | **Benchmarked** — "Top 30 to Top 5 by harness change alone" |
| Context Engineering > Prompt Engineering | Per-phase context stripping, 6 context types | Industry practice (Google, Anthropic, OpenAI) |
| Static vs Dynamic Context | Thread injection (static) + per-phase retrieval (dynamic) | Industry practice |
| Harness changes move models Top 30 → Top 5 | Validates investing in harness over model tuning | **Benchmarked** (Terminal Bench 2.0) |
| Conductor → Orchestrator shift | Captain as orchestrator — define goals, assign, review | Industry practice |
| The 80% Problem | DRY-RUN phase catches remaining 20% | **Observed** (Primeagen confirms: "agents produce horse crap") |
| Output eval + Trajectory eval | Both necessary — neither alone sufficient | **Benchmarked** (SWE-bench methodology) |
| Factory Model | "Developer's output is the system that produces code" | Theorized |
| Token Economics | CapEx vs OpEx tradeoff, intelligent model routing | **Benchmarked** (FrugalGPT: 98% cost reduction) |

### Gaps / unproven
- Paper is principles, not implementation guide
- No specifics on session lifecycle management
- References Day 3 (Context Engineering) and Day 5 (Spec-Driven Dev) papers we haven't read

---

## Source 3: kunchenguid/firstmate

**Type:** Production system (62 commits, 310 stars)
**Author:** Kunchen Guid
**Link:** https://github.com/kunchenguid/firstmate
**Consumed:** Full AGENTS.md (18K tokens), architecture doc, README

### Key findings used

| Pattern | Our use | Evidence level |
|---|---|---|
| AGENTS.md orchestration | Declarative agent manual, not app-installed | **Production** (shipping, 310 stars) |
| Ship vs Scout task shapes | Our Decompose vs Explore | **Production** |
| treehouse worktrees | Per-session isolated worktrees | **Production** (separate Go module) |
| Event-driven bash watcher | Our trained-model watcher concept (theirs is bash) | **Production** |
| secondmates | Persistent domain supervisors | **Production** |
| no-mistakes pipeline | Our verification gate inspiration | **Production** |
| FM_HOME layout | Our state directory layout (adapted) | **Production** |

### What we do differently
- Their watcher is bash script — ours is fine-tuned model on Pioneer/inference.net
- Their captain interface doesn't clean responses — ours does
- They use tmux windows — we use OpenCode sub-sessions
- They don't have per-phase context stripping
- They don't have AXI-compliant tool output
- They don't have Primeagen's dry-run pattern

---

## Source 4: kunchenguid/axi

**Type:** Specification + implementations (1.1k stars)
**Author:** Kunchen Guid
**Link:** https://github.com/kunchenguid/axi
**Consumed:** Full README, 10 principles, benchmark results

### Key findings used

| Finding | Our use | Evidence level |
|---|---|---|
| 10 AXI Principles | Every tool output standard | **Benchmarked** — "100% success at $0.050, 40% token savings" |
| TOON format (vs JSON) | Default output format | **Benchmarked** (gh-axi: 40% token savings over JSON) |
| Pre-computed aggregates | Include counts, don't make model paginate | **Benchmarked** |
| Content truncation + `--full` | Truncate preview, show total size | **Benchmarked** |
| Contextual disclosure | Next-step suggestions after output | **Benchmarked** |
| Minimal default schemas | 3-4 fields per list, not 10 | **Benchmarked** |
| Structured errors on stdout | Actionable errors, not stack traces | **Benchmarked** |

### Concrete tools we adopt from
- **gh-axi** → our GitHub interface (100% success, $0.050 avg cost, 3 avg turns vs MCP's 6-8)
- **lavish-axi** → rich review surfaces for captain when output is complex

---

## Source 5: oh-my-pi

**Type:** Open-source harness (14.9k stars, 55K lines Rust)
**Author:** Can Bölük
**Link:** https://github.com/can1357/oh-my-pi, https://blog.can.ac/2026/02/12/the-harness-problem/
**Consumed:** Blog post, README, architecture patterns from research agent

### Key findings used

| Finding | Our use | Evidence level |
|---|---|---|
| Hashline edits (61% fewer output tokens) | Default edit method, fall back to str_replace | **Benchmarked** (author's own numbers) |
| Advisor model (second model watches every turn) | Our orchestrator + watcher pattern | Theorized |
| Hindsight memory (retain/recall) | Cognee-based session memory (inspiration) | Theorized |
| Role-based model routing (4 roles) | Our model selection per task type | **Production** |
| Subagents with structured output (schema-validated objects) | Our phase output contracts | **Production** |
| Time-traveling stream rules | Stronger enforcement than hooks — abort mid-token | Theorized (future improvement) |
| "The harness matters as much as the model" | Core thesis of our entire design | **Benchmarked** (+8% on Gemini by changing edit format alone) |

### What we do differently
- We don't use hashline exclusively — combined with str_replace for complex changes
- Our advisor model is a trained watcher, not a second LLM on every turn
- We have explicit per-phase context stripping — they have linear history

---

## Source 6: SWE-agent / mini-SWE-agent

**Type:** Research paper + open-source (19.6k stars)
**Author:** Princeton NLP + Meta
**Link:** https://arxiv.org/abs/2405.15793 (NeurIPS 2024)
**Consumed:** Paper abstract, architecture, research agent report

### Key findings used

| Finding | Our use | Evidence level |
|---|---|---|
| ACI concept (interface > model) | Tool design is our first build phase | **Benchmarked** (SWE-bench results) |
| mini-SWE-agent: bash only, stateless | Counterpoint — maybe fewer abstractions is better | **Benchmarked** (outperforms Claude Code on DeepSWE) |
| "Does not need tool-calling interface" | Validates shell-level tool design | **Benchmarked** |
| Linear history for debugging | Our per-phase output contracts | **Benchmarked** |

### What we do differently
- We opt for more structured tooling, not less (AXI, TOON, hashline edits)
- mini-SWE-agent proves simplicity works — we should validate our complexity against it
- Their "bash only" approach is a design pole we should test against

---

## Source 7: Devin (Cognition)

**Type:** Commercial product
**Author:** Cognition AI
**Link:** https://www.cognition.ai/blog/introducing-devin, https://www.cognition.ai/blog/swe-1-6
**Consumed:** Blog posts, architecture descriptions

### Key findings used

| Finding | Our use | Evidence level |
|---|---|---|
| Custom models for agent behavior | Future: train watcher model on Pioneer | Theorized (expensive, deferred) |
| "Model UX" concept | Tools should feel good to use, not just score high | Theorized |
| Parallel tool calls training | Future optimization | Theorized (deferred) |

### What we do differently
- We don't train custom models (yet). We harness-optimize existing models.
- Our approach is open-source composition, not vertical integration.

---

## Source 8: tldr-code

**Type:** Open-source CLI (Rust, 283 commits)
**Author:** Parcadei
**Link:** https://github.com/parcadei/tldr-code
**Consumed:** README, command reference

### Key findings used

| Finding | Our use | Evidence level |
|---|---|---|
| AST + call graph + data flow + taint analysis (40 commands) | Replace llm-tldr with tldr-code wrapper | **Production** |
| Daemon mode for caching | Our code analysis caching layer | **Production** |
| 18 language support | Broad project coverage | **Production** |
| `whatbreaks` — what breaks if target changes | Dependency impact analysis | **Production** |
| `contracts` — pre/post-condition inference | Invariant detection (Primeagen Phase 5) | **Production** |

### Gaps
- Not installed yet on current machine
- Need to benchmark against llm-tldr for token efficiency

---

## Source 9: Command Code (commandcode.ai)

**Type:** Commercial product
**Author:** Ahmad Awais
**Link:** https://commandcode.ai/docs/hooks
**Consumed:** Full hooks documentation, tools reference, taste docs

### Key findings used

| Finding | Our use | Evidence level |
|---|---|---|
| PreToolUse hooks — deny before execution + inject context | Our enforcement mechanism pattern | **Production** |
| Stop hooks — quality gate at end of turn | "Don't finish with violations" gate | **Production** |
| `additionalContext` injection — feed enforcement reasons to model | Model learns not to retry | **Production** |
| Harness-level enforcement works for any model (DeepSeek, Claude, GPT) | Model-independent tool design | **Benchmarked** (DeepSeek V4 "insanely better" via harness) |
| taste-1 neuro-symbolic model | Future: captain taste learning | Theorized (deferred) |

### What we do differently
- Our tool-guard is currently agent-level (opencode.json config) — needs to match Command Code's harness-level approach
- We add Primeagen's dry-run pattern — Command Code doesn't have this
- We add per-phase context stripping — Command Code doesn't do this

---

## Source 10: Primeagen "55" Workflow

**Type:** Talk / personal workflow demonstration
**Author:** Primeagen (Twitch/YouTube)
**Link:** https://github.com/Primeagen/55
**Consumed:** Full talk transcript

### Key findings used

| Finding | Our use | Evidence level |
|---|---|---|
| 7-phase workflow (research → structures → interfaces → to-dos → dry-run → invariants → implement) | Our G→P→D→I→V→R lifecycle | **Observed** (works in practice for Primeagen) |
| Phase 4: implement → verify → revert → report | Our DRY-RUN session — validates spec, not code | **Observed** (Primeagen: "This is the best phase") |
| "Agents left alone produce horse crap" | Every phase has a human gate | **Observed** |
| Human gates every phase — don't proceed if structures/interfaces/to-dos aren't correct | Captain approval at every phase boundary | **Observed** |
| JSON mode for test harness | Programmatic verification that doesn't depend on ML | **Production** |
| Deviation report reveals spec gaps | Solves the 80% problem before code lands | **Observed** |
| LLMs horrible at invariants (Phase 5) — make them deterministic | `verify-invariant` must be deterministic, not ML | **Observed** |
| Cloud handoff — send worktree to cloud, finish on phone | Future: cloud sync for captain mobility | Theorized (deferred) |

---

## Source 11: MCP Anti-Patterns (Daniel Oh, IBM, CNCF)

**Type:** Conference talk
**Author:** Daniel Oh, CNCF Ambassador, Java/Cloud AI Lead at IBM
**Link:** Agentic AI Foundation Summit, 2026
**Note:** Talk transcript provided by user

### Key findings used

| Finding | Our use | Evidence level |
|---|---|---|
| **Single-Consumer Trap:** when one agent talks to one tool, function calling is faster and cheaper than MCP | Validates our AXI-over-MCP choice for most tools | **Benchmarked** (20ms direct vs 200ms+ through MCP) |
| **Performance Overhead:** MCP adds 10x latency (multi-hop networking, JSON-RPC, observability layers) | We use direct CLI with AXI wrappers, not MCP | **Benchmarked** |
| **Token Math:** 50 tokens direct function call vs 500-1,500 simple MCP vs 2,000+ complex MCP | AXI/TOON is the right call — 50 tokens per tool call is our goal | **Benchmarked** |
| **Mega-Server Anti-Pattern:** giant all-in-one MCP server is the new monolith | Our tools are independent binaries, not one monolith | **Observed** |
| **Micro-MCP:** break MCP servers apart like microservices | If we ever need MCP, this is how | **Observed** |
| **5-Point MCP Checklist:** distribution, discoverability, multi-team delivery, context-window pressure, clean API design — 3+ yeses = MCP makes sense | Our current design gets 0-1 yeses — validates not using MCP | **Observed** |
| **Garbage In, Garbage MCP:** messy API schema through MCP amplifies the mess | Our tools have clean, designed I/O from day one | **Observed** |
| **MCP is not a security layer** — cramming auth/rate-limiting/zero-trust into MCP makes it heavier | Our permission-check is a separate layer, not embedded in transport | **Observed** |
| "Plan the sunset" — every MCP server should ship with a retirement plan | Every tool must have a documented reason for existing | **Observed** |

### Impact on our design
This talk directly validates our **AXI-first, MCP-last** approach:
- Our tools are direct CLIs with TOON output (50-token cost bracket)
- We only reach for MCP when we need discoverability or multi-team delivery (neither relevant for Jwalin's personal setup)
- If we ever need MCP (e.g., for a shared team tool), we use micro-MCP pattern, not mega-server

---

## Source 12: fm-sessiond (our data)

**Type:** Production database
**Schema:** sessions(id, account, project, agent, model, provider, started_at, ended_at, message_count, tokens, cost, parent_session_id) + messages(id, session_id, role, model, content_preview, tokens, cost, has_tool_use, has_thinking)
**Location:** ~/.local/share/fm-sessiond/sessions.db

### Key findings

| Metric | Value |
|---|---|
| Total tool calls | 1.96 million (in scope) |
| Total sessions | 18,569 |
| Banned tool violations | 276,423 |
| Hook enforcement blocks | 1,040 (<0.4%) |
| rtk adoption (weekly, current) | 45.3% |
| Tool compliance trend | Flat — no improvement from hooks alone |
| Context waste (avg) | 3M tokens per session — massive |
| Session success/failure labels | **MISSING** — cannot distinguish good from bad |
| gpt-5.5 bias | 5,175/9,161 sessions — training data skewed |

### What this tells us
- **Enforcement is broken** — 0.4% block rate proves agent-level config doesn't work. Need harness-level (Command Code pattern).
- **Training data is garbage** — can't train watcher on unlabeled data. Labels are critical blocker.
- **Context waste is epidemic** — 3M avg tokens per session validates per-phase stripping as essential.
- **Fix order**: enforcement first → labels second → watcher training third.

---

## Evidence Traceability Matrix

| Design Decision | Source(s) | Level |
|---|---|---|
| Harness-first approach | Whitepaper §Harness Engineering + oh-my-pi blog | Benchmarked |
| Tool enforcement at harness level | Command Code hooks + Daniel Oh MCP talk | Benchmarked |
| Deny by default, prove to unlock | Daniel Oh MCP checklist + Primeagen constraint | Observed |
| AXI/TOON output over MCP | Daniel Oh token math (50 vs 500+) + gh-axi benchmarks | Benchmarked |
| G→P→D→I→V→R lifecycle | Gulli Prompt Chaining + Primeagen 55 | Observed |
| Per-phase context stripping | Gulli Context Engineering + "Lost in the Middle" | Benchmarked |
| DRY-RUN session (implement→revert→report) | Primeagen Phase 4 + Whitepaper 80% problem | Observed |
| Human gate every phase | Primeagen constraint + Gulli Human-in-the-Loop | Observed |
| Recency-based priority | Session conversation decision | Theorized |
| Thread = task lifecycle | Session conversation decision | Theorized |
| Cognee labeling (task-level, session-linked) | Session conversation decision | Theorized |
| Watcher as trained model (not bash) | firstmate bash watcher + Pioneer/inference.net free training | Theorized |
| Hashline + str_replace edits | oh-my-pi hashline (61% fewer output tokens) | Benchmarked |
| tldr-code over llm-tldr | tldr-code has 40+ commands, 18 languages, daemon mode | Production |
| model-agnostic tool design | Command Code + Daniel Oh — harness works for any model | Benchmarked |
| Context injection ≤1K guideline | "Lost in the Middle" U-shaped recall curve | Benchmarked |
| Session labels must exist first | fm-sessiond data: unlabeled = train on garbage | Production |


## Sources not yet consumed

| Source | Why relevant | Priority |
|---|---|---|
| Day 3 paper: Context Engineering, Sessions, Skills & Memory | Referenced in SDLC whitepaper — more on context management | High |
| Day 5 paper: Spec-Driven Production Grade Development | Referenced in SDLC whitepaper — code review patterns | Medium |
| Aider repo-map benchmark | How aider handles context injection | Medium |
| LangChain harness study (+13.7 points) | Detailed evidence of harness effect | Medium |
| FrugalGPT paper (Chen et al. 2023) | Model routing cost optimization | Low (sufficiently validated) |
| Liu et al. "Lost in the Middle" (2023) | Context window recall curve | Low (well-known) |
| PRM / Lightman et al. (2023) | Process supervision for verification | Low (well-known) |
