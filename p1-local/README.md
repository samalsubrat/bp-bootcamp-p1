# Project 1 handover README (team: p1-subrat)

Status key: **executed locally (date)** · **executed on self-hosted stand-in (date)** · **pending** · **unavailable on BP**.

> **Read this first.** The facilitator's classroom environment (session variables, cached images, prepared cluster,
> Argo CD Application, Git server, Loki/Grafana) was **unavailable**. Everything marked "self-hosted stand-in" ran on
> a kind cluster, Argo CD core, an in-cluster Git server and Loki/Grafana that the team set up on this Windows machine
> (Podman). It follows the brief's workflow but is **not** classroom evidence and **not** BP evidence. Every deviation is
> listed in [evidence-log.md](evidence-log.md).

## Starting files and source version

* Supplied application copied from `../code/code/app` **unchanged**. Tree checksum (sha256 over the per-file sha256 list,
  `find . -type f | sort | xargs sha256sum | sha256sum`): `c054739a02738cc5aa9641798a78f9629d9c81b61769f5829903e25b7bc3742c`.
  Release compiled in: `foundation-observe-a`.
* Files we own (copied from `../guided/`): `app/wwwroot/client.json`, `runtime.env`, `Containerfile` (unchanged),
  `configuration/app/resources.yaml`, `submit.sh` (one-line Windows `kubectl cp` fix, see below).
* Added by the team: `session.sh` (self-hosted session), `observability/` (Loki + Grafana), `verify.sh` (fresh
  deployed-result check), `plan.md` (milestone 1), `review-request.md`, `milestone5.md`. Stand-in cluster files are in
  `../p1-cluster/`.

## Prerequisites

| Item | Version used | Notes |
|---|---|---|
| Podman | 6.1.4, machine **rootful** (`podman machine set --rootful`) | kind needs rootful Podman |
| .NET SDK | 10.0.401 in container `mcr.microsoft.com/dotnet/sdk:10.0.401` | no host SDK on this machine (deviation) |
| ASP.NET base | `mcr.microsoft.com/dotnet/aspnet:10.0.12@sha256:222759b3…5ad4` (local ID `d61417333cee`) | pulled once by digest (no classroom cache) |
| kubectl / kind / argocd | v1.33.2 / v0.29.0 / v3.0.6 in `../p1-tools/` (checksums verified) | put on PATH by `session.sh` |
| Shell | Git Bash or MSYS2 UCRT64 | `session.sh` sets `MSYS2_ARG_CONV_EXCL` |

Session variables (names only; no secrets): `P1_NAMESPACE`, `P1_IMAGE`, `P1_SESSION`, `P1_LOCAL_LOKI_URL`,
`P1_CLUSTER_LOKI_URL`, `P1_HOST_LOKI_URL`, `P1_GRAFANA_URL`, `P1_REPO_NAMESPACE`, `P1_REPO_POD`. Load with
`. ./session.sh` from `p1-local`. Kubeconfig stays in `~/.kube/config` (written by kind) and is **not** part of the
submission.

## Build and image identity (executed locally 2026-11-19)

From `p1-local` in bash:

```bash
export MSYS2_ARG_CONV_EXCL='*'     # Windows shells only: stop container paths being rewritten
podman run --rm -v "$(cygpath -m "$PWD"):/src" -w /src mcr.microsoft.com/dotnet/sdk:10.0.401 \
  dotnet publish app/Foundation.csproj -c Release -o publish --nologo
podman build --pull=never -f Containerfile -t localhost/p1_subrat:foundation-a .
podman image inspect localhost/p1_subrat:foundation-a --format '{{.Id}}'
```

On a machine with the classroom .NET SDK, use `dotnet publish app/Foundation.csproj -c Release -o publish --nologo` directly.

| Identity | Value |
|---|---|
| Image label | `localhost/p1_subrat:foundation-a` |
| Local image ID | `db37c67f4a659db11e83c5e526a8b5f53d7e24542f45d915ed81f904d01aee2a` |
| Runtime image ID in cluster (`crictl inspecti`, Pod `imageID`) | `sha256:db37c67f4a659db11e83c5e526a8b5f53d7e24542f45d915ed81f904d01aee2a`, the same image |
| Import method (stand-in for facilitator) | `podman save` → `kind load image-archive … --name p1` (no rebuild) |

## Public configuration

* `LAB_ENV`: started `workshop-blue`; **currently `workshop-green`** (milestone 5c, commit `08c8f5e1…`).
* `client.json`: `{"deadlineMs":450,"retries":0}`, the supplied value (450 × 1 ≤ 650). `slow` (300 ms server time)
  returned in 0.300 s, so 450 ms leaves ~150 ms headroom; `overdue` (900 ms) is unavailable by design; retries would
  force `deadlineMs ≤ 216` and make `slow` always fail. Reasoning in [plan.md](plan.md).
* Same-origin routing: the page calls the relative `/api/boards/reference`; page and API share one process and port
  8080, so no API hostname or CORS is involved.
* Service `foundation`: selector `app: foundation` (= Pod template label), port `8080` → `targetPort: http` (container
  port named `http` = 8080, the Containerfile's `ASPNETCORE_URLS`). `imagePullPolicy: Never` = image must already be
  imported into the node (prepared-import property, not a BP registry policy). Readiness/liveness probe `/healthz`.

## Deployment revision and review

Configuration repo: `configuration/` (branch `main`), one file `app/resources.yaml`.

| Commit | Purpose | Review |
|---|---|---|
| `98b81b633bf70d04757f52b4a0c0e45b51510301` | Proposal: image + blue; interim session/Loki | [review-request.md](review-request.md), decision **pending** |
| `017cd5a8f057b4f05271eb1ec19997cdd8bee364` | Session `p1_subrat-20261119`, cluster Loki, config-revision 2: **known-good** | decision **pending** |
| `1653f1b32488aede4b461d30d336533602fc44c0` | Controlled failure: selector `app: foundation-missing` | [milestone5.md](milestone5.md) |
| `54083be54de646c6a9af2fda19b9bcc1806001d9` | Revert of the failure (tree = `017cd5a8`) | milestone5.md |
| `08c8f5e1342241f45506e9beff318042691f4cd7` | `LAB_ENV` green, config-revision 3: **currently deployed** | milestone5.md |

Argo CD (self-hosted stand-in, 2026-11-20): Application `argocd/p1-subrat`, manual sync, last sync revision
`08c8f5e1…`, **Synced, Healthy**. No BP pull request or hosted CI was executed.

## Startup and verification

### Self-hosted environment (once per machine; stand-in for the facilitator's preparation)

```bash
cd p1-local && . ./session.sh                     # PATH, KIND_EXPERIMENTAL_PROVIDER, variables
kind create cluster --name p1                     # rootful Podman machine required
kubectl config set-context --current --namespace=argocd
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.0.6/manifests/core-install.yaml
podman build -t localhost/p1-git-server:2 ../p1-cluster/git-server
podman save -o ../p1-images/git-server.tar localhost/p1-git-server:2
kind load image-archive ../p1-images/git-server.tar --name p1
kubectl apply -f ../p1-cluster/git-server.yaml -f ../p1-cluster/application.yaml
podman save -o ../p1-images/foundation-a.tar localhost/p1_subrat:foundation-a
kind load image-archive ../p1-images/foundation-a.tar --name p1     # "facilitator import"
./observability/up.sh                               # Loki :3100, Grafana :3000, local app :18080; joins Loki to kind
. ./session.sh                                      # re-read P1_REPO_POD
```

### Deploy a reviewed commit (milestone 4 workflow)

```bash
cd configuration && P1_REVISION=$(git rev-parse HEAD)     # run submit.sh from HERE, as ../submit.sh
../submit.sh "$P1_REVISION"
argocd --core app sync "$P1_NAMESPACE" --revision "$P1_REVISION"
argocd --core app wait "$P1_NAMESPACE" --sync --health --timeout 90
kubectl -n "$P1_NAMESPACE" get deployment,pods,service,endpointslices
cd .. && ./verify.sh 18082 <evidence-prefix> <expected-env>   # fresh port-forward + all checks below
```

`kubectl port-forward service/foundation` connects localhost → Kubernetes API server → kubelet → the Pod the Service
selects, on port 8080. It checks Service selection and port mapping; it is **not** a public BP ingress.

### Evidence (actual)

| Check | Command | Expected | Actual (time UTC, request ID) |
|---|---|---|---|
| Health | `curl /healthz` | 200 Healthy | local 2026-11-19 15:12 ✔; cluster 2026-11-20 04:02 ✔ (`cluster-health.txt`), green 04:07 ✔ |
| Reference | page + `/api/boards/reference` | 200, 3×3, 6 moves, `foundation-observe-a`, env | local curl `3da3d592-7ae1-4318-b539-896683194865`; local **browser** `4d5f5a6b-67e8-47a6-ba37-d49e52130b47` and `d8abb88e-68a5-4518-8f60-57db6e2c2447`; cluster curl `93b26d72-a8cb-4787-8055-953f02c67341` (blue); green `309c97c7-3379-4c79-a4bc-17b6ad4cd074` (`workshop-green`). Body identical to `data/board-reference.json` every time. Cluster **browser** click: **pending** |
| Missing | `/api/boards/missing` | 404 NOT_FOUND | ✔ local and cluster (`local-missing.txt`, `cluster-missing.txt`) |
| Grafana | `{job="academy-w110", session="p1_subrat-20261119"} \| json \| request_id="…"` | matching row | local browser `d8abb88e…` seen by the learner in Grafana Explore; cluster `93b26d72…`, `36ff858b…`, `309c97c7…` via the Grafana Loki datasource (`*-grafana-query.json`) |

## Controlled failure and recovery (self-hosted stand-in, 2026-11-20). Details in [milestone5.md](milestone5.md)

* **Bad revision** `1653f1b3…`: Service selector → `app: foundation-missing`. **Prediction:** Pod stays healthy, Argo
  Synced/Healthy, no endpoints, fresh port-forward fails. **Observed:** exactly that. Pod `…-v2rph` Running/ready,
  0 restarts; EndpointSlice endpoints `null`; fresh port-forward → `error: timed out waiting for the condition`;
  an older port-forward still answered because it was pinned to the Pod (so stop old forwards first).
* **Why not rebuild:** the image was healthy; a new image still runs in a Pod labelled `app=foundation`, which the
  broken selector still doesn't match. **Rejected repair:** `kubectl edit service` (unreviewed, makes the cluster disagree with Git).
* **Corrective revision** `54083be5…` (`git revert`, tree = known-good): endpoint back, fresh port-forward, all checks
  and Grafana ✔ (`36ff858b-3c28-424d-af6f-1701e6038431`).
* **Blue → green** `08c8f5e1…`: `LAB_ENV` + `academy/config-revision` 2→3 in one commit → new ReplicaSet/Pod
  `foundation-6bcf9bc55b-b7q26`, endpoint moved to `10.244.0.13`, same image ID, fresh request
  `X-Lab-Environment: workshop-green` (`309c97c7…`). Without the annotation bump the running Pod would keep `workshop-blue`.

## Recovery procedure

Restore the last reviewed known-good configuration: from `configuration`, `git revert <bad commit>` (or check out the
known-good tree in a new commit), then `../submit.sh "$(git rev-parse HEAD)"`, `argocd --core app sync "$P1_NAMESPACE"
--revision "$(git rev-parse HEAD)"`, `argocd --core app wait … --sync --health`, stop old port-forwards, and run
`./verify.sh 18082 <prefix> <env>`. Known-good blue = `017cd5a8…` / `54083be5…`; current green = `08c8f5e1…`.

## Reproduction (milestone 6)

Self-check from a fresh folder `../p1-repro` (2026-11-20, same machine, by the team, **not yet by a peer**):
copied `../code/code/app` + guided files, ran the build commands above.

| Compared | Result |
|---|---|
| App source, Containerfile, runtime.env, client.json | identical |
| Publish output | identical except `Foundation.staticwebassets.endpoints.json` (`Last-Modified` = publish time); `Foundation.dll` identical (`local-publish.sha256` vs `repro-publish.sha256`) |
| Image ID | **differs**: repro `8fddebd2f27faa5826ecb580b0f557932eef9c29c689f892a91fc6c4ae4dad3e` vs deployed `db37c67f…`. Expected: file timestamps and image creation time change the layer and config digests. Selected version (commit), actual runtime (Pod imageID `db37c67f…`) and receipt (headers/body) are therefore checked by ID, not by tag |
| Repro image smoke | 200, `foundation-observe-a`, `workshop-blue`, `/healthz` Healthy |

Finding during reproduction: after `podman save`/`load` (used when switching Podman to rootful), the base image lost
its multi-platform digest, so `FROM …@sha256:222759b3…` failed with `image not known` until it was pulled again by
digest. Keep the base image by pulling it, not via save/load, or record the repair.

**Peer reproduction: pending.** A peer must follow this README from a fresh folder and record their image ID here: ____

## Windows-specific notes

* `submit.sh`: `kubectl cp` on Windows misreads an absolute `C:/…` source as `pod:path`; our copy runs `kubectl cp`
  from inside the temporary folder with a relative path (diff vs `../guided/submit.sh` is that one line).
* Always run `../submit.sh` from `configuration/`; run from `p1-local` it refuses (HEAD resolves in the outer repo).
* Namespace/Application is `p1-subrat` (Kubernetes forbids `_`); the image label keeps `p1_subrat`.

## Not submitted

`publish/`, `app/bin/`, `app/obj/` (`.gitignore`), `../p1-images/`, `../p1-tools/`, `~/.kube/config`, running
containers. No credentials are used anywhere (Grafana is anonymous and only reachable on 127.0.0.1).

## Stop / release

`podman stop p1-subrat-local p1-grafana p1-loki`; stop port-forwards with Ctrl-C; `kind delete cluster --name p1`
releases the stand-in cluster (the facilitator would release the classroom namespace/Application).

## BP items still pending

* Yalla scaffolding, BP pull request, BP hosted CI, BP deployment and ingress: **pending / unavailable**: approved
  CLI walkthrough not supplied. Local and self-hosted success does not establish BP scaffolding or deployment.
* Classroom (facilitator) environment evidence: **unavailable**; replaced by the self-hosted stand-in above.
