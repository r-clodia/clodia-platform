#!/usr/bin/env bash
# Clodia Agency — setup build-from-source.
# Clona i repo sorgente in ./repos, prepara la datadir e il file .env.
set -euo pipefail

ORG="${CLODIA_GH_ORG:-r-clodia}"
BRANCH="${CLODIA_GIT_BRANCH:-main}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Repo che si buildano da sorgente (clodia-logic viene clonato a runtime
# dall'agent-server, quindi non serve qui).
REPOS=(clodia-tools clodia-web clodia-pwa)

echo "==> Clono i repo sorgente da github.com/${ORG} (branch ${BRANCH})"
mkdir -p "$ROOT/repos"
for r in "${REPOS[@]}"; do
  dest="$ROOT/repos/$r"
  if [ -d "$dest/.git" ]; then
    echo "    $r già presente → git pull"
    git -C "$dest" pull --ff-only
  else
    git clone --depth=1 -b "$BRANCH" "https://github.com/${ORG}/${r}.git" "$dest"
  fi
done

echo "==> Preparo la datadir"
# La datadir contiene TUTTI i dati dell'istanza (secrets, topics, db, pki…).
# Vive fuori dal repo: di default ./clodia-data, override con CLODIA_DATA in .env.
if [ ! -f "$ROOT/.env" ]; then
  cp "$ROOT/.env.example" "$ROOT/.env"
  echo "    creato .env da .env.example — EDITALO prima di avviare (ANTHROPIC_API_KEY, CLODIA_DATA, CLODIA_BASE_EMAIL)"
fi
# shellcheck disable=SC1090
set -a; . "$ROOT/.env"; set +a
mkdir -p "${CLODIA_DATA:-$ROOT/clodia-data}"

echo ""
echo "Setup completato. Prossimi passi:"
echo "  1) Edita .env (ANTHROPIC_API_KEY, CLODIA_DATA, CLODIA_BASE_EMAIL)"
echo "  2) Build immagini base:  docker compose --profile build-only build base bundle"
echo "  3) Avvia:                docker compose up -d --build"
echo "  4) Apri la webui su http://localhost:\${WEBUI_PORT:-7843} e fai il bootstrap admin"
echo "  5) Collega i provider/credenziali dalla sezione Tools (OAuth o paste-key)"
