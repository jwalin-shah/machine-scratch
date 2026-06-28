# GitHits CLI cheatsheet (no MCP)
# Source: https://docs.githits.com/cli/commands
# Captured 2026-06-27.

## Search and package navigation

```bash
npx githits@latest search "<query>"
npx githits@latest search-status <searchRef>
npx githits@latest pkg info <spec>           # version, license, popularity, vulnerabilities, etc.
npx githits@latest pkg deps <spec>
npx githits@latest pkg changelog <spec>
npx githits@latest pkg vulns <spec>
npx githits@latest pkg upgrade-review <spec> <from> <to>
```

## Docs

```bash
npx githits@latest docs list <spec>
npx githits@latest docs read <pageId>
npx githits@latest docs read <pageId> --start-line 50 --end-line 150
```

## Code (indexed package/repo)

```bash
npx githits@latest code files <spec>
npx githits@latest code files npm:express --path-prefix src/ --extensions ts js

npx githits@latest code read <spec> <path>
npx githits@latest code read npm:express src/application.js
npx githits@latest code read npm:express src/application.js --start-line 120 --end-line 200

npx githits@latest code grep <spec> "<pattern>"
npx githits@latest code grep npm:express "Router"
npx githits@latest code grep npm:express "use\(.*middleware" --regex
```

`<spec>` examples: `npm:express`, `pypi:requests`, `cargo:serde`, or a GitHub URL like
`https://github.com/expressjs/express`.

## House notes

- We installed `npm i -g githits` so `githits ...` works without `npx`.
- We **do not** run `npx githits@latest init` (no MCP). Use the subcommands above directly.
- For repo-level recon prefer `rtk grep` / `rtk read` on local checkouts; reach for githits
  when you need real-world examples or dependency context that isn't on disk.
