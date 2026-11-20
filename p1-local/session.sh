# Self-hosted P1 environment session (stand-in for the facilitator's session, which was unavailable).
# Public labels only — no credentials. Load in bash (Git Bash or MSYS2 UCRT64) from p1-local with:
#     . ./session.sh
_p1_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$_p1_here/../p1-tools:$PATH"            # kubectl, kind, argocd
export KIND_EXPERIMENTAL_PROVIDER=podman
export MSYS2_ARG_CONV_EXCL="/git"                    # keep in-Pod paths like /git/... from being rewritten on Windows

export P1_NAMESPACE=p1-subrat                        # Kubernetes namespace and Argo CD Application (no '_' allowed)
export P1_IMAGE=localhost/p1_subrat:foundation-a     # built image label (unchanged; image ID db37c67f…)
export P1_SESSION=p1_subrat-20261119                 # public log stream label

export P1_LOCAL_LOKI_URL=http://p1-loki:3100         # Loki as seen from the local app container (network p1-obs)
export P1_CLUSTER_LOKI_URL=http://p1-loki:3100       # Loki as seen from cluster Pods (p1-loki joined to network kind)
export P1_HOST_LOKI_URL=http://127.0.0.1:3100        # Loki as seen from this machine
export P1_GRAFANA_URL=http://127.0.0.1:3000

export P1_REPO_NAMESPACE=p1-git                      # self-hosted Git server used by submit.sh / Argo CD
# newest Pod: after a Git-server rollout the old Pod may still be terminating
P1_REPO_POD="$(kubectl -n p1-git get pod -l app=git-server --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}' 2>/dev/null)"
export P1_REPO_POD
unset _p1_here
echo "P1 session: ns=$P1_NAMESPACE session=$P1_SESSION repo_pod=${P1_REPO_POD:-NOT RUNNING} context=$(kubectl config current-context 2>/dev/null)"
