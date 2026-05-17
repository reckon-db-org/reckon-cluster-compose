#!/usr/bin/env bash
# Capture HTTP/2 traffic on port 50051 of a beam node while a gRPC
# test runs. Bundles ssh+tcpdump+scp into one step.
#
# Usage: bash capture-grpc-50051.sh [host] [duration_s] [out_dir]
#   host       — beam node to capture on (default: beam01.lab)
#   duration_s — tcpdump runtime (default: 30)
#   out_dir    — where the pcap lands locally (default: /tmp)
#
# The remote `tcpdump' runs as root via sudo. The test must be
# triggered separately *during* the capture window — typical
# orchestration:
#
#   bash capture-grpc-50051.sh beam01.lab 25 /tmp &
#   sleep 3
#   RECKON_E2E_CLUSTER=1 RECKON_E2E_GATEWAY=beam01.lab:50051 \
#     rebar3 ct --suite=apps/multi_node_torture/test/multi_node_subscription_failover_SUITE
#   wait
#
# Look at the pcap with `tshark -r <file> -d tcp.port==50051,http2'
# or, if tshark is unavailable, `tcpdump -r <file> -nn -A | less'.

set -euo pipefail

HOST="${1:-beam01.lab}"
DURATION="${2:-30}"
OUT_DIR="${3:-/tmp}"
TS=$(date -u +%Y%m%dT%H%M%S)
PCAP_NAME="grpc-${HOST%%.*}-${TS}.pcap"
REMOTE_PATH="/tmp/${PCAP_NAME}"
LOCAL_PATH="${OUT_DIR}/${PCAP_NAME}"

echo "==> Capturing on ${HOST} port 50051 for ${DURATION}s"
ssh "rl@${HOST}" "sudo timeout ${DURATION} tcpdump -i any -nn -s 0 -w ${REMOTE_PATH} 'port 50051' 2>/dev/null || true"

echo "==> Fetching ${REMOTE_PATH} -> ${LOCAL_PATH}"
scp -q "rl@${HOST}:${REMOTE_PATH}" "${LOCAL_PATH}"
ssh "rl@${HOST}" "rm -f ${REMOTE_PATH}"

ls -lh "${LOCAL_PATH}"
echo
echo "==> Inspect:"
echo "    tshark -r ${LOCAL_PATH} -d tcp.port==50051,http2 -V | less"
echo "    or (no tshark): tcpdump -r ${LOCAL_PATH} -nn -X | less"
