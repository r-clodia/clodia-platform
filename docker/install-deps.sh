#!/usr/bin/env bash
# Pre-installa le dipendenze Python note per velocizzare i restart.
# Se il requirements.txt cambia dopo il build, l'entrypoint può reinstallare.
set -euo pipefail

# agent-server
if [ -f /clodia/tools/system/agent-server/requirements.txt ]; then
    pip install --no-cache-dir -q -r /clodia/tools/system/agent-server/requirements.txt
fi
