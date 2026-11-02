#!/bin/sh
# Runs each plumb binary on every fetched app in apps_pinned.tsv.
# Usage: study/2026-11-launch/run.sh <study-dir> <plumb-binary>...
# Writes results/<version>/<owner>_<repo>.json and .txt (--verbose).
set -u
here=$(cd "$(dirname "$0")" && pwd)
study=$1; shift
for bin in "$@"; do
  v=$("$bin" --version | awk '{print $NF}')
  mkdir -p "$here/results/$v"
  tail -n +2 "$here/apps_pinned.tsv" | while IFS="$(printf '\t')" read -r repo app sha stars pushed n; do
    f=$(echo "$repo" | tr / _)
    "$bin" doctor "$study/$f/$app" --json > "$here/results/$v/$f.json"
    echo "$v $repo exit=$?"
    "$bin" doctor "$study/$f/$app" --verbose --no-color > "$here/results/$v/$f.txt" 2>&1
  done
done
