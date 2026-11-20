# Milestone 1 — Plan and baseline

Status: drafted 2026-11-19 (restart). Fields marked **CONFIRM** need a real value from the team / environment session.

## Game intention (stated now, not implemented)

| | Intended later game |
|---|---|
| Action | Player moves one square (up/down/left/right) per move on the board |
| State | Player position, remaining moves (starts at `initialMoves` = 6), treasures collected, score |
| Completion | Player reaches the exit (win, score = collected treasure value) or runs out of moves (loss) |

Treasure hunt remains the reference game. **CONFIRM** or replace with your own game before milestone 2.

## Destination and review

| Item | Value |
|---|---|
| Assigned namespace / Argo Application | `P1_NAMESPACE` = **CONFIRM** (previous attempt used `p1_subrat`) |
| Classroom session label | `P1_SESSION` = **CONFIRM** |
| Reviewer of the configuration change | **CONFIRM** (peer name / facilitator) |
| Operator rotation | Milestone 1 ____ · 2 ____ · 3 ____ · 4 ____ · 5 ____ · 6 ____ |
| Intended public environment | `workshop-blue` (green is used later in the milestone 5 exercise) |
| BP Yalla | Intended target; approved CLI walkthrough unavailable → BP scaffolding/deployment **pending** |

## Parts of the system

| Part | Where | Notes |
|---|---|---|
| Page | `GET /` → `wwwroot/index.html`, `app.js`, `site.css`, `client.json` | Served by the same process; `client.json` sent with `Cache-Control: no-store` |
| API | `GET /api/boards/{id}` | `reference` 200 · `slow` 200 after 300 ms · `overdue` 200 after 900 ms · anything else 404 `NOT_FOUND` |
| Health | `GET /healthz` | `200 Healthy` (liveness only; does not check the board or Loki) |
| Environment | `LAB_ENV` → `X-Lab-Environment` header | From `runtime.env` locally, ConfigMap `foundation-settings` in the cluster |
| Release | compiled constant → `X-Lab-Release: foundation-observe-a` | Changes only with a new image |
| Logs | one JSON record per request on stdout; also pushed to Loki when `LOCAL_LOKI_URL` is set | Stream labels `job="academy-w110"`, `session=<LAB_SESSION>`; correlate by `request_id` |

## Request path

```
 Browser (page + app.js)
   │  relative path: GET /api/boards/reference   (same origin — no API hostname, no CORS)
   ▼
 127.0.0.1:18081  ── kubectl port-forward ──►  Service "foundation" :8080
                                                 │ selector app=foundation
                                                 │ targetPort "http"
                                                 ▼
                                               Pod (Deployment "foundation", 1 replica)
                                                 container :8080 ─► page (/)  and  API (/api/boards/*), /healthz
                                                 │
                                                 │ stdout JSON record  ──(separate path)──►  Loki ◄── Grafana query
                                                 ▼
                                               kubectl logs deployment/foundation
```

The browser never uses the cluster-internal name (`foundation.<namespace>.svc`). Locally the same page is reached at
`http://127.0.0.1:18080` straight from the container.

## Client deadline (`client.json`)

Supplied starting point kept: `{"deadlineMs":450,"retries":0}` → budget 450 × 1 = 450 ≤ 650.

- `reference` (0 ms server time) and `slow` (300 ms) complete inside 450 ms with headroom for transfer.
- `overdue` (900 ms) is deliberately beyond any allowed budget, so the browser reports *unavailable*.
- No retry: the fixtures are deterministic, so a retry would only repeat the same wait; a 2-retry setting would
  force `deadlineMs ≤ 216`, which would make `slow` fail every attempt.
- Fresh local check (2026-11-19): `slow` returned 200 in 0.300 s, leaving ~150 ms headroom.
- **CONFIRM** against your W1.10 recorded timings (quote one observed `elapsed_ms` for `slow`).

## Fresh smoke expectations (used in milestones 2, 4, 5)

| # | Check | Expected |
|---|---|---|
| 1 | Open the page | Loads; shows `client.json` values `{"deadlineMs":450,"retries":0}` |
| 2 | Click **Load board** with *Reference* | Outcome `received`, HTTP 200, body = `data/board-reference.json` (3×3, start (0,0), wall (1,1), treasure t1 at (2,0) value 10, exit (2,2), `initialMoves` 6) |
| 3 | `curl /healthz` | `200`, body `Healthy` |
| 4 | Release header | `X-Lab-Release: foundation-observe-a` |
| 5 | Environment header | `X-Lab-Environment: workshop-blue` (matches intended setting) |
| 6 | *Missing* fixture / `curl /api/boards/missing` | `404 {"code":"NOT_FOUND","message":"Board not found"}` — checked separately, not a failure of the release |
| 7 | Log correlation | Request ID from the browser observation appears in stdout **and** in Grafana with `{job="academy-w110", session="<P1_SESSION>"}` |

## Historical baseline

W1.10 completed observations reused as history (not re-executed here): **CONFIRM** — copy the W1.10 request ID,
elapsed time for `reference`/`slow`, and the Grafana query you used.
