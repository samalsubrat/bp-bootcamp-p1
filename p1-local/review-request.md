# Review request — P1 foundation deployment proposal

**Configuration commit for review:** `017cd5a8f057b4f05271eb1ec19997cdd8bee364` (repo `p1-local/configuration`, branch `main`)

> **Update 2026-11-19 15:45.** The classroom environment was unavailable, so the team now runs a self-hosted stand-in
> (kind cluster `p1`, Argo CD core, in-cluster Git server, Loki/Grafana; see evidence log). Commit `017cd5a8…`
> follows `98b81b63…` and resolves the interim values below: `LAB_SESSION` = `p1_subrat-20261119`,
> `LOCAL_LOKI_URL` = `http://p1-loki:3100` (reachable from cluster Pods, verified), `academy/config-revision` 1 → 2.
> Image imported into the kind node with unchanged ID `db37c67f…`. Destination namespace / Application: `p1-subrat`.
> The tables below describe the original proposal `98b81b63…`.
**Requested by:** ____ **Reviewer:** ____ **Date:** 2026-11-19

## Outcome sought

Deploy the supplied foundation page + board API (release `foundation-observe-a`) as one Deployment behind one
Service in the classroom namespace, reconciled by Argo CD from this reviewed commit, publicly labelled
`workshop-blue`.

## Source and image identity

| Item | Value |
|---|---|
| Source | `../code/app`, copied unchanged (tree checksum `c054739a…742c`); only `wwwroot/client.json` set from `guided/` |
| Client setting | `{"deadlineMs":450,"retries":0}` — supplied value kept (see `plan.md`) |
| Containerfile | `guided/Containerfile`, unchanged; base `aspnet:10.0.12@sha256:222759b3…5ad4` |
| Build | `dotnet publish` with SDK 10.0.401 (in SDK container — deviation, see evidence log), `podman build --pull=never` |
| Local image | `localhost/p1_subrat:foundation-a` → ID `db37c67f4a659db11e83c5e526a8b5f53d7e24542f45d915ed81f904d01aee2a` |
| Classroom import | **PENDING** — facilitator must import this image without rebuilding and report the runtime image ID |

## Destination

Namespace / Argo Application `P1_NAMESPACE` = **PENDING** (expected `p1_subrat`). Local classroom
Kubernetes + Argo CD only; **not** a BP Yalla deployment (approved walkthrough unavailable).

## Changed fields (vs `guided/resources.yaml`)

| Field | Value | Status |
|---|---|---|
| `image` | `localhost/p1_subrat:foundation-a` | Proposed; must equal the facilitator's imported label |
| `LAB_ENV` | `workshop-blue` | Final |
| `LAB_SESSION` | `"local"` (the app's own default) | **Interim** — replace with real `P1_SESSION` |
| `LOCAL_LOKI_URL` | `""` (empty → app writes stdout only, no Loki push) | **Interim** — replace with `P1_CLUSTER_LOKI_URL` |

Kept unchanged: resource names `foundation-settings` / `foundation`, `replicas: 1`, `DOTNET_PROCESSOR_COUNT=1`,
`academy/config-revision: "1"`. When the two interim values are replaced, the ConfigMap changes, so the same commit
must bump `academy/config-revision` to `"2"` — otherwise the running Pod keeps its old environment.

## How the configuration works

- **Service selector** `app: foundation` matches the Pod template label, so the Service's endpoints are the ready
  Pod(s) of this Deployment. (Milestone 5 breaks exactly this.)
- **Port and named target:** Service port `8080` → `targetPort: http` → container port named `http` = `8080`, which
  is where the Containerfile's `ASPNETCORE_URLS=http://0.0.0.0:8080` listens. Naming the port means the Service
  follows the container if the number changes.
- **Same origin:** page and API come from the same process/port, so the browser calls the relative path
  `/api/boards/reference` — no API hostname, no CORS.
- **`imagePullPolicy: Never`:** the node must already hold the facilitator-imported image; the kubelet never contacts
  a registry. This is a property of the prepared classroom import, not a BP registry policy. If the label does not
  match an imported image the Pod fails with `ErrImageNeverPull`.
- **Health probes:** readiness (`/healthz` every 5 s) controls whether the Pod is a Service endpoint; liveness
  (every 10 s) restarts a hung process. `/healthz` is narrow — it does not prove the board or Loki works.

## Executed checks

- Local smoke (2026-11-19, image `db37c67f…`): `/` 200 · `/healthz` 200 Healthy · reference 200 with exact body,
  `foundation-observe-a`, `workshop-blue` · missing 404 · slow 200 in 0.300 s.
- Browser: request `4d5f5a6b-67e8-47a6-ba37-d49e52130b47` received 200, matched in container stdout.
- YAML parsed; Deployment selector = Pod labels; Service selector matches Pod; targetPort resolves to a container port.
- `P1_SUBMIT_DRY_RUN=1 ../submit.sh 98b81b63…` → bare copy prepared, no placeholders (cluster not contacted).
- **Not executed:** Grafana correlation, classroom import, Argo sync — no environment session.

## Recovery plan

Known-good = this reviewed commit. If a later commit breaks the deployment, revert it (or commit a correction),
publish with `submit.sh`, `argocd --core app sync --revision <good commit>`, start a fresh port-forward and repeat the
health/API/browser/log checks. Rebuilding the image is not a repair for configuration faults.

## Decision (recorded by reviewer)

- [ ] Approved as-is  [ ] Approved for local-only use; interim values must be replaced before classroom sync  [ ] Changes requested
- Reviewer: ____ Time: ____ Comments: ____
