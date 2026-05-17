#!/usr/bin/env bash
# Wipe a beam node's reckon-db data dir and restart its gateway
# container so it rejoins the cluster as a fresh member.
#
# Use when a node has fallen out of Raft membership (e.g. after a
# rough restart cycle) and gets stuck in "Joining cluster via ..."
# because its local Ra log has stale membership state from a
# previous incarnation that no longer matches the cluster's view.
#
# Usage: bash wipe-and-rejoin.sh <host> [store]
#   host  — beam node short name (e.g. beam00.lab)
#   store — store id (default: default_store)

set -euo pipefail

HOST="${1:-}"
STORE="${2:-default_store}"

if [ -z "${HOST}" ]; then
    echo "Usage: $0 <host> [store]" >&2
    exit 2
fi

SHORT="${HOST%%.*}"

echo "==> Stop gateway container on ${HOST}"
ssh "rl@${HOST}" "cd /home/rl/reckon-cluster-compose && docker compose --env-file=.env --env-file=env/${SHORT}.env down"

echo "==> Wipe ${STORE} data dir on ${HOST}"
# The compose stack creates a named volume mounted at /app/data.
# Wipe just the per-store subdir inside that volume — preserves
# the volume itself so a subsequent `compose up' doesn't have to
# recreate it.
VOLNAME="reckon-cluster-compose_reckon_gateway_data"
ssh "rl@${HOST}" "docker run --rm -v ${VOLNAME}:/d alpine sh -c 'rm -rf /d/${STORE} && echo wiped /d/${STORE}'"

echo "==> Restart gateway on ${HOST}"
ssh "rl@${HOST}" "cd /home/rl/reckon-cluster-compose && docker compose --env-file=.env --env-file=env/${SHORT}.env up -d"

echo
echo "==> Done. Tail logs with:"
echo "    ssh rl@${HOST} 'docker logs -f reckon-gateway'"
