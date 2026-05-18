# CLAUDE.md — reckon-cluster-compose

5-node reckon-gateway cluster across the lab subnet (`192.168.1.0/24`). Companion to `reckon-portal-compose` (single-VM web app) — different concern, different repo.

## What this is

Multi-host deployment shell for a clustered reckon-db. Image: `reckon-gateway:0.3.0` (built locally, distributed via `docker save | ssh ... docker load` — no registry yet).

## Topology

5 nodes: `beam00.lab` (.10) + `beam01.lab` (.11) + `beam02.lab` (.12) + `beam03.lab` (.13) + the dev box at `192.168.1.100` (referred to as `host00` in env files; DNS for `host00.lab` is misconfigured so we use IPs everywhere).

Raft quorum = 3 (tolerates 2 simultaneous failures). All stores in the cluster have their own Ra group spanning these 5 nodes.

### Runtime per host

| Host | IP | Runtime | Notes |
|---|---|---|---|
| beam00 | .10 | docker compose | Image build host (no docker on the laptop) |
| beam01 | .11 | docker compose | |
| beam02 | .12 | docker compose | |
| beam03 | .13 | docker compose | Larger NVMe (`/fast`) |
| host00 | .100 | **podman compose** | Dev laptop; no docker daemon. Image pulled via `ssh rl@beam00 'docker save reckon-gateway:<tag>' \| podman load`. |

Same `docker-compose.yml` is consumed by both runtimes — podman's `podman compose` CLI reads docker-compose syntax. `network_mode: host` works identically on both.

### Bringing up host00 the first time

```bash
# 1. Load the current gateway image into podman
ssh rl@beam00.lab "docker save reckon-gateway:0.4.9" | podman load

# 2. Start the stack
cd ~/work/codeberg.org/reckon-internal/reckon-cluster-compose
podman compose --env-file=.env --env-file=env/host00.env up -d

# 3. Verify (from any node)
podman logs reckon-gateway | grep '5-node cluster'
```

On subsequent gateway version bumps, re-do step 1 + `podman compose ... up -d` (no `down` needed; podman picks up the changed env).

## Cluster formation

- Gossip: `reckon_db_discovery` broadcasts on `239.255.0.1:45892` every 5s with the shared `RECKON_DB_CLUSTER_SECRET`. On receive, calls `net_kernel:connect_node/1`.
- Join: `reckon_db_node_monitor` watches `nodeup` events, triggers `reckon_db_store_coordinator:join_cluster/1`. Coordinator election picks the lowest name; rest join via `:khepri_cluster.join`.
- Leader: each store's Ra group elects independently.

No hardcoded peer lists. Add/remove via `env/<host>.env`.

## Why `network_mode: host`

Bridge networking blocks UDP multicast by default. Gossip discovery requires it. Host networking also avoids per-container BEAM dist port mapping complications. Cluster nodes are on a trusted subnet — fine to share the host's network namespace.

## Image distribution

`reckon-gateway` has no CI image-publishing workflow yet (the workspace CLAUDE.md notes it's "git+Docker only"). Workflow:
1. `./scripts/build-image.sh` — builds in the sibling `reckon-gateway` repo
2. `./scripts/distribute-image.sh` — `docker save` once + `ssh ... docker load` to each peer

When CI publishing lands (ghcr.io or Docker Hub), the compose `image:` line stops needing the local build.

## Gotchas

- **`NODE_NAME` is IP-based**, not hostname-based. `host00.lab` DNS is broken — we use `reckon_gateway@192.168.1.100`. If DNS gets fixed, switch to hostnames so leader-leaderboard messages are more readable.
- **Default `RELEASE_COOKIE` in the image is insecure.** The compose enforces `:?`-required so you can't `up` without setting it.
- **First boot creates the cluster**, no separate `join` step. All 5 nodes come up roughly together → gossip discovers → BEAM dist forms → Khepri votes → leader elected.
- **State lives in `./data/` on each host** (bind-mounted). To reset a node: `docker compose down && rm -rf data && docker compose up -d` on that host.

## Related repos

- `reckon-db-org/reckon-gateway` — the gRPC service + reckon-db library. Source of the image.
- `reckon-db-org/reckon-db` — the storage layer (Khepri, Ra, gossip discovery, coordinator).
- `reckon-db-org/reckon-e2e` — torture suite. Set `RECKON_E2E_GATEWAY=beam00.lab:50051` and run `RECKON_E2E_CLUSTER=1 rebar3 ct` against this cluster.
- `reckon-internal/reckon-portal-compose` — single-VM web app deploy. Different concern.
