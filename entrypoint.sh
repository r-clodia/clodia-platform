#!/usr/bin/env bash
# Entrypoint di ogni container Clodia.
# Clona o aggiorna il bundle da GitHub prima di avviare il servizio.
set -euo pipefail

BRANCH="${GIT_BRANCH:-main}"
GIT_REPO_SLUG="${GIT_REPO:-r-clodia/clodia-logic}"

# Preferisci il token dal mount secrets/ (no env exposure via docker inspect).
# Fallback su GIT_TOKEN env solo per retrocompatibilita.
if [ -f /clodia/secrets/github_token ]; then
    GIT_TOKEN="$(tr -d "\n\r" < /clodia/secrets/github_token)"
fi

if [ -n "${GIT_TOKEN:-}" ]; then
    REPO="https://x-access-token:${GIT_TOKEN}@github.com/${GIT_REPO_SLUG}.git"
else
    REPO="https://github.com/${GIT_REPO_SLUG}.git"
fi

# Clone in /tmp per evitare conflitti con i mount points già presenti in /clodia
CLONE_DIR="/tmp/clodia-bundle-src"
rm -rf "$CLONE_DIR"

# Sempre clone fresco in /tmp + rsync: evita problemi con i mount points
# read-only (secrets/:ro) che bloccano git reset --hard su /clodia.
echo "[entrypoint] Clono $BRANCH in $CLONE_DIR..."
git clone --depth=1 -b "$BRANCH" "$REPO" "$CLONE_DIR" \
    || { echo "[entrypoint] ERRORE: clone fallito"; exit 1; }

# Se abbiamo clonato in /tmp, copiamo in /clodia preservando i mount points
if [ "$CLONE_DIR" != "/clodia" ]; then
    echo "[entrypoint] Copio bundle in /clodia (preservo mount points)..."
    # Esclude le directory gestite dalla datadir (sono già montate da docker-compose)
    rsync -a --exclude='.git' \
        --exclude='secrets' --exclude='data' --exclude='topics' \
        --exclude='contacts.db' --exclude='boot/VIOLATION.md' \
        --exclude='boot/retrospectives' --exclude='dump' \
        "$CLONE_DIR/" /clodia/
    # Salva il .git per i pull successivi
    cp -r "$CLONE_DIR/.git" /clodia/.git
    git -C /clodia remote set-url origin https://github.com/${GIT_REPO_SLUG}.git
    rm -rf "$CLONE_DIR"
fi

echo "[entrypoint] Bundle pronto"

# Credential helper per git fetch/pull MANUALI sul repo privato: legge il token
# dal mount secrets/ a ogni chiamata (mai scritto in .git/config né in chiaro).
# L'auto-clone usa già un URL con token costruito sopra; questo serve ai pull a
# mano (es. hotfix o allineamento del checkout /clodia a origin/main).
if [ -f /clodia/secrets/github_token ]; then
    git config --global credential.helper '!f() { echo username=x-access-token; echo "password=$(tr -d "\n\r" < /clodia/secrets/github_token)"; }; f'
    echo "[entrypoint] git credential.helper configurato (token da secrets/)"
fi

# ~/.claude.json è fuori dal mount /root/.claude/ → sparisce ad ogni ricreazione
# del container. Lo ricreiamo all'avvio se mancante.
# Prima prova: ripristina dal backup nel mount (leggibile solo se i permessi lo permettono).
# Fallback: file minimal che consente a Claude Code di avviarsi con ANTHROPIC_API_KEY.
if [ ! -f "/root/.claude.json" ]; then
    backup=$(ls /root/.claude/backups/.claude.json.backup.* 2>/dev/null | sort -t. -k5 -n | tail -1 || true)
    if [ -n "$backup" ] && [ -r "$backup" ]; then
        cp "$backup" /root/.claude.json
        echo "[entrypoint] Ripristinato /root/.claude.json da $backup"
    else
        printf '{"hasCompletedOnboarding":true,"telemetryEnabled":false}\n' > /root/.claude.json
        echo "[entrypoint] Creato /root/.claude.json minimal (backup non leggibile)"
    fi
fi

# Nessun frontend embedded: la webui ufficiale è clodia-web (servita a parte).
# (rimosso il build SvelteKit embedded col refactor v4.)

# Installa dipendenze Python se presenti (dopo il git pull)
# Post-refactor v4: requirements.txt alla root del repo.
REQ="/clodia/requirements.txt"
if [ -f "$REQ" ]; then
    echo "[entrypoint] pip install -r $REQ ..."
    pip install --no-cache-dir -q -r "$REQ"
fi

# ── Auto-bootstrap (Flusso 0 / clonabilità) ────────────────────────────────
# Solo per l'agent-server (gate: esiste il modulo PKI). Idempotente:
#   - se il datadir non è inizializzato (agents/ vuoto) → init-datadir;
#   - bootstrap PKI: CA + identità dei super-agent (init-ca/issue-all sono no-op
#     se già presenti).
# Così un nuovo owner fa "docker compose up" su datadir vuoto e ottiene l'agency
# pronta (poi connette i provider da UI).
# Post-refactor v4: il pacchetto server/ è alla root del repo (/clodia).
AS_DIR="/clodia"
if [ -f "$AS_DIR/server/colony/pki.py" ]; then
    if [ ! -d /datadir/agents ] || [ -z "$(ls -A /datadir/agents 2>/dev/null)" ]; then
        echo "[entrypoint] datadir non inizializzato -> init-datadir"
        bash /clodia/docker/init-datadir.sh /datadir || echo "[entrypoint] WARN: init-datadir fallito"
    fi
    if [ -n "${CLODIA_ORCHESTRATOR_SECRET:-}" ]; then
        # Runtime KEYLESS (M3++): le chiavi private vivono nel gateway, non qui.
        # La bootstrap PKI (init-ca/issue-all) è responsabilità del trust-anchor
        # (il gateway la fa nel suo lifespan). Qui la saltiamo per non forgiare
        # una CA divergente nel volume runtime.
        echo "[entrypoint] runtime keyless -> PKI bootstrap delegata al gateway (skip)"
    else
        echo "[entrypoint] bootstrap PKI (idempotente)..."
        ( cd "$AS_DIR" && CLODIA_DATA=/datadir python3 -m server.colony.pki init-ca 2>/dev/null \
            && CLODIA_DATA=/datadir python3 -m server.colony.pki issue-all 2>/dev/null ) \
            || echo "[entrypoint] WARN: bootstrap PKI saltato"
    fi
    # Hardening perms (M3): segreti e vault leggibili SOLO da root. Il subprocess
    # dell'agente gira non-root (sandbox) → non li legge. Idempotente.
    for d in /datadir/secrets /datadir/clodia-vault; do
        [ -d "$d" ] && chmod 700 "$d" 2>/dev/null || true
    done
    # /proc-full (M3+): il subprocess agente (non-root) deve vedere SOLO il proprio
    # spawn. `/datadir` e `/datadir/spawns` traversabili (711, niente listing/read);
    # ogni altra voce root-only (700). I singoli spawn sono già 700 di proprietà del
    # loro uid (chown in session.py). L'orchestrator/gateway sono root → ignorano i
    # permessi. Idempotente. Vuoto CLODIA_AGENT_SANDBOX_UID = OFF → lockdown saltato.
    if [ -n "${CLODIA_AGENT_SANDBOX_UID:-}" ] && [ -d /datadir ]; then
        chmod 711 /datadir 2>/dev/null || true
        for e in /datadir/* /datadir/.[!.]*; do
            [ -e "$e" ] || continue
            case "$e" in
                /datadir/spawns) chmod 711 "$e" 2>/dev/null || true ;;
                *) chmod 700 "$e" 2>/dev/null || true ;;
            esac
        done
    fi
fi

echo "[entrypoint] Avvio: $*"
exec "$@"
