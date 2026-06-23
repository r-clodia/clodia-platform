FROM python:3.12-slim

ARG OPENAI_CODEX_NPM_VERSION=0.137.0

# Node.js 20 LTS
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl bash git sqlite3 rsync \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# CLI agentici spawnabili dai bot Node e dai tool Python.
# Codex e' pinnato: gli agent `agent_sdk=codex` girano dentro il worker
# agent-server e devono trovare un binario stabile a build-time.
RUN npm install -g @anthropic-ai/claude-code @openai/codex@${OPENAI_CODEX_NPM_VERSION}

# Verifica installazione
RUN claude --version
RUN codex --version

ENV CLODIA_DATA=/datadir
WORKDIR /clodia
