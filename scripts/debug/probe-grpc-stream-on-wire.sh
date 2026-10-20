#!/usr/bin/env bash
# the e2e harness. Confirms whether the server actually sends any
# HTTP/2 DATA frames after the subscribe, or stays silent past the
# initial HEADERS frame.
#
# Usage: bash probe-grpc-stream-on-wire.sh > /tmp/wire.pcap
#        then in another terminal:  RECKON_E2E_CLUSTER=1 RECKON_E2E_GATEWAY=beam01.lab:50051 rebar3 ct --suite=...
set -euo pipefail

DURATION_S="${1:-30}"
# shellcheck disable=SC2029  # the capture window is this script's argument; the remote side only runs tcpdump for that long
ssh rl@beam01.lab "sudo timeout ${DURATION_S} tcpdump -i any -nn -X -s 0 'port 50051' 2>&1 | head -200"
