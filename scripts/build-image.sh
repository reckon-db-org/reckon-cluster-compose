#!/usr/bin/env bash
#
# Build the reckon-gateway image locally from the sibling repo.
# Tags it both `reckon-gateway:<version>` and `reckon-gateway:latest`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="${SCRIPT_DIR}/.."
GATEWAY_REPO="${RECKON_GATEWAY_REPO:-${COMPOSE_DIR}/../../reckon-db-org/reckon-gateway}"

if [ ! -f "${GATEWAY_REPO}/Dockerfile" ]; then
    echo "ERROR: reckon-gateway repo not found at ${GATEWAY_REPO}" >&2
    echo "Override with RECKON_GATEWAY_REPO=/path/to/reckon-gateway" >&2
    exit 1
fi

VERSION=$(grep -E '^\s*\{vsn,' "${GATEWAY_REPO}/src/reckon_gateway.app.src" | sed -E 's/.*"([^"]+)".*/\1/')
echo "==> Building reckon-gateway ${VERSION} from ${GATEWAY_REPO}"

(
    cd "${GATEWAY_REPO}"
    docker build -t "reckon-gateway:${VERSION}" -t reckon-gateway:latest .
)

echo
echo "==> Image built:"
docker images reckon-gateway --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}"
