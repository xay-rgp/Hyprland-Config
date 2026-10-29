#!/usr/bin/env bash
set -euo pipefail
config_dir="$(dirname "$(readlink -f "$0")")"
restart=false
if [[ "${1:-}" == --restart ]]; then
    restart=true
    shift
fi
# Stop only the previous standalone copy, or this config when restarting.
# Plain launches are idempotent and never kill the new default bar itself.
instances=$(qs list --all --json)
mapfile -t old_ids < <(printf '%s' "$instances" | python3 -c '
import json, sys
current, legacy, restart = sys.argv[1:]
for instance in json.load(sys.stdin):
    path = instance.get("config_path")
    if (path == legacy and path != current) or (restart == "true" and path == current):
        print(instance["id"])
' "$config_dir/shell.qml" "$HOME/quickshell-bar/shell.qml" "$restart")
for instance_id in "${old_ids[@]}"; do
    qs kill --id "$instance_id"
done
exec qs --no-duplicate --path "$config_dir" "$@"
