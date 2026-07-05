#!/usr/bin/env bash
# Inizializza una datadir vuota per un'installazione pristine di Clodia.
# Uso: bash docker/init-datadir.sh /path/to/clodia-data
#
# Lo schema dei DB (logica) sta nel bundle (docker/schema/).
# I dati dell'istanza (righe) stanno nella datadir.
set -euo pipefail

DATADIR="${1:-$HOME/clodia-data}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Inizializzazione datadir: $DATADIR"
mkdir -p "$DATADIR"/{secrets,data,topics,boot/retrospectives,daemon-state/{whatsapp,telegram,check-mail},claude-home,codex-home,agents,agent-workspaces,agent-state,agency-shared,skills-catalog,rules-catalog}

# DB: crea file vuoti e applica lo schema (logica nel bundle, dati nella datadir)
if command -v sqlite3 &>/dev/null; then
    echo "Applicazione schema contacts.db..."
    sqlite3 "$DATADIR/contacts.db" < "$BUNDLE_ROOT/docker/schema/contacts.sql"
else
    echo "⚠️  sqlite3 non trovato — DB creati vuoti senza schema. Installare sqlite3 e rieseguire."
    touch "$DATADIR/contacts.db"
fi

# VIOLATION.md deve esistere come file
touch "$DATADIR/boot/VIOLATION.md"

# Seed agent: copia solo se manca, per non sovrascrivere memoria o prompt editati.
for seed in "$BUNDLE_ROOT"/templates/agents-seed/*; do
    [ -d "$seed" ] || continue
    name="$(basename "$seed")"
    target="$DATADIR/agents/$name"
    if [ ! -e "$target" ]; then
        cp -R "$seed" "$target"
        mkdir -p "$target/memory"
        echo "Seed agent installato: $name"
    fi
done

# trusted.json per WhatsApp (vuoto — da popolare con il LID di owner)
echo '{}' > "$DATADIR/daemon-state/whatsapp/trusted.json"

echo ""
echo "Struttura creata:"
find "$DATADIR" -not -path '*/.git/*' | sort

echo ""
echo "Prossimo passo: crea .env nella root del bundle con:"
echo "  CLODIA_DATA=$DATADIR"
echo "  ANTHROPIC_API_KEY=sk-ant-..."
echo "  TELEGRAM_BOT_TOKEN=..."
echo ""
echo "Per agenti agent_sdk=codex, il worker usa @openai/codex installato"
echo "nell'immagine e la subscription auth persistita in codex-home:"
echo "  CODEX_HOME=$DATADIR/codex-home codex login"
