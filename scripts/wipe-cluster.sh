#!/usr/bin/env bash
# Wipe every node's reckon-db data and start the cluster fresh.
#
# Use when you want to reset the cluster from scratch — e.g. after
# malformed test fixtures have polluted the store with non-compliant
# stream ids, or for a clean slate before a benchmark.
#
# DO NOT confuse with wipe-and-rejoin.sh — that script wipes ONE
# node and lets it rejoin a running cluster. Running it on every
# node sequentially leaves Ra in a fractured state (each wipe
# destroys quorum needed for the previous join to commit). This
# script does the cluster-wide reset correctly:
#
#   1. Stop the gateway on every node (no quorum to worry about).
#   2. Wipe the store data on every node in parallel.
#   3. Start every node back up; UDP multicast discovery + leader
#      election reforms the cluster from scratch.
#
# Covers BOTH the docker beams (beam00..beam03) AND the local
# podman host00 node (if env/host00.env exists and podman is
# available locally). host00 is opportunistic — if podman isn't
# installed or env/host00.env is missing, the script warns and
# carries on with just the beams.
#
# Usage: bash wipe-cluster.sh [<store>]
#   store — store id to wipe (default: default_store)

set -euo pipefail

STORE="${1:-default_store}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="${SCRIPT_DIR}/.."
BEAMS=(beam00.lab beam01.lab beam02.lab beam03.lab)
VOLNAME="reckon-cluster-compose_reckon_gateway_data"

# Decide whether host00 (local podman node) participates this run.
HOST00=false
if [ -f "${COMPOSE_DIR}/env/host00.env" ] && command -v podman >/dev/null 2>&1; then
    HOST00=true
fi

if $HOST00; then
    echo "==> WARNING: wiping '${STORE}' across ${BEAMS[*]} + host00 (podman)"
else
    echo "==> WARNING: wiping '${STORE}' across ${BEAMS[*]}"
    echo "    (host00 skipped — no env/host00.env or podman not installed)"
fi
echo "    Press Ctrl-C within 3s to abort."
sleep 3

#-------------------------------------------------------------------
# 1. Stop everywhere
#-------------------------------------------------------------------
echo
echo "==> Stop gateway on every node"
bash "${SCRIPT_DIR}/deploy-beams.sh" down

if $HOST00; then
    ( cd "${COMPOSE_DIR}" && \
        podman compose --env-file=.env --env-file=env/host00.env down 2>&1 | \
        grep -E 'Stopping|Stopped|Removed|Removing|Error' || true )
fi

#-------------------------------------------------------------------
# 2. Wipe in parallel
#-------------------------------------------------------------------
echo
echo "==> Wipe '${STORE}' data in parallel"
for host in "${BEAMS[@]}"; do
    ssh "rl@${host}" "docker run --rm -v ${VOLNAME}:/d alpine \
        sh -c 'rm -rf /d/${STORE} && echo wiped /d/${STORE} on \$(hostname)'" &
done

if $HOST00; then
    # Rootless podman volumes are owned by a UID-mapped user; rm via
    # a temp container is the portable way to clear them. --network=none
    # sidesteps pasta-network-init issues on rootless setups.
    podman run --rm --network=none \
        -v "${VOLNAME}:/d" alpine \
        sh -c "rm -rf /d/${STORE} && echo 'wiped /d/${STORE} on host00 (podman)'" &
fi
wait

#-------------------------------------------------------------------
# 3. Start everywhere
#-------------------------------------------------------------------
echo
echo "==> Start gateway on every node"
bash "${SCRIPT_DIR}/deploy-beams.sh" up

if $HOST00; then
    ( cd "${COMPOSE_DIR}" && \
        podman compose --env-file=.env --env-file=env/host00.env up -d 2>&1 | \
        grep -E 'Creating|Created|Starting|Started|Error' || true )
fi

echo
if $HOST00; then
    echo "==> Done. 5 nodes (4 beams + host00) starting up."
else
    echo "==> Done. 4 beam nodes starting up."
fi
echo "    Cluster reforms via UDP discovery within ~30s."
echo "    Verify: probe a node and check VerifyMembershipConsensus is healthy."
