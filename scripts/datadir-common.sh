# shellcheck shell=bash
# Shared by the datadir helper scripts (clodia-platform#554). Sourced, not run.
#
# Reads `.env` from the repository root (as `docker compose` does) and sets:
#   ROOT         repository root
#   VOLUME       the datadir volume name (CLODIA_DATA_VOLUME, default clodia-data)
#   HELPER_IMAGE the throwaway image used to reach the volume
#   PROJECT      the compose project name (for the project-scoped volumes)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$ROOT/.env"
  set +a
fi
# shellcheck disable=SC2034  # the next three are used by the sourcing scripts
VOLUME="${CLODIA_DATA_VOLUME:-clodia-data}"
# Pinned minor: the scripts only need busybox `cp`, `find`, `du`, `stat`, `sh`.
# shellcheck disable=SC2034
HELPER_IMAGE="${CLODIA_HELPER_IMAGE:-alpine:3.20}"
# Same rule as compose: COMPOSE_PROJECT_NAME, else the directory name.
# shellcheck disable=SC2034
PROJECT="${COMPOSE_PROJECT_NAME:-$(basename "$ROOT" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')}"

die() { echo "ERROR: $*" >&2; exit 1; }

need_docker() {
  command -v docker >/dev/null 2>&1 || die "docker not found in PATH"
  docker info >/dev/null 2>&1 || die "the docker daemon is not reachable (is the runtime started?)"
}

volume_exists() { docker volume inspect "$1" >/dev/null 2>&1; }
