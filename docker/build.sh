#!/usr/bin/env bash
# Builda tutte le image Clodia in ordine (base → bundle → servizi).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== 1/3  clodia-base ==="
docker build -f docker/base.Dockerfile -t clodia-base .

echo "=== 2/3  clodia-bundle ==="
docker build -f docker/bundle.Dockerfile -t clodia-bundle .

echo "=== 3/3  clodia-agent-server ==="
docker build -f docker/agent-server.Dockerfile -t clodia-agent-server .

# I daemon (telegram, whatsapp, check-mail) girano come processi dentro
# l'agent-server, accesi/spenti dalla webui. Niente image dedicate.

echo ""
echo "Build completato. Immagini:"
docker images | grep clodia
