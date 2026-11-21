#!/usr/bin/env bash
# Browse the datadir volume READ-ONLY in a throwaway shell (#554).
#
# Usage: scripts/datadir-shell.sh
#
# The datadir is a named Docker volume, not a host folder: this is the owner's
# way to look inside. Everything is mounted read-only, so nothing you do here
# can change the instance; `exit` discards the container. The agent seeds live
# in their own volume and are mounted at /datadir/agents when it exists.
#
# The shell runs as root: it shows EVERYTHING, vault and secrets included.
# Use it from a trusted terminal; to copy something out, scripts/datadir-export.sh.
set -euo pipefail
# shellcheck source=scripts/datadir-common.sh
. "$(dirname "${BASH_SOURCE[0]}")/datadir-common.sh"

need_docker
volume_exists "$VOLUME" || die "volume $VOLUME not found (CLODIA_DATA_VOLUME?)"

args=(--rm -it --network none -v "$VOLUME":/datadir:ro -w /datadir)
if volume_exists "${PROJECT}_clodia-agents"; then
  args+=(-v "${PROJECT}_clodia-agents":/datadir/agents:ro)
fi
echo "datadir volume $VOLUME, read-only. 'exit' to leave." >&2
exec docker run "${args[@]}" "$HELPER_IMAGE" sh
