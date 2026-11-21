#!/usr/bin/env bash
# Copy a file or folder OUT of the datadir volume to the host (#554).
#
# Usage: scripts/datadir-export.sh <path> <dest>
#   <path>  path inside the datadir, relative to /datadir (e.g. topics/SEAL-1/acme,
#           audit/2026-11.jsonl). `agents/...` is read from the seeds volume.
#   <dest>  host directory to copy into (created if missing). The copy lands at
#           <dest>/<basename of path>, owned by the user running the script.
#
# The volume is mounted read-only: exporting never changes the instance. What
# you copy out, though, leaves the volume's protection — a copy of
# clodia-vault/ or secrets/ on the host is as readable as any other file there.
set -euo pipefail
# shellcheck source=scripts/datadir-common.sh
. "$(dirname "${BASH_SOURCE[0]}")/datadir-common.sh"

[ $# -eq 2 ] || die "usage: $0 <path-inside-datadir> <host-dest-dir>"
rel="${1#/datadir}"; rel="${rel#/}"; rel="${rel%/}"
[ -n "$rel" ] && [ "$rel" != "." ] || die "name a path inside the datadir, not the whole volume"
case "/$rel/" in */../*) die "'..' is not allowed in the path" ;; esac
dest="$2"
mkdir -p "$dest"
dest="$(cd "$dest" && pwd -P)"

need_docker
volume_exists "$VOLUME" || die "volume $VOLUME not found (CLODIA_DATA_VOLUME?)"

case "$rel" in
  clodia-vault|clodia-vault/*|secrets|secrets/*|pki|pki/*)
    echo "WARNING: '$rel' holds credentials or keys. The copy in $dest is protected only by the host's permissions." >&2 ;;
esac

args=(--rm --network none -v "$VOLUME":/datadir:ro -v "$dest":/out)
if volume_exists "${PROJECT}_clodia-agents"; then
  args+=(-v "${PROJECT}_clodia-agents":/datadir/agents:ro)
fi
name="$(basename "$rel")"
docker run "${args[@]}" "$HELPER_IMAGE" sh -euc '
  src="/datadir/$1"
  [ -e "$src" ] || { echo "ERROR: /datadir/$1 does not exist" >&2; exit 1; }
  [ ! -e "/out/$2" ] || { echo "ERROR: $2 already exists in the destination: refusing to overwrite" >&2; exit 1; }
  cp -R -p "$src" "/out/$2"
  chown -R "$3:$4" "/out/$2"
' _ "$rel" "$name" "$(id -u)" "$(id -g)"
echo "exported /datadir/$rel -> $dest/$name"
