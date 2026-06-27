# Issue #4: Cognee Labels & Session Analytics

> Status: DRAFT — grill before merge
> Research consumed: fm-sessiond schema (sessions + messages), Cognee docs, design-v2-research.md (D4-D7 gap), adversarial review pass 2

---

## The problem

fm-sessiond has 18,569 sessions, 1.96M tool calls, but **cannot distinguish a successful session from a failed one**. The schema has `ended_at`, `message_count`, `total_cost`, `total_input_tokens` — but no `status`, `outcome`, or `label` field.

This is the critical blocker for:
- **Watcher training**: can't train a model on unlabeled data
- **Session analytics**: can't measure completion rate, quality, or improvement over time
- **Feedback loops**: can't detect whether changes to the harness improve outcomes
- **Cost optimization**: can't tell if expensive sessions produce better results

---

## The fix: task-level labels, Cognee-based linking

Labels live at the **task level** (in fm-tasks), not the session level. Cognee links sessions to tasks. A task can span multiple sessions (one per phase). The task outcome is the label.

```
fm-tasks:                                  fm-sessiond:
┌──────────────────────┐                   ┌─────────────────────────────┐
│ task-id: voice-lat-7 │                   │ session: abc-123            │
│ project: voice       │──Cognee links──→  │   task-id: voice-lat-7      │
│ kind: ship           │                   │   phase: PLAN               │
│ outcome: success     │                   │   model: deepseek-v4-flash  │
│ pr: firstmate#47     │                   │   tokens: 12,450            │
│ created: 2026-06-27  │                   │   cost: 0.023               │
│ depends-on: stream-3 │                   └─────────────────────────────┘
└──────────────────────┘
```

No schema migration needed for fm-sessiond. The `task-id` goes into `parent_session_id` or we add a linking table in Cognee.

---

## Label sources

Where does `outcome: success / failed / abandoned / unknown` come from?

| Source | Reliability | When available |
|---|---|---|
| **PR merged** | High — proven by CI | After task completion |
| **Captain said "looks good"** | High — human judgment | After REVIEW session |
| **Captain cancelled mid-session** | Medium — might be good work they didn't need | On cancel |
| **Deviation report found critical issues** | Medium — spec was wrong, not necessarily the code | After DRY-RUN |
| **Session churn heuristic** (high message_count, no outcome, no PR) | Low — inferred, not proven | After session ends |
| **Tool violation rate > threshold** | Low — correlation, not causation | After session ends |

**Primary source**: the orchestrator sets the label after the REPORT session. If a PR was created and merged → `success`. If the captain cancelled → `abandoned`. If verification failed and task was scrapped → `failed`. Default: `unknown`.

---

## Cognee schema for task-session linking

```json
{
  "task-id": "voice-lat-7",
  "outcome": "success",
  "phases": [
    {"phase": "GRILL", "session-id": "abc-123", "tokens": 3400, "cost": 0.005},
    {"phase": "PLAN", "session-id": "def-456", "tokens": 12450, "cost": 0.023},
    {"phase": "DRY-RUN", "session-id": "ghi-789", "tokens": 28000, "cost": 0.051,
     "deviations": 2, "deviation-severity": "minor"},
    {"phase": "IMPLEMENT", "session-id": "jkl-012", "tokens": 45000, "cost": 0.087},
    {"phase": "VERIFY", "session-id": "mno-345", "tokens": 8900, "cost": 0.016,
     "layers-passed": 4, "layers-total": 4},
    {"phase": "REPORT", "session-id": "pqr-678", "tokens": 1200, "cost": 0.002}
  ],
  "total-tokens": 98950,
  "total-cost": 0.184,
  "pr-url": "https://github.com/jwalinshah/firstmate/pull/47",
  "depends-on": ["stream-3"]
}
```

---

## What Cognee enables

Once labels exist, every D4-D7 query from the original research pass becomes answerable:

| Query | Before | After |
|---|---|---|
| D4: Task completion rate by model | "can't tell" | "deepseek-v4-flash: 78% success, claude-sonnet: 84% success" |
| D5: Session dropout — where stuck? | "can't distinguish good from bad" | "42% of failed sessions stuck in EXECUTE phase, 31% in VERIFY" |
| D6: Cost per task by model | "raw averages, no quality filter" | "deepseek-v4-flash: $0.12/successful-task, claude-sonnet: $0.31/successful-task" |
| D7: Tool patterns predicting success | "correlation unknown" | "sessions with >5 rg calls in first 10 turns: 23% success. Sessions with <3: 71% success" |
| Watcher training data | "unlabeled garbage" | "labeled training set with task outcomes" |

---

## Build order

1. Add `outcome` field to fm-tasks schema (text: success/failed/abandoned/unknown)
2. Add `depends-on` field to fm-tasks schema (text[]: list of task-ids)
3. Add Cognee linking when task completes: task → phases → sessions
4. Backfill existing fm-tasks with `unknown` outcome
5. Start tracking — new tasks get real labels from orchestrator
6. Train watcher on labeled data after N tasks collected (N = 100 minimum)
