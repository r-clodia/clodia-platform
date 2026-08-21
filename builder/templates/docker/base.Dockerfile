FROM python:3.12-slim

# The pin is a compatibility contract with the model slugs declared in
# `agent.yaml`: the models endpoint returns a `minimal_client_version` per slug,
# and a CLI below it gets HTTP 400 "requires a newer version of Codex". Bump it
# deliberately, checking that the agents' slugs are served at the new version.
ARG OPENAI_CODEX_NPM_VERSION=0.149.0
ARG OPENCODE_NPM_VERSION=1.15.13

# Node.js 20 LTS
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl bash git sqlite3 rsync \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# CLI agentici spawnabili dai bot Node e dai tool Python.
# Codex e' pinnato: gli agent `agent_sdk=codex` girano dentro il worker
# agent-server e devono trovare un binario stabile a build-time.
RUN npm install -g @anthropic-ai/claude-code @openai/codex@${OPENAI_CODEX_NPM_VERSION} \
    opencode-ai@${OPENCODE_NPM_VERSION}

# Verifica installazione
RUN claude --version
RUN codex --version
RUN opencode --version

ENV CLODIA_DATA=/datadir
WORKDIR /clodia
