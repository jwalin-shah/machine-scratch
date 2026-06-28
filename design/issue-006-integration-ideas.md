# Issue #6: Integration Ideas — LangGraph, LangChain, PromptFoo, etc.

> Status: IDEA — not grinded, not approved. Captured for future reference.

## The vision

CCC (semantic code search) + Cognee (knowledge graph memory) + thread architecture
(GRILL → PLAN → DRY-RUN → IMPLEMENT → VERIFY → REPORT) needs an orchestration layer
that routes between tools, persists state across phases, and evaluates quality.

## Candidates

### LangGraph

**What it adds**: Stateful agent graph with conditional routing, checkpointing, human-in-the-loop.
Each thread phase becomes a node. The graph decides when to call CCC vs Cognee vs both.

**Why it might be a massive unlock**:
- `cognee-integration-langgraph` already exists — `get_sessionized_cognee_tools()` gives
  drop-in `add_tool` and `search_tool` that are session-aware
- LangGraph's `create_react_agent` with Cognee tools = agent that reads/writes knowledge graph
  autonomously
- Checkpointing = resume interrupted sessions without losing context
- Human-in-the-loop = captain can approve/reject mid-graph

**Risks**:
- Adds Python dependency + graph definition overhead
- May be overkill if CLI chaining is sufficient for early stages
- Need to test whether `cognee-integration-langgraph` works with local MLX backend

### LangChain

**What it adds**: Prompt templates, model routing, tool abstractions, callbacks.
The foundation that LangGraph builds on.

**Why consider**: Already the underlying layer for `cognee-integration-langgraph`.
If we use LangGraph, we get LangChain for free. Standardizes prompt management
and model routing.

**Risks**:
- Heavy dependency tree
- LangChain's abstraction layer hides details we might want control over
- Many LangChain features overlap with what we already do in bash/CLI

### PromptFoo (promptfoo)

**What it adds**: LLM eval framework — red-teaming, regression testing, quality gates.
Compare model outputs side-by-side, detect regressions, set quality thresholds.

**Why consider**:
- Need eval to answer D4-D7 queries (success rate by model, cost per task, etc.)
- Could gate the VERIFY phase: "does this code change pass the eval suite?"
- Red-teaming prompts for each thread phase (GRILL, PLAN, etc.)

**Risks**:
- Another config surface to maintain
- Requires labeled test cases to be useful
- Best integrated after we have labeled task data from Cognee

### Others to keep on radar

| Tool | What | Why later |
|---|---|---|
| **Weave (Weights & Biases)** | Trace LLM calls, visualize graphs | After LangGraph — traces LangGraph runs |
| **Phoenix (Arize)** | LLM observability, span analysis | Alternative to Weave, open-source |
| **Inference.net (Catalyst)** | Gateway + tracing + evals | Already in stack via `inf` CLI — could replace PromptFoo |
| **CrewAI** | Multi-agent orchestration | Alternative to LangGraph — simpler but less flexible |
| **Temporal** | Durable execution, retries | For production thread architecture — if threads need reliability |

## Recommendation (not yet approved)

1. Ship CCC MCP + Cognee CLI first — prove the value without orchestration overhead
2. Add Cognee MCP second — so agents auto-use memory
3. Evaluate LangGraph when the thread architecture moves from design to build —
   specifically when we need checkpointing, human-in-the-loop, and conditional routing
   between phases
4. Evaluate PromptFoo / Inference.net evals when we have labeled task data from Cognee
   (per issue-004 timeline — minimum 100 labeled tasks)

> "Compose, don't build" — but also "don't compose until you need to."
> LangGraph, PromptFoo, etc. earn their place when CLI chaining hurts.
