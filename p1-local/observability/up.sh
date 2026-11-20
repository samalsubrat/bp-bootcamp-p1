#!/usr/bin/env bash
# Start the self-hosted Loki + Grafana and (re)start the app container wired to them.
# Run from p1-local:   ./observability/up.sh
# Local-only stand-in for the classroom's prepared Loki/Grafana — not a BP or classroom service.
set -euo pipefail
export MSYS2_ARG_CONV_EXCL='*' MSYS_NO_PATHCONV=1   # stop Git Bash / MSYS2 rewriting container paths

cd "$(dirname "$0")/.."
. ./session.sh
ds="$(cygpath -m "$PWD/observability/grafana-datasource.yaml" 2>/dev/null || echo "$PWD/observability/grafana-datasource.yaml")"

podman network exists p1-obs || podman network create p1-obs
# The kind cluster (if running) must also reach Loki: join p1-loki to its network after start.

podman rm -f p1-loki p1-grafana "$P1_NAMESPACE-local" >/dev/null 2>&1 || true

podman run -d --name p1-loki --network p1-obs -p 127.0.0.1:3100:3100 \
  docker.io/grafana/loki:3.5.3 -config.file=/etc/loki/local-config.yaml

# Anonymous Admin is acceptable only because Grafana is bound to 127.0.0.1 on this machine.
podman run -d --name p1-grafana --network p1-obs -p 127.0.0.1:3000:3000 \
  -e GF_AUTH_ANONYMOUS_ENABLED=true -e GF_AUTH_ANONYMOUS_ORG_ROLE=Admin -e GF_AUTH_DISABLE_LOGIN_FORM=true \
  -v "$ds:/etc/grafana/provisioning/datasources/loki.yaml:ro" \
  docker.io/grafana/grafana:12.1.0

printf 'waiting for Loki'
for _ in $(seq 1 60); do
  [ "$(curl -s "$P1_HOST_LOKI_URL/ready")" = "ready" ] && break
  printf '.'; sleep 2
done
echo " $(curl -s "$P1_HOST_LOKI_URL/ready")"

podman run -d --name "$P1_NAMESPACE-local" --network p1-obs -p 127.0.0.1:18080:8080 \
  --env-file runtime.env -e LAB_SESSION="$P1_SESSION" -e LOCAL_LOKI_URL="$P1_LOCAL_LOKI_URL" \
  "$P1_IMAGE"

sleep 2
podman logs "$P1_NAMESPACE-local" | head -1
echo "page:    http://127.0.0.1:18080"
echo "grafana: $P1_GRAFANA_URL/explore"

if podman network exists kind; then
  podman network connect kind p1-loki 2>/dev/null || true
  echo "p1-loki also joined network kind (cluster Pods use $P1_CLUSTER_LOKI_URL)"
fi
