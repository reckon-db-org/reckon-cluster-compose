#!/usr/bin/env bash
#
# Ship the locally-built reckon-gateway image to every cluster host
# via `docker save | ssh ... docker load`. Avoids needing a registry.
#
# Usage: ./distribute-image.sh [tag]

set -euo pipefail

TAG="${1:-0.3.0}"
HOSTS=(beam00.lab beam01.lab beam02.lab beam03.lab)
LOCAL_HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! docker image inspect "reckon-gateway:${TAG}" >/dev/null 2>&1; then
    echo "ERROR: reckon-gateway:${TAG} not found locally. Run build-image.sh first." >&2
    exit 1
fi

echo "==> Saving image once..."
TMPFILE=$(mktemp -t reckon-gateway-XXXXXX.tar)
trap "rm -f ${TMPFILE}" EXIT
docker save "reckon-gateway:${TAG}" -o "${TMPFILE}"
echo "    saved $(du -h "${TMPFILE}" | cut -f1) to ${TMPFILE}"

for host in "${HOSTS[@]}"; do
    echo
    echo "==> Loading on ${host}"
    ssh "rl@${host}" 'docker load' < "${TMPFILE}"
    ssh "rl@${host}" "docker tag reckon-gateway:${TAG} reckon-gateway:latest || true"
done

echo
echo "==> Local host: image already present (built here)"
echo "==> Done. ${#HOSTS[@]} remote hosts + 1 local = 5 nodes ready."
