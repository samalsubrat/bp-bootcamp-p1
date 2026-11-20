# Milestone 5 — Diagnose and recover one configuration failure

Known-good: `017cd5a8f057b4f05271eb1ec19997cdd8bee364` (Synced/Healthy, Pod image `db37c67f…`, endpoint = Pod IP,
request `93b26d72-a8cb-4787-8055-953f02c67341` matched in Grafana). Evidence preserved in `cluster-*.txt/json`.

## 5a. Controlled failure: Service selector `app: foundation` → `app: foundation-missing`

### Prediction (written before the change)

- **Deployment / Pod:** unchanged. The Deployment's own selector and Pod template labels are not touched, so no new
  Pod is created; the existing Pod stays Running and Ready, because its readiness/liveness probes call `/healthz` on
  the container directly and do not go through the Service.
- **Argo CD:** `Synced` (cluster matches the selected commit) and most likely `Healthy`. Argo judges health from the
  Service object and the Deployment, and a Service with no endpoints is not reported as degraded.
- **Service / EndpointSlice:** the Service still exists with port 8080, but no Pod carries `app=foundation-missing`,
  so its EndpointSlice has **no endpoints**.
- **Fresh port-forward:** `kubectl port-forward service/foundation` resolves the Service's selector to a Pod. With no
  match it fails immediately, and no request reaches the app, so there is no new log record or Grafana row.
- **Old port-forward:** a port-forward started *before* the change is pinned to the Pod it chose at start-up and
  could keep answering. That would hide the failure, so stop it first.
- **Rebuilding the image would not help:** the fault is in which Pods the Service selects (configuration), not in
  the image. A rebuilt image would run in a Pod still labelled `app=foundation`, which the broken selector still
  doesn't match.

### Review request (bad commit, deliberately)

Outcome: controlled training failure. Change: Service `spec.selector.app` only. Source/image unchanged (`db37c67f…`).
Checks: diff shows one line. Recovery: `git revert` back to the known-good selector. Reviewer decision: ____

### Observed (2026-11-20, all matching the prediction)

| Step | Evidence |
|---|---|
| Bad commit | `1653f1b32488aede4b461d30d336533602fc44c0`, one-line diff (Service selector), submitted and synced: Argo **Synced to main (1653f1b), Healthy** |
| Pod | `foundation-54846764d9-v2rph` still Running, ready=true, 0 restarts, not replaced |
| Service | `foundation` 8080/TCP, selector `app=foundation-missing`; `kubectl get pods -l app=foundation-missing` → No resources found |
| EndpointSlice | `foundation-j5fb6` ports `<unset>`, endpoints `<unset>` / `null` (was `10.244.0.12:8080`) |
| Fresh port-forward | `kubectl port-forward --pod-running-timeout=20s service/foundation 18082:8080` → `error: timed out waiting for the condition`, exit 1; curl to :18082 → exit 7 (nothing listening). No request reached the app, so there is no log record. |
| Old port-forward | The :18081 forward started before the change still answered `200 Healthy`: it is pinned to the Pod it resolved at start-up. Shows why it must be stopped before testing a Service change. |

Evidence file: `failure-evidence.txt`.

**Why rebuilding the image would not repair it:** the image was never at fault; the Pod ran healthy throughout. A
new image would still run in a Pod labelled `app=foundation`, which the broken selector still doesn't match. The repair has to
be in the reviewed configuration.

**Rejected repair:** running `kubectl edit service foundation` by hand. It would bring the endpoint back, but Argo
would show the cluster out of sync with Git (and could undo the edit on the next sync), and the fix would leave no
reviewed record.

## 5b. Correction

Corrective commit `54083be54de646c6a9af2fda19b9bcc1806001d9` = `git revert 1653f1b`; its file tree is identical to
known-good `017cd5a8`. Submitted, synced: **Synced to main (54083be), Healthy**. Fresh verification (`./verify.sh 18082
recovered`, new port-forward): endpoint `10.244.0.12` back; `/` 200, `/healthz` Healthy, reference 200 identical body,
`foundation-observe-a`, `workshop-blue`, missing 404; request `36ff858b-3c28-424d-af6f-1701e6038431` in Pod log and a
matching Grafana row. The Pod was not replaced (a Service change does not restart Pods). Evidence: `recovered-*`.

## 5c. Environment change blue → green (separate predicted exercise)

### Prediction (written before the change)

- The change updates ConfigMap `LAB_ENV` **and** bumps the Pod-template annotation `academy/config-revision` 2 → 3
  in the same commit.
- The annotation is part of the Pod template, so changing it makes the Deployment roll out a **new Pod**
  (new ReplicaSet/Pod name). The new process reads `workshop-green` from the ConfigMap when it starts.
- A fresh request returns `X-Lab-Environment: workshop-green`; release stays `foundation-observe-a`; image ID stays
  `db37c67f…` (no rebuild); the Service endpoint moves to the new Pod's IP.
- Without the annotation bump, the ConfigMap would change but the running Pod would keep its start-up environment
  (`workshop-blue`), because environment variables are read only when the process starts.

### Review request

Outcome: public environment label blue → green. Changed fields: `LAB_ENV`, `academy/config-revision`. Image unchanged.
Checks: two-line diff. Recovery: revert to `54083be5…`. Reviewer decision: ____

### Observed (2026-11-20, matching the prediction)

| Step | Evidence |
|---|---|
| Commit | `08c8f5e1342241f45506e9beff318042691f4cd7` (two-line diff), submitted, synced: **Synced to main (08c8f5e), Healthy** |
| Rollout | New ReplicaSet `foundation-6bcf9bc55b` (1/1); old `foundation-54846764d9` scaled to 0; Pod `foundation-54846764d9-v2rph` → Completed, new Pod `foundation-6bcf9bc55b-b7q26` Running, `config-revision` 3 |
| Image | Both Pods `sha256:db37c67f4a659db11e83c5e526a8b5f53d7e24542f45d915ed81f904d01aee2a`: no rebuild |
| Endpoint | moved `10.244.0.12` → `10.244.0.13` (new Pod) |
| Fresh request | `./verify.sh 18082 green workshop-green`: `X-Lab-Environment: workshop-green`, `X-Lab-Release: foundation-observe-a`, body identical, health OK, missing 404; Pod stdout `READY … environment=workshop-green`; request `309c97c7-3379-4c79-a4bc-17b6ad4cd074` found in Pod log and in Grafana |

Evidence: `green-*`. Any port-forward started before this rollout (for example the old :18081 one) is now attached to a
Pod that no longer exists. Stop it.
