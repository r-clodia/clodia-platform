#!/usr/bin/env bash
# Copy a bind-mounted datadir into the named volume `clodia-data` (#554).
#
# Usage: scripts/migrate-datadir-to-volume.sh [BIND_PATH]
#   BIND_PATH  the host folder that was mounted on /datadir
#              (default: CLODIA_DATA from .env)
#   Volume:    CLODIA_DATA_VOLUME from .env, default `clodia-data`.
#
# BEFORE running it, the operator stops agent-server and clodia-tools — after
# checking that no turn is in flight (a copy taken under a running instance is
# not consistent):
#   docker compose stop agent-server clodia-tools
#
# What it does: refuses if the two services are running or if the volume exists
# and is not empty; creates the volume; copies with `cp -a` (owners, modes,
# timestamps, symlinks preserved) from a read-only mount of the bind; compares
# file counts and total bytes; prints the next steps.
# What it never does: delete or modify the bind. It stays as the rollback.
set -euo pipefail
# shellcheck source=scripts/datadir-common.sh
. "$(dirname "${BASH_SOURCE[0]}")/datadir-common.sh"

BIND="${1:-${CLODIA_DATA:-}}"
[ -n "$BIND" ] || die "no bind path: pass it as argument or set CLODIA_DATA in .env"
case "$BIND" in /*) ;; *) BIND="$ROOT/${BIND#./}" ;; esac
if [ -d "$BIND" ]; then
  BIND="$(cd "$BIND" && pwd -P)"
else
  # Colima & co.: the documented macOS layout kept the datadir INSIDE the VM
  # (e.g. /var/clodia-data), invisible from the host. The docker daemon
  # resolves it; `--mount` (unlike `-v`) refuses a path that does not exist
  # instead of creating an empty one.
  echo "==> $BIND is not visible from this host: letting the docker daemon resolve it"
fi
SRC_MOUNT="type=bind,src=$BIND,dst=/src,readonly"

need_docker

running="$(cd "$ROOT" && docker compose ps --status running -q agent-server clodia-tools 2>/dev/null || true)"
[ -z "$running" ] || die "agent-server and/or clodia-tools are running. Check that no turn is in flight, then: docker compose stop agent-server clodia-tools"

if volume_exists "$VOLUME"; then
  first="$(docker run --rm --network none -v "$VOLUME":/dst:ro "$HELPER_IMAGE" sh -c 'ls -A /dst | head -n 1')"
  [ -z "$first" ] || die "volume $VOLUME exists and is not empty: refusing to merge into it. Inspect it with scripts/datadir-shell.sh, or choose another CLODIA_DATA_VOLUME."
  echo "==> volume $VOLUME exists and is empty: reusing it"
else
  echo "==> creating volume $VOLUME"
  docker volume create "$VOLUME" >/dev/null
fi

# An empty source would "verify" perfectly (1 entry = 1 entry) and leave an
# empty volume that boots as a brand-new instance: refuse it.
src_first="$(docker run --rm --network none --mount "$SRC_MOUNT" "$HELPER_IMAGE" sh -c 'ls -A /src | head -n 1')" \
  || die "cannot mount $BIND (does it exist where the docker daemon runs?)"
[ -n "$src_first" ] || die "$BIND is empty: nothing to migrate (wrong path?)"

echo "==> copying $BIND -> volume $VOLUME"
docker run --rm --network none --mount "$SRC_MOUNT" -v "$VOLUME":/dst "$HELPER_IMAGE" cp -a /src/. /dst/

# Counts and bytes are exact; `du` is reported but not compared, because block
# accounting differs between filesystems (virtiofs vs ext4).
# shellcheck disable=SC2016  # expanded by the sh inside the helper container
measure='cd "$1" && printf "%s %s %s\n" "$(find . | wc -l)" "$(find . -type f -exec stat -c %s {} + | awk "{s+=\$1} END {print s+0}")" "$(du -sk . | cut -f1)"'
read -r src_n src_b src_k < <(docker run --rm --network none --mount "$SRC_MOUNT" "$HELPER_IMAGE" sh -c "$measure" _ /src)
read -r dst_n dst_b dst_k < <(docker run --rm --network none -v "$VOLUME":/dst:ro "$HELPER_IMAGE" sh -c "$measure" _ /dst)

printf '\n%-8s %12s %16s %12s\n' "" "entries" "bytes (files)" "du (KiB)"
printf '%-8s %12s %16s %12s\n' "bind" "$src_n" "$src_b" "$src_k"
printf '%-8s %12s %16s %12s\n' "volume" "$dst_n" "$dst_b" "$dst_k"

if [ "$src_n" != "$dst_n" ] || [ "$src_b" != "$dst_b" ]; then
  die "the copy does not match the source. The bind is untouched; inspect the volume (scripts/datadir-shell.sh), then 'docker volume rm $VOLUME' and retry."
fi

cat <<NEXT

Copy verified. The bind at $BIND has NOT been touched.

Next steps:
  1. Make sure .env does NOT select the bind override: no
     docker-compose.datadir-bind.yml in COMPOSE_FILE. CLODIA_DATA is no longer
     read by the default compose file (leave it, it documents the rollback).
  2. Start:   docker compose up -d agent-server clodia-tools
  3. Check:
     - clodia-tools log: no "DATADIR NOT ISOLATED" line (#554);
     - agent-server log: the boundary self-test reports every store denied to
       the sandbox uid (clodia-logic boot hardening re-applies 700/600).
  4. Keep the bind as the rollback until the instance has run cleanly; then
     archive or delete it yourself. To roll back: stop the two services and
     set COMPOSE_FILE=docker-compose.yml:docker-compose.datadir-bind.yml
     (Linux hosts only — never on macOS, see docs/install-macos.md).
  5. Backups: the datadir is now inside the Docker VM/host, not a host folder.
     Browse it with scripts/datadir-shell.sh, copy out with
     scripts/datadir-export.sh.
NEXT
