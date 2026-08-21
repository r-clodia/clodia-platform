FROM python:3.12-slim

# This pin is a compatibility contract with the model slugs declared in
# `agent.yaml`, not just a version number. The models endpoint returns a
# `minimal_client_version` per slug: a CLI below it gets HTTP 400 "requires a
# newer version of Codex", and the agent simply "does not start".
#
# Measured on the running instance with 0.137.0 (21 Aug 2026):
#   - `gpt-5.6-sol` (fullstack-dev) -> 400 on every turn;
#   - the model refresh failed on EVERY turn of EVERY codex agent, silently:
#     `unknown variant 'max', expected one of none|minimal|low|medium|high|xhigh`
#     — the server announces a reasoning level this CLI cannot deserialize, and
#     the parser discards the whole response instead of the unknown field.
# Both are gone on 0.149.0, verified in a throwaway container against a copy of
# the real CODEX_HOME: `gpt-5.6-sol` and `gpt-5.5` complete a turn, no 400, no
# refresh error, and `auth.json` is left untouched by the migration.
#
# Still pinned, for the reason below: it must be bumped deliberately, together
# with a check that the slugs in the agents' stacks are served at that version.
ARG OPENAI_CODEX_NPM_VERSION=0.149.0
# OpenCode: runtime degli agent `agent_sdk=opencode` (modelli aperti su provider
# sovrani — gpt-oss, glm, gemma). NON era installato qui: su un'istanza esistente
# c'era perché aggiunto a mano il 25 luglio, quindi ogni ricostruzione lo perdeva
# e una istanza NUOVA nasceva senza. Conseguenza misurata: due dei cinque agenti
# nativi (messaggero su gpt-oss, segretario su gemma) non potevano partire, e il
# sintomo era "non parte" senza altra spiegazione.
# Pinnato come codex, e per la stessa ragione: gli agent lo cercano a runtime e
# un binario che cambia sotto i piedi rompe turni già in corso.
ARG OPENCODE_NPM_VERSION=1.15.13

# Node.js 20 LTS
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl bash git sqlite3 rsync pandoc \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# CLI agentici spawnabili dai bot Node e dai tool Python.
# Codex e' pinnato: gli agent `agent_sdk=codex` girano dentro il worker
# agent-server e devono trovare un binario stabile a build-time.
RUN npm install -g @anthropic-ai/claude-code @openai/codex@${OPENAI_CODEX_NPM_VERSION} \
    opencode-ai@${OPENCODE_NPM_VERSION} docx

# Verifica installazione: se un runtime manca si scopre QUI, non quando un agente
# "non parte" senza spiegazione in produzione.
RUN claude --version
RUN codex --version
RUN opencode --version

ENV CLODIA_DATA=/datadir
WORKDIR /clodia
