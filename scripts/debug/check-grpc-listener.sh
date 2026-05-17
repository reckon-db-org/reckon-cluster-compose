#!/usr/bin/env bash
#
# Inspect the gateway's gRPC listener state on a beam node from inside
# the BEAM. Looks for: cowboy listener on the configured port, whether
# the grpc app is started, and whether the registered grpc service
# names match what we expect.
#
# Usage: ./check-grpc-listener.sh <host>

set -eu

HOST="${1:-beam01.lab}"

ssh "rl@${HOST}" "docker exec reckon-gateway /app/bin/reckon_gateway eval '
    Apps = [A || {A, _, _} <- application:which_applications()],
    HasGrpc = lists:member(grpc, Apps),
    Listeners = try ranch:info() of L -> L catch _:_:_ -> ranch_error end,
    Services = try grpc_lib:services() of S -> S catch _:_:_ -> grpc_lib_error end,
    {apps, length(Apps), grpc, HasGrpc, listeners, Listeners, services, Services}.
'"
