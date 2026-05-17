#!/usr/bin/env bash
#
# Distribute a reckon-gateway image tag from one beam node (the
# "source") to the other beam nodes via `docker save | ssh ... docker load`.
#
# Use when the build happened on a beam node (so the laptop has no
# docker daemon to run distribute-image.sh from). The source node
# already has the image; the others don't.
#
# Usage:
#   ./distribute-from-beam.sh <tag> [<source-host>]
#     tag         — required, e.g. "0.4.2"
#     source-host — defaults to beam01.lab

set -eu

TAG="${1:-}"
SRC="${2:-beam01.lab}"

if [ -z "$TAG" ]; then
    echo "Usage: $0 <tag> [<source-host>]" >&2
    exit 2
fi

PEERS=()
for h in beam00 beam01 beam02 beam03; do
    if [ "${h}.lab" != "$SRC" ] && [ "${h}" != "$SRC" ]; then
        PEERS+=("${h}.lab")
    fi
done

if ! ssh "rl@${SRC}" "docker image inspect reckon-gateway:${TAG}" >/dev/null 2>&1; then
    echo "ERROR: reckon-gateway:${TAG} not present on ${SRC}" >&2
    exit 1
fi

echo "==> Source: ${SRC} reckon-gateway:${TAG}"
echo "==> Targets: ${PEERS[*]}"

for peer in "${PEERS[@]}"; do
    echo
    echo "==> ${SRC} -> ${peer}"
    ssh "rl@${SRC}" "docker save reckon-gateway:${TAG}" \
        | ssh "rl@${peer}" 'docker load'
done

echo
echo "==> Done. ${#PEERS[@]} peer(s) updated."
