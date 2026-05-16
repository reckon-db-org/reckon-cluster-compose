# reckon-cluster-compose

5-node `reckon-gateway` cluster deployment across the lab subnet.

## Topology

| Node | IP | Role |
|---|---|---|
| `beam00.lab` | 192.168.1.10 | cluster member |
| `beam01.lab` | 192.168.1.11 | cluster member |
| `beam02.lab` | 192.168.1.12 | cluster member |
| `beam03.lab` | 192.168.1.13 | cluster member |
| `host00` (dev box) | 192.168.1.100 | cluster member |

Raft quorum = 3 (tolerates 2 simultaneous failures). All nodes share the same `RELEASE_COOKIE` + `RECKON_DB_CLUSTER_SECRET`; each has a unique `NODE_NAME` (uses IP, not DNS, to sidestep `.lab` resolution issues).

## Cluster formation flow

1. Each node starts `reckon_gateway:0.3.0` container with `network_mode: host` (multicast must reach the host's NIC).
2. `reckon_db_discovery` (gossip strategy) broadcasts on `239.255.0.1:45892` every 5s.
3. On each receive: peer node verified via shared secret → `net_kernel:connect_node/1` connects BEAM dist.
4. `reckon_db_node_monitor` watches `{nodeup, _}` → calls `reckon_db_store_coordinator:join_cluster/1`.
5. Coordinator election: lowest node name → coordinator. Others join via `:khepri_cluster.join`.
6. Each store independently elects a Ra leader.

No hardcoded peer lists. Add or remove nodes by editing `env/<host>.env`.

## First-time deployment

### Prereqs

- Docker on every cluster host
- SSH access to `rl@beamN.lab` from the dev box (key-based)
- The 5 hosts can multicast to each other on the lab subnet (they're all on `192.168.1.0/24` — should just work)
- A locally-checked-out `reckon-db-org/reckon-gateway` repo (`build-image.sh` looks for it as a sibling of this dir)

### Steps

```bash
# 1. Configure
cp .env.example .env
# edit .env, set:
#   RELEASE_COOKIE          (openssl rand -base64 32 | tr -d '/+= ')
#   RECKON_DB_CLUSTER_SECRET (same)

# 2. Build the image once
./scripts/build-image.sh

# 3. Ship it to every host (docker save | ssh load)
./scripts/distribute-image.sh

# 4. Deploy
./scripts/deploy-all.sh up

# 5. Verify
./scripts/status.sh
```

After `up`, gossip discovery takes ~10 seconds to form the BEAM mesh, then another ~5 seconds for the Khepri/Ra cluster to elect a leader for the default store.

## Day-to-day

```bash
./scripts/status.sh                    # docker compose ps × 5 hosts
./scripts/deploy-all.sh restart        # rolling restart
./scripts/deploy-all.sh down           # take cluster down
```

## Cluster health via gRPC

The gateway's `HealthService` exposes:
- `Health` — basic alive check
- `ServerInfo` — current node, BEAM version, integrity status
- `ClusterStatus(store_id)` — returns `HEALTHY` / `DEGRADED` / `SPLIT_BRAIN` / `NO_QUORUM`

Drive these from `reckon-e2e` with `RECKON_E2E_GATEWAY=beam00.lab:50051` or any other cluster node.

## What's NOT here

- TLS for the gRPC port (lab subnet is trusted; add Caddy in front if exposing externally)
- Persistent backup story (TODO — `pg_dump`-equivalent for Khepri)
- CI image publishing (image is built locally + distributed via `docker save`; switch to ghcr.io when CI lands for reckon-gateway)
- Multi-store config (default_store only; add more in reckon-gateway's `sys.config.src` and bump the image)
