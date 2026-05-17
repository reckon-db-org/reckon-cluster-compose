#!/usr/bin/env bash
#
# Deploy reckon-cluster-compose to beam00..03 only (skip host00).
# Used when the dev laptop has no docker daemon, so we can't run the
# host00 step of deploy-all.sh.
#
# Usage: ./deploy-beams.sh [up|down|restart]

set -eu

ACTION="${1:-up}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="${SCRIPT_DIR}/.."
HOSTS=(beam00.lab beam01.lab beam02.lab beam03.lab)

[ -f "${COMPOSE_DIR}/.env" ] || { echo "ERROR: ${COMPOSE_DIR}/.env missing" >&2; exit 1; }

for host in "${HOSTS[@]}"; do
    key="${host%%.*}"
    target="/home/rl/reckon-cluster-compose"
    echo
    echo "==> ${key} (${host})"
    rsync -az --delete --exclude=.git --exclude=data \
        "${COMPOSE_DIR}/" "rl@${host}:${target}/"
    case "$ACTION" in
        up)
            ssh "rl@${host}" "cd ${target} && docker compose --env-file=.env --env-file=env/${key}.env up -d"
            ;;
        down)
            ssh "rl@${host}" "cd ${target} && docker compose --env-file=.env --env-file=env/${key}.env down"
            ;;
        restart)
            ssh "rl@${host}" "cd ${target} && docker compose --env-file=.env --env-file=env/${key}.env down && docker compose --env-file=.env --env-file=env/${key}.env up -d"
            ;;
        *) echo "Unknown action: $ACTION" >&2; exit 2 ;;
    esac
done

echo
echo "==> Done. ${#HOSTS[@]} beam nodes ${ACTION}."
