#!/usr/bin/env bash
# Move one application's audio stream to another device.
#
#   audio-route.sh sink   <stream node id> <sink node name>
#   audio-route.sh source <stream node id> <source node name>
#
# The shell knows streams by their PipeWire node id, but pactl addresses them
# by its own sink-input/source-output index, so look that up first.
# WirePlumber remembers the choice for that application.
set -euo pipefail

kind=$1 id=$2 dev=$3
case $kind in
    sink)   list=sink-inputs;    move=move-sink-input ;;
    source) list=source-outputs; move=move-source-output ;;
    *) echo "usage: $0 sink|source <node id> <device name>" >&2; exit 2 ;;
esac

idx=$(pactl -f json list "$list" \
    | jq -r --arg id "$id" '.[] | select((.properties["object.id"] | tostring) == $id) | .index' \
    | head -n1)

[ -n "$idx" ] || { echo "no $list entry for node $id" >&2; exit 1; }
pactl "$move" "$idx" "$dev"
