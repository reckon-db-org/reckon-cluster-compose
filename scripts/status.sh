#!/usr/bin/env bash
#
# Quick status across all 5 nodes.

set -euo pipefail

REMOTE_HOSTS=(beam00.lab beam01.lab beam02.lab beam03.lab)

for host in "${REMOTE_HOSTS[@]}"; do
    echo "==> ${host}"
    ssh -o BatchMode=yes -o ConnectTimeout=5 "rl@${host}" \
        'cd /home/rl/reckon-cluster-compose 2>/dev/null && docker compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Image}}"' \
        2>&1 | grep -v "Warning:" | head -5
    echo
done

echo "==> host00 (local)"
( cd "$(dirname "${BASH_SOURCE[0]}")/.." && docker compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Image}}" ) 2>&1 | head -5
