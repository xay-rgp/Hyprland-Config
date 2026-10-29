#!/usr/bin/env bash
set -euo pipefail
config_dir="$(dirname "$(readlink -f "$0")")"
mapfile -t packages < "$config_dir/packages.txt"
missing=()
for package in "${packages[@]}"; do
    pacman -Q "$package" >/dev/null 2>&1 || missing+=("$package")
done
if ((${#missing[@]})); then
    sudo pacman -S --needed "${missing[@]}"
else
    echo 'All bar and shortcut dependencies are installed.'
fi
