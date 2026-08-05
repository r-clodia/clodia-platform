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

# Control-plane agent-server↔gateway: genera una volta un secret non esportato
# ai subprocess agentici. Necessario anche per il canale file cifrato /shared.
if [ -z "${CLODIA_ORCHESTRATOR_SECRET:-}" ]; then
  _clodia_orchestrator_secret="$(openssl rand -hex 32)"
  sed -i.bak "s/^CLODIA_ORCHESTRATOR_SECRET=.*/CLODIA_ORCHESTRATOR_SECRET=${_clodia_orchestrator_secret}/" "$ROOT/.env"
  rm -f "$ROOT/.env.bak"
  export CLODIA_ORCHESTRATOR_SECRET="$_clodia_orchestrator_secret"
  echo "    generato CLODIA_ORCHESTRATOR_SECRET"
fi
mkdir -p "${CLODIA_DATA:-$ROOT/clodia-data}"
# Stato decisionale del gateway (whitelist/gate/deleghe): directory a parte,
# montata dal SOLO container clodia-tools. Se stesse nella datadir la
# vedrebbe anche l'agent-server, dove girano gli agenti (issue #80).
_gw_state="${CLODIA_GATEWAY_STATE:-$ROOT/gateway-state}"
mkdir -p "$_gw_state"
chmod 700 "$_gw_state" 2>/dev/null || true

echo ""
echo "Setup completato. Prossimi passi:"
echo "  1) Edita .env: CLODIA_BASE_EMAIL e CLODIA_AGENT_EGRESS_PROXY."
echo "     ANTHROPIC_API_KEY puo restare VUOTA: le credenziali dei provider si"
echo "     collegano dalla webui e vivono nel vault, non nel .env (passo 5)."
echo "     CLODIA_AGENT_EGRESS_PROXY e OBBLIGATORIA: la rete dell agent-server e"
echo "     'internal' (senza DNS), quindi senza proxy il clone del sorgente"
echo "     FALLISCE al boot e il container entra in loop di restart."
echo "  2) Build immagini base, IN SEQUENZA (bundle dipende da base):"
echo "       docker compose --profile build-only build base"
echo "       docker compose --profile build-only build bundle"
echo "  3) Avvia:                docker compose up -d --build"
echo "  4) Apri la webui su http://localhost:\${WEBUI_PORT:-7843} e fai il bootstrap"
echo "     admin (Nuovo utente, tipo human). SALVA la recovery key: si vede una"
echo "     volta sola. Le porte sono su 127.0.0.1 per default: da remoto serve un"
echo "     proxy esplicito (es. 'tailscale serve'), o CLODIA_BIND_HOST."
echo "  5) Collega i provider/credenziali dalla sezione Tools (OAuth o paste-key)"
echo ""
echo "Su macOS: vedi docs/install-macos.md (runtime container, e perche la datadir"
echo "NON va in una cartella del Mac)."
