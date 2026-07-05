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

# ~/.claude.json è fuori dal mount /root/.claude/ → sparisce ad ogni ricreazione
# del container. Lo ricreiamo all'avvio se mancante.
# Prima prova: ripristina dal backup nel mount (leggibile solo se i permessi lo permettono).
# Fallback: file minimal che consente a Claude Code di avviarsi con ANTHROPIC_API_KEY.
if [ ! -f "/root/.claude.json" ]; then
    backup=$(ls /root/.claude/backups/.claude.json.backup.* 2>/dev/null | sort -t. -k5 -n | tail -1)
    if [ -n "$backup" ] && [ -r "$backup" ]; then
        cp "$backup" /root/.claude.json
        echo "[entrypoint] Ripristinato /root/.claude.json da $backup"
    else
        printf '{"hasCompletedOnboarding":true,"telemetryEnabled":false}\n' > /root/.claude.json
        echo "[entrypoint] Creato /root/.claude.json minimal (backup non leggibile)"
    fi
fi

# Build del frontend SvelteKit (solo agent-server; gli altri container saltano)
FRONTEND="/clodia/tools/system/agent-server/frontend"
BUILD_OUT="$FRONTEND/build"
if [ -d "$FRONTEND" ] && [ "${SKIP_FRONTEND_BUILD:-false}" != "true" ]; then
    needs_build=false
    if [ ! -d "$BUILD_OUT" ]; then
        needs_build=true
    elif [ -n "$(find "$FRONTEND/src" -newer "$BUILD_OUT" -type f 2>/dev/null | head -1)" ]; then
        needs_build=true
    fi
    if [ "$needs_build" = "true" ]; then
        echo "[entrypoint] Build frontend..."
        cd "$FRONTEND"
        npm ci --silent 2>/dev/null || npm install --silent
        npm run build --silent
        cd /
    else
        echo "[entrypoint] Frontend build aggiornata, skip."
    fi
fi

# Installa dipendenze Python se presenti (dopo il git pull)
REQ="/clodia/tools/system/agent-server/requirements.txt"
if [ -f "$REQ" ]; then
    echo "[entrypoint] pip install -r $REQ ..."
    pip install --no-cache-dir -q -r "$REQ"
fi

echo "[entrypoint] Avvio: $*"
exec "$@"
