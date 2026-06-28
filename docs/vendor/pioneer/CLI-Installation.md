# CLI installation — Pioneer (mirror of https://docs.pioneer.ai/CLI-Installation.md)

Install the Pioneer CLI when you want terminal access to training jobs, model artifacts, datasets, and the interactive Pioneer agent.

Pioneer CLI is published as `@fastino-ai/pioneer-cli` and runs with Bun `1.1.0` or newer.

## Requirements
- macOS or Linux
- Bun `1.1.0` or newer
- Node.js and npm
- A Pioneer API key from Pioneer API keys

## Install
```bash
curl -fsSL https://bun.sh/install | bash    # if Bun missing
npm install -g @fastino-ai/pioneer-cli
pioneer --version
pioneer --help
```

## Authenticate
```bash
pioneer auth login      # validates the key, stores at ~/.pioneer/config.json
pioneer auth status
```
CI / shell-only: `PIONEER_API_KEY=...` env var (we use `secret-cache exec`).

## Smoke test
```bash
pioneer --version
pioneer auth status
pioneer model base-models
pioneer dataset list
```

## Update / troubleshoot
```bash
npm install -g @fastino-ai/pioneer-cli@latest
# 'pioneer: command not found' -> check `npm bin -g` is on PATH
# 'env: bun: No such file or directory' -> install Bun, open new terminal
# auth fails -> create a new API key, `pioneer auth login` again
```
