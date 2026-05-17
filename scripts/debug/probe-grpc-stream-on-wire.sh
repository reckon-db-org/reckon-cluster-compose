#!/usr/bin/env bash
# Tap port 50051 on beam01 with tcpdump while a subscribe runs from
# the e2e harness. Confirms whether the server actually sends any
# HTTP/2 DATA frames after the subscribe, or stays silent past the
# initial HEADERS frame.
#
# Usage: bash probe-grpc-stream-on-wire.sh > /tmp/wire.pcap
#        then in another terminal:  RECKON_E2E_CLUSTER=1 RECKON_E2E_GATEWAY=beam01.lab:50051 rebar3 ct --suite=...
set -euo pipefail

DURATION_S="${1:-30}"
ssh rl@beam01.lab "sudo timeout ${DURATION_S} tcpdump -i any -nn -X -s 0 'port 50051' 2>&1 | head -200"
