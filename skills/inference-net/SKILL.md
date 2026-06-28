---
name: inference-net
description: Use Inference.net (Catalyst) to route LLM calls through the Gateway, capture OpenInference-shaped traces, run evals/rubrics, build datasets from traffic, and fine-tune/deploy models. Trigger this when the user asks about `inf` CLI, the Catalyst gateway/tracing, HALO, model evals, or instrumenting an app for observability.
---

# Inference.net (Catalyst)

Base URL: https://api.inference.net (Catalyst Gateway is OpenAI-compatible)
CLI binary: `inf` (`@inference/cli`, installed globally)
Auth: `inf auth login` or `INFERENCE_API_KEY=...` (we wrap with `secret-cache exec`).

Local docs mirror: `docs/vendor/inference-net/llms.txt`.

## What you get

| Mode    | What it does |
|---------|--------------|
| Gateway | Route every LLM call through the Catalyst proxy -> cost/latency/usage land in Observe. |
| Tracing | Install the Catalyst tracing SDK + spans around agents/tools/provider calls (OpenInference shape). |
| Both    | Gateway routing first, then trace collection - single agent session. |

## Day-one commands

```bash
npm install -g @inference/cli       # once
inf auth login

inf project list
inf models                          # browseable model/provider/pricing catalog
inf trace list
inf trace tree <id>
inf span search <query>
inf inference list --task <id>
inf eval ...                        # rubrics, runs, results
inf dataset upload data.jsonl
inf training ...                    # queue runs / monitor / logs
inf halo run                        # HALO agent-trace analysis
inf dashboard                       # interactive TUI
```

## Instrument an app (agent-driven)

`inf instrument` hands the diff to a coding agent (Claude Code, OpenCode, Codex).
House default: drive it from OpenCode.

```bash
cd /path/to/project
inf instrument --agent opencode      # or --dry-run / --print-prompt
```

The CLI fetches the official instrumentation skill, builds a prompt, and the
agent makes the gateway + tracing edits. Review the diff before applying.

## Gateway calls (OpenAI-compatible proxy)

```bash
curl https://api.inference.net/v1/chat/completions \
  -H "Authorization: Bearer $INFERENCE_API_KEY" \
  -H "Content-Type: application/json" \
  -H "x-inference-provider: openai" \
  -H "x-inference-provider-api-key: $OPENAI_API_KEY" \
  -d '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"hi"}]}'
```

Useful gateway headers:

| Header                          | Purpose |
|--------------------------------|---------|
| `x-inference-provider`         | `openai`, `anthropic`, `groq`, `cerebras`, `gemini`, `vertex`, `openrouter`, ... |
| `x-inference-provider-api-key` | Downstream provider key (`x-api-key` for Anthropic-native SDK). |
| `x-inference-provider-url`     | Any OpenAI-compatible base URL even without a named integration. |
| `x-inference-environment`      | `production`, `staging`, ... |
| `x-inference-task-id`          | Groups requests under a task (`inf inference list --task ...`). |

## Tracing (TypeScript / Python OpenInference SDKs)

Idiom: memoize `setup()` per long-lived process, wrap work in `agentSpan`/`agent_span`,
call `shutdown()` on `SIGTERM` (short-lived) or `forceFlush()` per invocation (serverless).

See `docs/vendor/inference-net/llms.txt` traces section for the full integration list
(Vercel AI SDK, OpenAI Agents, LangChain, LangGraph, Claude Code, OpenCode, Cursor SDK,
Pydantic AI, LiveKit, ElevenLabs, ...).

## HALO

`inf halo run` analyzes captured traces and produces a markdown report.
In CI: `inf halo schedule` then `inf halo report pull`.

## House notes
- Keys live in Infisical -> injected via `secret-cache exec -- inf ...` (never `export`).
- Prefer `inf` CLI over hand-rolled curl when browsing traces/inferences - cheaper output.
- The Catalyst MCP exists but we use the CLI + this skill instead (no MCP policy).
