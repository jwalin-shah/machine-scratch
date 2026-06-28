# Verify OpenCode Config

Two layers: **automated structural checks** (no session needed), then **live
session checks** (proves the agent actually listens).

## 1. Automated (run first)

One command runs everything that does not need a chat session:

```bash
rtk test ~/projects/machine-scratch/bin/test-opencode.sh
```

Or step by step:

```bash
~/projects/machine-scratch/bin/install-active-config.sh   # after any config edit
rtk test ~/projects/machine-scratch/bin/verify-opencode-config.sh
rtk test ~/projects/machine-scratch/bin/test-opencode-permissions.sh
rtk test ~/projects/machine-scratch/bin/test-opencode-profiles.sh
```

Checks: config not drifted, profiles valid, permissions deny `cat`/`ls`/…, tool-guard
plugin + hook behavior, approved tools execute, 58 TokenRouter + 56 Pioneer models,
`oo`/`ot`/`op` profile merge.

Exit 0 = safe to proceed to live tests.

**Live agent probes** (network + tokens):

```bash
rtk test ~/projects/machine-scratch/bin/test-opencode-live.sh ot --quick
rtk test ~/projects/machine-scratch/bin/test-opencode.sh --live oo   # install + all + live oo
```

## 2. Profile smoke (no chat, per launcher)

Each launcher sets `OPENCODE_CONFIG` to its profile. Confirm merge + model:

```bash
# oo — ChatGPT Plus, gpt-5.5
OPENCODE_CONFIG=~/.config/opencode/profiles/oo.json opencode debug config | jq '{model, instructions}'

# ot — TokenRouter, deepseek v4 flash
OPENCODE_CONFIG=~/.config/opencode/profiles/ot.json opencode debug config | jq '{model, instructions}'

# op — Pioneer
OPENCODE_CONFIG=~/.config/opencode/profiles/op.json opencode debug config | jq '{model, instructions}'
```

All three should still show `instructions` from global config and the correct
`model` from the profile.

Prerequisites:

| Launcher | Before first use |
|---|---|
| `oo` | `opencode providers login` (OpenAI OAuth / ChatGPT Plus) |
| `ot` | `secret-cache refresh` (TokenRouter key) |
| `op` | `secret-cache refresh` (Pioneer key) |

## 3. Live session (proves enforcement + auth)

Mid-session model switch: use the TUI model picker — all TokenRouter and Pioneer
models from global config are listed there when you launched via `ot` or `op`.

### Permission test prompts (copy-paste)

Run these in order in any session (`oo`, `ot`, or `op`). Each tests one layer.

**Should be DENIED** (agent must not run the command; should suggest alternative):

```
Run exactly this bash command and show me the output: cat README.md
```

```
Run exactly this bash command: ls -la
```

```
Run exactly this bash command: grep -r launcher .
```

```
Run exactly this bash command: find . -name '*.json'
```

```
Run exactly this bash command: export FOO=bar && echo ok
```

**Should be ALLOWED** (command runs, you get results):

```
Run exactly this bash command: rtk grep launcher ~/projects/machine-scratch
```

```
Run exactly this bash command: rtk ls ~/projects/machine-scratch
```

```
Run exactly this bash command: rtk read ~/projects/machine-scratch/README.md
```

**What success looks like for denials:**
- Permission denied before output appears
- Agent retries with `rtk read`, `rtk ls`, `rtk grep`, or `rtk find` instead
- No file contents from `cat`, no directory listing from bare `ls`

**What success looks like for allows:**
- Command executes
- Real output returned (file paths, file content slices, etc.)

### oo (ChatGPT Plus)

```bash
oo
```

1. Confirm TUI shows model **gpt-5.5** (OpenAI provider).
2. Ask: *Run `cat README.md` and show the output.*
   - **Expect:** denied; agent uses `bat --plain`, `rtk read`, or `rg`.
3. Ask: *Search for "launcher" with rtk grep in machine-scratch.*
   - **Expect:** allowed; results returned.

### ot (TokenRouter)

```bash
secret-cache refresh   # if verify script warned
ot
```

1. Confirm model **deepseek/deepseek-v4-flash** (TokenRouter).
2. Same permission tests as oo (`cat` denied, `rtk grep` allowed).
3. Send any short prompt — **Expect:** response (proves TokenRouter auth works).

### op (Pioneer)

```bash
op
```

1. Confirm Pioneer provider / `pioneer/auto` model.
2. Short prompt — **Expect:** response.

## 4. What a denial looks like

When the agent tries a blocked command:

- Command does not run
- UI shows permission denied
- Tool-guard may add: *Use rtk read instead of cat* (etc.)
- Agent should retry with an approved tool

## Test runtime notes

Live tests are bounded with `gtimeout` when Homebrew `coreutils` is installed. Do not add coreutils `gnubin` to agent PATH; GNU aliases like `gcat`, `gls`, `ggrep`, and `gfind` are policy bypasses and should remain denied.

The OpenCode plugin is ESM; the installer writes `~/.config/opencode/package.json` with `{ "type": "module" }` to keep Node from warning about module type.

## 5. After changing machine-scratch config

```bash
~/projects/machine-scratch/bin/install-active-config.sh
rtk test ~/projects/machine-scratch/bin/verify-opencode-config.sh
```

Then re-run the live checks for whichever launcher you changed.
