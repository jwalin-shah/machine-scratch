---
name: pioneer-api
description: Interact with the Pioneer API to manage datasets, training jobs, evaluations, and run inference. Use when the user wants to call the Pioneer API, manage ML models, start training runs, run inference, or integrate Pioneer into their workflow.
---

# Pioneer API

Base URL: https://api.pioneer.ai
Auth header: X-API-Key: YOUR_API_KEY

Get your API key: pioneer.ai -> Settings -> API Keys.
In this house we never export keys; we wrap with `secret-cache exec -- ...`.

Local docs mirror: `docs/vendor/pioneer/llms.txt` (run `ctx7 docs /websites/pioneer_ai <query>` for live lookup).
Local CLI install notes: `docs/vendor/pioneer/CLI-Installation.md`.

## Inference (Pioneer format)
POST /inference, GET /base-models (filters: ?supports_inference=true&task_type=decoder)

```bash
curl -X POST https://api.pioneer.ai/inference \
 -H "X-API-Key: $PIONEER_API_KEY" \
 -H "Content-Type: application/json" \
 -d '{
   "model_id": "job_abc123",
   "text": "Apple announced the MacBook Pro at WWDC in Cupertino.",
   "schema": { "entities": ["organization", "product", "event", "location"] },
   "threshold": 0.5
 }'
```

Schema keys (any combo): `entities`, `classifications`, `structures`, `relations`.

Decoder models: `"task": "generate"` + `"messages"` array instead of `text`+`schema`.

`model_id` = job_id from `POST /felix/training-jobs` OR a base model ID (e.g. `fastino/gliner2-base-v1`).

## Inference (OpenAI-compatible)
POST /v1/chat/completions, POST /v1/completions  (base_url = `https://api.pioneer.ai/v1`)

```bash
curl -X POST https://api.pioneer.ai/v1/chat/completions \
 -H "X-API-Key: $PIONEER_API_KEY" -H "Content-Type: application/json" \
 -d '{"model":"job_abc123",
      "messages":[{"role":"user","content":"Extract entities from: Apple launched the iPhone."}],
      "schema":{"entities":["organization","product"]}}'
```

## Inference (Anthropic-compatible)
POST /v1/messages (base_url = `https://api.pioneer.ai/v1`)

## Inference history
- GET    /inferences
- GET    /inferences/:id
- POST   /inferences/:id/feedback   (Adaptive Inference)

## Datasets
- GET    /felix/datasets
- GET    /felix/datasets/:name
- DELETE /felix/datasets/:name

## Training jobs
- POST   /felix/training-jobs
- GET    /felix/training-jobs
- GET    /felix/training-jobs/:id
- POST   /felix/training-jobs/:id/stop

```bash
curl -X POST https://api.pioneer.ai/felix/training-jobs \
 -H "X-API-Key: $PIONEER_API_KEY" -H "Content-Type: application/json" \
 -d '{
   "model_name": "my-ner-model",
   "base_model": "fastino/gliner2-base-v1",
   "datasets": [{"name": "my-dataset"}],
   "training_type": "lora",
   "nr_epochs": 5,
   "learning_rate": 5e-5
 }'
```
Status: `requested | running | complete | failed | stopped`.
Metrics on complete: `{ "f1": ..., "precision": ..., "recall": ... }`.

## Evaluations
- POST /felix/evaluations
- GET  /felix/evaluations
- GET  /felix/evaluations/:id

## Errors
| Code | Meaning |
|---|---|
| 401 | invalid or missing API key |
| 402 | insufficient credits |
| 404 | resource not found |
| 422 | validation error |
| 429 | rate limited |
| 500 | server error |

## House notes
- Provider catalog for OpenCode is wired under `pioneer/*` in `config/opencode/opencode.json`. Use the `op` launcher to start a session against Pioneer.
- Prefer the `pioneer` CLI (`npm i -g @fastino-ai/pioneer-cli`, needs Bun) for datasets/training/evals; curl only for one-offs.
- For full doc lookup, agents should `ctx7 docs /websites/pioneer_ai "<question>"` instead of re-deriving from this file.
