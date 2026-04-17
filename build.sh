#! /bin/sh
set -eu

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --output type=local,dest=./dist \
   -t haproxy-static:3.3 .

# Refresh ./dist/<arch>/haproxy-latest as a copy of the newest haproxy-<ver>.
# A real copy (not a symlink) is required because raw.githubusercontent.com
# serves symlink text instead of dereferencing; identical content is deduped
# by git's blob SHA, so no repo bloat.
for arch_dir in ./dist/linux_*/; do
  [ -d "$arch_dir" ] || continue
  latest=$(ls -1 "$arch_dir"haproxy-[0-9]* 2>/dev/null | sort -V | tail -n1)
  [ -n "$latest" ] || continue
  cp -f "$latest" "${arch_dir}haproxy-latest"
  echo "updated ${arch_dir}haproxy-latest -> $(basename "$latest")"
done