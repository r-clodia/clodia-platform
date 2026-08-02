#!/usr/bin/env bash
# Test NEGATIVI del confine piano-agenti → gateway (issue clodia-platform#80).
#
# Ogni check verifica che qualcosa NON sia possibile dal container dove girano
# gli agenti (`agent-server`). Un check che "riesce" e' una falla: il gateway e'
# il reference monitor solo se e' l'unica via, e cio' che vive nello stesso
# filesystem/rete degli agenti non e' protetto da lui.
#
# Eseguilo con l'utente di default dei container (root, come fa `docker exec`):
# con un uid ristretto alcuni check "passano" solo perche' il processo non ha i
# permessi di guardare, e il risultato sarebbe piu' rassicurante del vero.
#
# Uso (dalla radice del deploy, con lo stack su):
#   ./docker/test-plane-isolation.sh          # esce !=0 se un check BLOCCANTE fallisce
#   STRICT=1 ./docker/test-plane-isolation.sh # esce !=0 anche sui gap noti (DoD completa)
#
# Env: COMPOSE (default "docker compose"), AGENT_SERVICE, TOOLS_SERVICE.
set -uo pipefail

COMPOSE=${COMPOSE:-docker compose}
AGENT=${AGENT_SERVICE:-agent-server}
TOOLS=${TOOLS_SERVICE:-clodia-tools}
STRICT=${STRICT:-0}

pass=0 fail=0 gap=0

ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; pass=$((pass + 1)); }
ko()   { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail + 1)); }
todo() { printf '  \033[33mGAP \033[0m  %s\n' "$1"; gap=$((gap + 1)); }

in_agent() { $COMPOSE exec -T "$AGENT" sh -c "$1" >/dev/null 2>&1; }
in_tools() { $COMPOSE exec -T "$TOOLS" sh -c "$1" 2>/dev/null; }

echo "Confine piano-agenti → gateway (issue #80)"
echo "  agent-server: $AGENT   gateway: $TOOLS"
echo ""

# ── Preflight ───────────────────────────────────────────────────────────────
# Senza questo, un container spento farebbe passare TUTTI i check negativi
# ("il file non c'e'" perche' non c'e' il container): il test mentirebbe nella
# direzione peggiore. Il canale exec va dimostrato funzionante prima.
if ! in_agent 'true'; then
  echo "ERRORE: 'exec' su $AGENT non funziona (stack spento?). Nessun check eseguito." >&2
  exit 3
fi
if ! in_agent 'test -d /datadir'; then
  echo "ERRORE: /datadir non montato in $AGENT: il deploy non e' quello atteso." >&2
  exit 3
fi
if in_agent 'test -e /__sanity_check_inesistente__'; then
  echo "ERRORE: $AGENT risponde OK anche su un path inesistente (COMPOSE stub?)." >&2
  exit 3
fi
if ! in_tools 'true' >/dev/null; then
  echo "ERRORE: 'exec' su $TOOLS non funziona (gateway giu'?)." >&2
  exit 3
fi

echo "── Bloccanti ───────────────────────────────────────────────────────────"

# 1. La state dir del gateway non esiste nel filesystem dell'agent-server.
if in_agent 'test -e /gateway-state'; then
  ko "/gateway-state e' visibile dall'agent-server (volume montato da entrambi?)"
else
  ok "/gateway-state non esiste nel container degli agenti"
fi

# 2. Il gateway usa davvero una state dir separata dalla datadir condivisa.
STATE_DIR=$(in_tools 'python3 -c "from server import state_paths; print(state_paths.state_dir())"' | tr -d '\r')
ISOLATED=$(in_tools 'python3 -c "from server import state_paths; print(state_paths.is_isolated())"' | tr -d '\r')
if [ "$ISOLATED" = "True" ]; then
  ok "stato del gateway isolato dalla datadir condivisa (state_dir=$STATE_DIR)"
else
  ko "stato del gateway ancora in CLODIA_DATA (state_dir=${STATE_DIR:-?}); imposta CLODIA_TOOLS_STATE_DIR"
fi

# 3. I file di stato che il gateway legge NON sono raggiungibili dagli agenti:
#    e' il test che l'issue chiede ("scrivere clodia-tools-config.yaml fallisce").
for f in clodia-tools-config.yaml clodia-tools-gate.json clodia-tools-gate-revoked.json \
         clodia-tools-gate-requests.json delegations/active.jsonl; do
  target="${STATE_DIR:-/gateway-state}/$f"
  if in_agent "test -e '$target'"; then
    ko "$target raggiungibile dall'agent-server"
  else
    ok "$target non raggiungibile dall'agent-server"
  fi
done

# 4. Il residuo legacy sulla datadir condivisa, se c'e', non e' piu' quello letto.
if in_agent 'test -e /datadir/clodia-tools-config.yaml'; then
  if [ "$ISOLATED" = "True" ]; then
    ok "copia legacy presente su /datadir ma inerte (il gateway legge $STATE_DIR)"
  else
    ko "il gateway legge /datadir/clodia-tools-config.yaml, scrivibile dal piano agenti"
  fi
else
  ok "nessuna copia legacy su /datadir"
fi

echo ""
echo "── Gap noti di #80 (non ancora chiusi; STRICT=1 li rende bloccanti) ─────"

# 5. Egress diretto verso internet dal container degli agenti (punto 2 di #80):
#    richiede la separazione piano-agenti / piano-core, perche' l'agent-server
#    ospita anche orchestratore e poller che internet lo usano legittimamente.
if in_agent 'python3 -c "import urllib.request as u; u.urlopen(\"https://api.github.com\", timeout=5)"'; then
  todo "egress internet diretto APERTO dall'agent-server (curl/urllib scavalcano il gateway)"
else
  ok "egress internet negato dal container degli agenti"
fi

# 6. Vault e file dei topic non leggibili dal filesystem degli agenti.
if in_agent 'test -n "$(ls -A /datadir/clodia-vault 2>/dev/null)"'; then
  todo "/datadir/clodia-vault popolato nel container degli agenti (manca la maschera del vault)"
else
  ok "/datadir/clodia-vault vuoto o assente nel container degli agenti"
fi

# 7. Vault cifrato a riposo (SECURITY.md 8.24) — oggi solo permessi OS.
if in_tools 'python3 -c "import os,sys; sys.exit(0 if os.environ.get(\"CLODIA_VAULT_ENCRYPTION\") else 1)" && echo yes' | grep -q yes; then
  ok "cifratura del vault a riposo attiva"
else
  todo "vault non cifrato a riposo (SECURITY.md 8.24 resta PARZ)"
fi

echo ""
printf 'pass=%d  fail=%d  gap=%d\n' "$pass" "$fail" "$gap"
if [ "$fail" -gt 0 ]; then exit 1; fi
if [ "$STRICT" = "1" ] && [ "$gap" -gt 0 ]; then exit 2; fi
exit 0
