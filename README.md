# BP Bootcamp — Project 1: Deploy the game foundation (team p1-subrat)

Reproducible deployment of the supplied foundation page + board API (release `foundation-observe-a`), with a
controlled configuration failure, its recovery, and a blue → green environment change.

**Start here: [p1-local/README.md](p1-local/README.md)**, the handover README (build, image identity, configuration,
deployment revisions, verification evidence, failure/recovery, reproduction, pending BP items).

> The facilitator's classroom environment was unavailable. Milestones 4–5 ran on a **self-hosted stand-in**
> (kind cluster + Argo CD core + in-cluster Git server + Loki/Grafana on Podman, Windows). This is not classroom
> evidence and not BP evidence; every deviation is listed in [p1-local/evidence-log.md](p1-local/evidence-log.md).

## Layout

| Path | Contents |
|---|---|
| `p1-local/` | Project folder (the brief's personal project folder) |
| `p1-local/app/` | Supplied application, copied unchanged (only `wwwroot/client.json` set from the guided file) |
| `p1-local/Containerfile`, `runtime.env`, `submit.sh` | Packaging recipe, public environment, Git transport |
| `p1-local/configuration/` | Reviewed deployment configuration `app/resources.yaml`. Its commit history is kept with the **original SHAs** (`98b81b63`, `017cd5a8`, `1653f1b3`, `54083be5`, `08c8f5e1`), merged here with `git subtree` |
| `p1-local/plan.md` | Milestone 1: plan, request path, smoke expectations, game intention |
| `p1-local/review-request.md`, `milestone5.md` | Milestone 3 review request; milestone 5 predictions, observations, recovery |
| `p1-local/evidence-log.md` + `local-*`, `cluster-*`, `failure-evidence.txt`, `recovered-*`, `green-*`, `running-pods.json` | Evidence log and raw evidence files |
| `p1-local/session.sh`, `observability/`, `verify.sh` | Self-hosted session, Loki/Grafana start-up, fresh verification |
| `p1-cluster/` | Self-hosted stand-in for the facilitator's preparation: Git server and Argo CD Application |

## Final state (2026-11-20)

Argo CD Application `p1-subrat`: **Synced to `08c8f5e1342241f45506e9beff318042691f4cd7`, Healthy**; Pod runtime image
`sha256:db37c67f4a659db11e83c5e526a8b5f53d7e24542f45d915ed81f904d01aee2a` (= the reviewed local build); public
environment `workshop-green`.

## Not included

Build output (`publish/`, `bin/`, `obj/`), image archives (`p1-images/`), downloaded CLI binaries (`p1-tools/`,
versions and checksum verification are in the handover README), kubeconfig, credentials, and the course's distributed
materials (`code/`, `guided/`, `starter/`, the learner manual). Paths like `../code/code/app` in the handover README
refer to those course materials.

Still pending (human steps): reviewer decisions, cluster browser check, peer reproduction, individual demonstrations,
and all BP Yalla items.
