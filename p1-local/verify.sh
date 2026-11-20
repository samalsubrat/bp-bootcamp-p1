#!/usr/bin/env bash
# Fresh deployed-result check through a NEW port-forward (never reuses an old one).
# Usage (from p1-local, after `. ./session.sh`):   ./verify.sh <local-port> <evidence-prefix> [expected-env]
#   e.g.  ./verify.sh 18082 recovered workshop-blue
# Writes <prefix>-summary.txt plus headers/body/health/missing/pod-logs/grafana files.
set -uo pipefail
port="${1:?local port}"; prefix="${2:?evidence prefix}"; want_env="${3:-workshop-blue}"
: "${P1_NAMESPACE:?source session.sh first}" "${P1_SESSION:?}" "${P1_GRAFANA_URL:?}"
out="$prefix-summary.txt"; : > "$out"
say() { echo "$*" | tee -a "$out"; }

say "== $(date -u +%FT%TZ) verify $P1_NAMESPACE via fresh port-forward 127.0.0.1:$port"
say "argo: $(kubectl -n argocd get application "$P1_NAMESPACE" -o jsonpath='revision={.status.sync.revision} sync={.status.sync.status} health={.status.health.status}')"
say "pod:  $(kubectl -n "$P1_NAMESPACE" get pods -l app=foundation -o jsonpath='{range .items[*]}{.metadata.name} ready={.status.containerStatuses[0].ready} config-revision={.metadata.annotations.academy/config-revision} imageID={.status.containerStatuses[0].imageID} ip={.status.podIP}{" "}{end}')"
say "endpoints: $(kubectl -n "$P1_NAMESPACE" get endpointslices -l kubernetes.io/service-name=foundation -o jsonpath='{range .items[*]}{.endpoints[*].addresses}{end}')"

kubectl -n "$P1_NAMESPACE" port-forward --pod-running-timeout=20s service/foundation "$port:8080" > "$prefix-port-forward.log" 2>&1 &
pf=$!
trap 'kill $pf 2>/dev/null' EXIT
for _ in $(seq 1 20); do curl -s -o /dev/null "http://127.0.0.1:$port/healthz" && break; sleep 1; done

rid="$(powershell -NoProfile -Command '[guid]::NewGuid().ToString()' 2>/dev/null | tr -d '\r')"
[ -n "$rid" ] || rid="$(cat /proc/sys/kernel/random/uuid)"
base="http://127.0.0.1:$port"
say "page:    $(curl -s -o /dev/null -w '%{http_code} %{content_type}' "$base/")"
curl -s -i "$base/healthz" > "$prefix-health.txt"
say "health:  $(head -1 "$prefix-health.txt" | tr -d '\r') / $(tail -1 "$prefix-health.txt")"
curl -s -H "X-Request-Id: $rid" -D "$prefix-headers.txt" "$base/api/boards/reference" -o "$prefix-board.json"
say "board:   $(head -1 "$prefix-headers.txt" | tr -d '\r'); $(grep -i '^X-Lab' "$prefix-headers.txt" | tr -d '\r' | paste -sd ' ')"
if diff -q <(tr -d '\r' < "$prefix-board.json") <(tr -d '\r' < app/data/board-reference.json) >/dev/null; then say "body:    identical to data/board-reference.json"; else say "body:    DIFFERS"; fi
grep -qi "^X-Lab-Environment: $want_env" "$prefix-headers.txt" && say "env:     $want_env as expected" || say "env:     NOT $want_env"
curl -s -i "$base/api/boards/missing" > "$prefix-missing.txt"
say "missing: $(head -1 "$prefix-missing.txt" | tr -d '\r') $(tail -1 "$prefix-missing.txt")"
say "request_id: $rid"

sleep 3
kubectl -n "$P1_NAMESPACE" logs deployment/foundation > "$prefix-pod-logs.txt"
say "pod log: $(grep -m1 '^READY' "$prefix-pod-logs.txt")"
grep -q "$rid" "$prefix-pod-logs.txt" && say "pod log: request record found" || say "pod log: request record MISSING"
q="{job=\"academy-w110\", session=\"$P1_SESSION\"} | json | request_id=\"$rid\""
curl -s -G "$P1_GRAFANA_URL/api/datasources/proxy/uid/p1-loki/loki/api/v1/query_range" \
  --data-urlencode "query=$q" --data-urlencode "since=15m" > "$prefix-grafana-query.json"
grep -q "\"request_id\":\"$rid\"" "$prefix-grafana-query.json" && say "grafana: matching row for $q" || say "grafana: NO matching row for $q"
