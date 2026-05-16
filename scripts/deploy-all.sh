#!/usr/bin/env bash
#
# Deploy reckon-cluster-compose to every host: rsync the dir, point
# at the right per-host env, bring up the container.
#
# Run from the local dev machine. Assumes:
#   - scripts/build-image.sh + distribute-image.sh have already run
#   - .env exists locally with real RELEASE_COOKIE + RECKON_DB_CLUSTER_SECRET
#   - env/<host>.env exists for each host
#
# Usage: ./deploy-all.sh [up|down|restart]

set -euo pipefail

ACTION="${1:-up}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="${SCRIPT_DIR}/.."
REMOTE_HOSTS=(beam00.lab beam01.lab beam02.lab beam03.lab)
LOCAL_HOST=host00

if [ ! -f "${COMPOSE_DIR}/.env" ]; then
    echo "ERROR: ${COMPOSE_DIR}/.env not found." >&2
    echo "Copy .env.example to .env and fill in RELEASE_COOKIE + RECKON_DB_CLUSTER_SECRET." >&2
    exit 1
fi

run_remote() {
    local host="$1"
    local host_key="${host%%.*}"     # beam00.lab -> beam00
    local target="/home/rl/reckon-cluster-compose"

    echo
    echo "==> ${host_key} (${host})"
    rsync -az --delete \
        --exclude=.git --exclude=data \
        "${COMPOSE_DIR}/" "rl@${host}:${target}/"

    case "${ACTION}" in
        up)
            ssh "rl@${host}" "cd ${target} && docker compose --env-file=.env --env-file=env/${host_key}.env up -d"
            ;;
        down)
            ssh "rl@${host}" "cd ${target} && docker compose --env-file=.env --env-file=env/${host_key}.env down"
            ;;
        restart)
            ssh "rl@${host}" "cd ${target} && docker compose --env-file=.env --env-file=env/${host_key}.env down && docker compose --env-file=.env --env-file=env/${host_key}.env up -d"
            ;;
        *)
            echo "Unknown action: ${ACTION}" >&2; exit 2
            ;;
    esac
}

run_local() {
    echo
    echo "==> ${LOCAL_HOST} (this machine)"
    (
        cd "${COMPOSE_DIR}"
        case "${ACTION}" in
            up)      docker compose --env-file=.env --env-file=env/${LOCAL_HOST}.env up -d ;;
            down)    docker compose --env-file=.env --env-file=env/${LOCAL_HOST}.env down ;;
            restart) docker compose --env-file=.env --env-file=env/${LOCAL_HOST}.env down && docker compose --env-file=.env --env-file=env/${LOCAL_HOST}.env up -d ;;
        esac
    )
}

for host in "${REMOTE_HOSTS[@]}"; do
    run_remote "${host}"
done
run_local

echo
echo "==> Done. ${#REMOTE_HOSTS[@]} remote + 1 local = 5 nodes ${ACTION}."
echo "==> Verify cluster: ./scripts/status.sh"
