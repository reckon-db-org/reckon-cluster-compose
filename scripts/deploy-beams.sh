#!/usr/bin/env bash
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
            # shellcheck disable=SC2029  # ${target} and ${key} are computed locally, one rsync destination and env file per beam
            ssh "rl@${host}" "cd ${target} && docker compose --env-file=.env --env-file=env/${key}.env up -d"
            ;;
        down)
            # shellcheck disable=SC2029  # same locally computed ${target}; the beam is only told where to run compose
            ssh "rl@${host}" "cd ${target} && docker compose --env-file=.env --env-file=env/${key}.env down"
            ;;
        restart)
            # shellcheck disable=SC2029  # same local ${target}, and the remote shell expands nothing: both paths arrive resolved
            ssh "rl@${host}" "cd ${target} && docker compose --env-file=.env --env-file=env/${key}.env down && docker compose --env-file=.env --env-file=env/${key}.env up -d"
            ;;
        *) echo "Unknown action: $ACTION" >&2; exit 2 ;;
    esac
done

echo
echo "==> Done. ${#HOSTS[@]} beam nodes ${ACTION}."
