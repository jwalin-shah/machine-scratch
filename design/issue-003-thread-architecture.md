# Issue #3: Thread Architecture — Context, Lifecycle & Boundaries

> Status: DRAFT — grill before merge
> Research consumed: Agentic Design Patterns (Gulli Ch2: Routing, Ch8: Memory Management), "The New SDLC with Vibe Coding" (Context Engineering), Primeagen "55" workflow, design-v2-synthesis.md, session conversation decisions

---

## Core model

```
THREAD (stable, lives as long as the task)
  └─ TASK (created by thread from captain intent)
       ├─ GRILL session     → output: sharpened spec
       ├─ PLAN session      → output: interfaces + to-dos
       ├─ DRY-RUN session   → output: deviation report
       ├─ IMPLEMENT session → output: working code
       ├─ VERIFY session    → output: pass/fail per layer
       └─ REPORT session    → output: PR + findings
```

**Key rule: Thread dies when the task dies.** No archival policy needed. Task done → clean up worktree → thread summary kept as learning → thread closed.

---

## Thread creation

A thread is created when `fm-brief.sh` decomposes captain input into a work pack. The work pack contains:
- Project name (or EXPLORE type if no project exists)
- Task shape: **ship** (deliver a change) or **scout** (investigate and report)
- Natural-language goal from captain
- Dependency markers (if any)

If the work pack matches an existing thread (same project, same task scope), it reuses the thread. If not, a new thread is created.

**Routing confirmation gate:** Before creating a thread, the system shows the captain:
> "Starting [project] session for: [brief summary]. Correct?"

Captain says yes → proceed. No → re-brief.

---

## Context injection per session

Every session within a thread starts with a context payload assembled by `inject-context`. The payload is different per phase:

### GRILL injection
```
Thread summary (≤200t) — what this thread is about
Past outcomes (≤300t, last 3) — what happened before
Captain preferences (≤100t) — from captain.md
Project structure (≤200t) — from tldr-code tree
```

### PLAN injection
```
Grill output (≤300t) — challenged assumptions, sharpened spec
Project API surface (≤200t) — interfaces, types, stubs
Existing to-dos (≤100t) — from previous dry-run iterations
```

### DRY-RUN injection
```
Interfaces + to-dos (≤300t) — what to implement
Test harness config (≤100t) — how to verify
Deviation schema (≤100t) — what to report
```

### IMPLEMENT injection
```
Corrected spec (≤200t) — from dry-run report
Deviation report (≤200t) — what was wrong and why
To-dos (≤200t) — updated
```

### VERIFY injection
```
Code changes (≤400t) — what was implemented
Verification gate config (≤100t) — which layers to run
Intent statement (≤100t) — what captain originally asked for
```

### REPORT injection
```
Verification results (≤300t) — pass/fail per layer
Thread summary (≤100t) — to update thread
```

**1K is a guideline, not a hard limit.** The schema enforces structure, not size. If a phase needs more context, it requests more. The `inject-context` tool truncates intelligently (preserving beginning + end, summarizing middle — Liu et al. "Lost in the Middle" recall curve).

---

## Context stripping between phases

Each phase's output is a **structured contract** — not a raw conversation dump. The model writes its output into predefined fields. The next phase receives only the fields it needs.

```
GRILL output:
  ├─ spec (structured) — what we're building, sharpened
  ├─ decisions (list) — key decisions made
  ├─ open-questions (list) — what wasn't resolved
  └─ captain-intent (100t) — original ask, preserved verbatim
         ↓ stripped to: spec + captain-intent for PLAN
         
PLAN output:
  ├─ interfaces (schema) — function signatures, types
  ├─ to-dos (list) — every change point
  ├─ dependencies (list) — external things needed
  └─ risk-notes (list) — things that might go wrong
         ↓ stripped to: interfaces + to-dos for DRY-RUN
         
DRY-RUN output:
  ├─ deviations (list) — every place implementation broke from plan
  ├─ severity (enum) — minor / significant / critical
  └─ root-cause (text) — why the deviation happened
         ↓ stripped to: corrected spec + deviations for IMPLEMENT
```

**Primeagen connection:** This is context engineering. Each phase gets "the context that a skilled human developer would need to do good work" — nothing more, nothing less.

---

## Thread lifecycle rules

| Event | What happens |
|---|---|
| Captain gives new input | `fm-brief.sh` decomposes → matches existing thread or creates new |
| Captain corrects mid-task | Keep thread summary, restart session from current phase, note "why changed" |
| Captain says "scrap it" | Cancel current session, mark task failed, keep thread summary for learning |
| Thread dependency resolved | Blocked thread becomes unblocked, surfaces Q&A at recency priority |
| Task completes | Worktree cleaned up, thread summary updated, thread enters done state |
| Captain asks about past | Thread history accessible via Cognee recall, not live |

---

## Dependencies between threads

Threads are **independent units of work**. The system does not unblock threads with results from other threads — that would mean the decomposition was wrong.

Instead:
- Thread A depends on Thread B → Thread A is marked `waiting-on: thread-B`
- `fm-brief.sh` sees the dependency and routes B first
- When B finishes, A becomes unblocked
- The orchestrator surfaces B's outcome to A's context injection
- **No thread ever directly reads another thread's session**

**Circular dependency detection:** If A waits on B and B waits on A, the system detects the cycle and escalates to the captain: "These two threads have a circular dependency. Re-brief as one task?"

---

## Single captain session lock

Only one captain session is allowed at a time. No two opencode (or Claude Code, or Codex) terminals can dispatch tasks simultaneously.

Enforced by a file lock at `~/.local/share/fm-sessiond/captain.lock`. When a harness starts, it acquires the lock. If it can't, it prints:

> "Another captain session is active ([PID] since [timestamp]). Operate read-only or kill the other session."

This prevents:
- Two sessions dispatching conflicting changes to the same thread
- Split captain attention ("who approved that?")
- Worktree conflicts from parallel dispatches

---

## Direction change mid-task

Captain says "scrap that, do it this way instead."

**Policy:** Keep thread summary, restart the current session, log why the direction changed.

1. Current session receives a "direction change" signal
2. Session completes its current tool call (no abrupt kill — data loss)
3. Session writes a "why we changed" note to the thread summary
4. Thread creates a new session in the same phase as the cancelled one
5. The cancelled session's context is available via Cognee recall, but the new session starts fresh from the corrected spec

**Why restart, not resume:** Starting fresh from the corrected spec is cleaner than trying to "fix" a half-executed plan. The cancelled session's learnings (what went wrong) are preserved in Cognee for future reference.

---

## Priority: recency, then dependency

When multiple threads are blocked waiting for captain input:
1. **Recency**: whichever thread the captain just talked to goes first
2. **Dependency**: if thread A unlocks thread B (or others), A surfaces first
3. **FIFO**: otherwise, first-come-first-served

The captain never sees interleaved questions from different threads. One Q&A completes its cycle before the next surfaces.
