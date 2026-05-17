#!/usr/bin/env bash
# Wipe every beam node's reckon-db data and start the cluster fresh.
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
# Usage: bash wipe-cluster.sh [<store>]
#   store — store id to wipe (default: default_store)

set -euo pipefail

STORE="${1:-default_store}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="${SCRIPT_DIR}/.."
HOSTS=(beam00.lab beam01.lab beam02.lab beam03.lab)
VOLNAME="reckon-cluster-compose_reckon_gateway_data"

echo "==> WARNING: wiping '${STORE}' across ${HOSTS[*]}"
echo "    Press Ctrl-C within 3s to abort."
sleep 3

echo
echo "==> Stop gateway on every node"
bash "${SCRIPT_DIR}/deploy-beams.sh" down

echo
echo "==> Wipe '${STORE}' data in parallel"
for host in "${HOSTS[@]}"; do
    ssh "rl@${host}" "docker run --rm -v ${VOLNAME}:/d alpine \
        sh -c 'rm -rf /d/${STORE} && echo wiped /d/${STORE} on \$(hostname)'" &
done
wait

echo
echo "==> Start gateway on every node"
bash "${SCRIPT_DIR}/deploy-beams.sh" up

echo
echo "==> Done. Cluster reforms via UDP discovery within ~30s."
echo "    Verify: probe a node and check VerifyMembershipConsensus is healthy."
