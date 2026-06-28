# CocoIndex-Code (ccc) Skill

Use this skill for indexing and semantically searching codebases using the
**ccc** CLI tool. This is the code-indexing sidecar — cheap bulk vector search
for code, transcripts, and ledgers.

> **ccc is the bulk indexer.** Use it for whole codebases and transcripts.
> Cognee is the knowledge graph — use it for curated high-value content like
> architecture decisions and agent learnings.

## Installation

Installed as a **uv tool**:

```bash
uv tool install cocoindex-code
```

CLIs: `ccc` (primary), `cocoindex-code` (MCP server — use `ccc` instead)

## Quick Start

### Initialize (one-time)

```bash
ccc init
```

This creates global settings at `~/.cocoindex_code/global_settings.yml` and
starts the daemon.

### Index a Project

```bash
cd /path/to/project
ccc index
```

This builds/refreshes a semantic search index for the project. Subsequent runs
are incremental — only changed files are re-indexed.

### Search

```bash
ccc search "how does authentication work"
ccc search "what is the entry point" --top-k 10
```

### Structural Grep (no index needed)

```bash
ccc grep "def handle_"     # find functions matching pattern
ccc grep "class.*Config"   # find classes matching pattern
```

This grep is semantic-aware — it understands code structure.

### Check Status

```bash
ccc status                 # show indexed projects and stats
ccc doctor                 # system health check
```

## CLI Reference

| Command | Description |
|---|---|
| `ccc init` | Initialize global settings and daemon |
| `ccc index` | Build/refresh index for current project |
| `ccc search <query>` | Semantic search across indexed code |
| `ccc grep <pattern>` | Structural grep (no index needed) |
| `ccc status` | Show project/index status |
| `ccc reset` | Reset databases and optionally remove settings |
| `ccc doctor` | System health check |
| `ccc mcp` | Run as MCP server (use `cocoindex-code serve` instead) |
| `ccc daemon` | Manage the daemon process (start/stop/status) |

## Architecture: ccc + Cognee + CocoIndex Library

| Tool | Role | CLI |
|---|---|---|
| **ccc** (cocoindex-code) | Bulk code/transcript vector search | `ccc` |
| **Cognee** | Knowledge graph for relationships | `cognee-cli` |
| **CocoIndex library** | Build custom data pipelines (embeddings, ETL) | `cocoindex` |

## Daemon

`ccc` runs a background daemon (`~/.cocoindex_code/`) that manages indices.
The daemon starts automatically on first `ccc init` / `ccc index`. Check logs:

```bash
ccc doctor                          # check daemon health
cat ~/.cocoindex_code/daemon.log    # daemon logs
```

## Reference

```bash
ccc --help
ccc <command> --help
```