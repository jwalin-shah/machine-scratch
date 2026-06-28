# Cognee Skill

Use this skill when working with the Cognee knowledge graph system for cross-session
agent memory. Cognee stores and retrieves high-value content, relationships, and
architectural context using a local knowledge graph.

> **Cognee is a sidecar to CocoIndex, not a replacement.** Use CocoIndex/ccc for
> bulk code/transcript search. Use Cognee for curated high-value content:
> architecture decisions, cross-repo coordination, agent learnings, project context.

## Architecture

| | CocoIndex (ccc) | Cognee |
|---|---|---|
| Role | Cheap bulk vector search | Expensive knowledge graph |
| Cost | Local embeddings, no per-doc LLM | Per-document LLM call for entity extraction |
| Feed it | Whole codebases, transcripts | High-value curated content only |
| Strength | "Where is X in the code" | "How does X relate to Y" |

## Installation

Cognee is installed as a **uv tool**:

```bash
uv tool install cognee
```

CLI: `cognee-cli`

## Local Model Configuration (MLX + FastEmbed)

This machine uses **fully local models** — no external API keys needed.

### Prerequisites

The MLX LLM server must be running before using Cognee:

```bash
uv tool install mlx-lm
uv tool run --from mlx-lm mlx_lm.server --model mlx-community/Qwen2.5-7B-Instruct-4bit
```

### Environment

```dotenv
LLM_PROVIDER="openai"
LLM_MODEL="qwen2.5-7b-instruct"
LLM_ENDPOINT="http://localhost:8080/v1"
LLM_API_KEY="not-needed"
EMBEDDING_PROVIDER="fastembed"
EMBEDDING_MODEL="sentence-transformers/all-MiniLM-L6-v2"
EMBEDDING_DIMENSIONS="384"
COGNEE_SKIP_CONNECTION_TEST=true
```

## CLI Commands

| Command | Description |
|---|---|
| `cognee-cli remember <text> -d <dataset>` | Add content + build graph |
| `cognee-cli recall <query> -d <dataset>` | Query the knowledge graph |
| `cognee-cli forget --dataset <name>` | Delete a dataset |
| `cognee-cli improve -d <dataset>` | Re-process/enrich the graph |
| `cognee-cli feedback add <sid> <qid> -t "..." -s -1` | Score Q&A answers |
| `cognee-cli --user-id <uuid> remember/recall` | Multi-agent isolation |

### Session Memory

```bash
cognee-cli remember "Quick note" --session-id current-session
cognee-cli recall "What did I just learn?" --session-id current-session
```

### Query Types (`-t`)

`GRAPH_COMPLETION` (default), `RAG_COMPLETION`, `CHUNKS`, `SUMMARIES`, `CODE`, `CYPHER`

## Reference

```bash
uv tool run --from cognee cognee-cli --help
```

Docs: https://docs.cognee.ai/