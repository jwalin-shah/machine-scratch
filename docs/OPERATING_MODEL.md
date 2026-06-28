# Operating Model

`machine-scratch` is the design/control repo. Nothing becomes active just
because it exists in GitHub, `examples/`, or an old bootstrap script.

## Promotion Rule

Every machine capability follows this path:

1. Review the source repo, script, config, or docs.
2. Challenge the assumption: do we actually use this, and what does it replace?
3. Decide active, reference-only, or reject.
4. If active, copy or adapt the smallest useful part into `machine-scratch`.
5. Document why it exists and how it is launched.
6. Install through an incremental script.
7. Verify without exposing secrets.

## Roles

- `machine-scratch`: current source of truth, agent rules, install fragments, status docs.
- `~/projects/examples/`: reference repos (`machine-bootstrap`, `quota-core`, etc.); not active machine state.
- `_reference` repos: material to learn from, not active machine state.

## What We Avoid

- Running `bootstrap.sh` wholesale on an existing machine.
- Exporting provider keys globally.
- Letting reference repos write into `~/.config` directly.
- Agent-level permission overrides that bypass global tool policy.
- Installing every CLI just because it exists.

## Active Install Surface

The active machine should be reproducible from reviewed fragments in this repo:

- `agent-rules/` for global agent instructions (symlinked to `~/.agent-rules`).
- `config/opencode/` for OpenCode providers and permissions.
- `config/claude/` for `claude-launch` stack (ca/cb/ctoken).
- `config/launchers/` for secret-scoped and Claude launch wrappers.
- `config/launchd/` for user LaunchAgents.
- `bin/install-active-config.sh` for non-package config installation.
- `docs/ACTIVE_MACHINE_SETUP.md` for current state.

Package installation remains explicit and reviewed separately.
