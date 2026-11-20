#!/usr/bin/env bash
# P1 supplied transport: copy the selected, committed configuration revision as a bare Git repository into the
# facilitator's prepared classroom Git server. It neither approves the change nor mutates the application.
#
# Usage (from the configuration folder):   ../submit.sh "$P1_REVISION"
# Requires (classroom environment session): P1_NAMESPACE, P1_REPO_NAMESPACE, P1_REPO_POD
# Optional: P1_REPO_PATH (default /git/$P1_NAMESPACE.git, as prepared by the facilitator)
#           P1_SUBMIT_DRY_RUN=1  build and check the bare copy locally, but do not contact the cluster.
# No credentials are read or written by this script; kubectl uses the prepared environment's own configuration.
set -euo pipefail

revision="${1:-}"
if [[ ! "$revision" =~ ^[0-9a-f]{40}$ ]]; then
  echo "usage: ../submit.sh FULL_40_CHARACTER_REVISION (from: git rev-parse HEAD)" >&2
  exit 2
fi
if [ "$(git rev-parse HEAD)" != "$revision" ]; then
  echo "REFUSED: $revision is not the current committed revision ($(git rev-parse HEAD))." >&2
  exit 2
fi
if [ -n "$(git status --porcelain -- app/resources.yaml)" ]; then
  echo "REFUSED: app/resources.yaml has uncommitted changes; commit the reviewed configuration first." >&2
  exit 2
fi
if grep -q "REPLACE_WITH_" app/resources.yaml; then
  echo "REFUSED: app/resources.yaml still contains REPLACE_WITH_ placeholders." >&2
  exit 2
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
git clone --quiet --bare . "$work/repo.git"
git -C "$work/repo.git" update-ref refs/heads/main "$revision"
echo "prepared bare copy: main -> $(git -C "$work/repo.git" rev-parse refs/heads/main)"

if [ "${P1_SUBMIT_DRY_RUN:-0}" = "1" ]; then
  echo "DRY RUN: not contacting the classroom Git server."
  exit 0
fi

: "${P1_NAMESPACE:?set by the classroom environment session}"
: "${P1_REPO_NAMESPACE:?set by the classroom environment session}"
: "${P1_REPO_POD:?set by the classroom environment session}"
target="${P1_REPO_PATH:-/git/$P1_NAMESPACE.git}"

kubectl -n "$P1_REPO_NAMESPACE" exec "$P1_REPO_POD" -- rm -rf "$target.incoming"
# Local change (Windows): kubectl cp misreads an absolute "C:/..." source as pod:path, so copy from inside $work.
(cd "$work" && kubectl -n "$P1_REPO_NAMESPACE" cp repo.git "$P1_REPO_POD:$target.incoming")
kubectl -n "$P1_REPO_NAMESPACE" exec "$P1_REPO_POD" -- sh -c "rm -rf '$target' && mv '$target.incoming' '$target'"
echo "submitted revision $revision to $P1_REPO_POD:$target (transport only; approval and sync are separate steps)"
