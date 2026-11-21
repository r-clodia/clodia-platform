FROM python:3.12-slim

# The pin is a compatibility contract with the model slugs declared in
# `agent.yaml`: the models endpoint returns a `minimal_client_version` per slug,
# and a CLI below it gets HTTP 400 "requires a newer version of Codex". Bump it
# deliberately, checking that the agents' slugs are served at the new version.
# 0.160.0 since clodia-platform#493: `gpt-6-astra` (ophelia) needs >= 0.153.0.
# Must stay equal to `docker/base.Dockerfile` — `scripts/check-codex-pin.py`.
ARG OPENAI_CODEX_NPM_VERSION=0.160.0
ARG OPENCODE_NPM_VERSION=1.15.13
# Claude Code is pinned too (clodia-platform#535): 2.1.197 is the version the
# production agent-server was running when the pin was introduced (21 Nov 2026).
# Bump it like codex: a PR changing both copies, after a test turn of an
# `agent_sdk: claude` agent on the new version. See `docker/base.Dockerfile`.
ARG ANTHROPIC_CLAUDE_CODE_NPM_VERSION=2.1.197

# Node.js 20 LTS
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl bash git sqlite3 rsync \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# CLI agentici spawnabili dai bot Node e dai tool Python.
# All three are pinned: the agents run inside the agent-server worker and must
# find a binary that does not change under them between rebuilds.
RUN npm install -g @anthropic-ai/claude-code@${ANTHROPIC_CLAUDE_CODE_NPM_VERSION} \
    @openai/codex@${OPENAI_CODEX_NPM_VERSION} \
    opencode-ai@${OPENCODE_NPM_VERSION}

# Verifica installazione
RUN claude --version
RUN codex --version
RUN opencode --version

ENV CLODIA_DATA=/datadir
WORKDIR /clodia
