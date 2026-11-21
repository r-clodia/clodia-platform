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
# Bumped to 0.160.0 for `gpt-6-astra` (clodia-platform#493, 4 Oct 2026). The
# contract above is not a figure of speech: the catalog the CLI itself ships
# (`codex-rs/models-manager/models.json` at tag rust-v0.160.0) declares
#   gpt-6-astra  minimal_client_version 0.153.0   (ophelia, from this release)
#   gpt-6-sol    minimal_client_version 0.155.0   (the successor OpenAI points
#                                                  gpt-5.6-sol users to)
#   gpt-5.6-sol  minimal_client_version 0.144.0   (fullstack-dev, unchanged)
# — which is exactly why 0.149.0 answered 400 "requires a newer version of
# Codex" on Astra. 0.160.0 is the latest STABLE (1 Oct 2026); above it there are
# only 0.161/0.162 alphas. Astra declares the same reasoning levels as Sol
# (low|medium|high|xhigh), so the 0.137.0 deserialization failure above cannot
# come back through the model — only through a CLI left behind again.
#
# Checked, not assumed, before bumping: the `exec --json` event schema
# (`codex-rs/exec/src/exec_events.rs`) is identical between rust-v0.149.0 and
# rust-v0.160.0 except one additive optional field (`results` on `web_search`),
# and every config key the agent-server writes or passes with `-c` still exists
# in `codex-rs/config/src/config_toml.rs` at 0.160.0.
#
# Still pinned, for the reason below: it must be bumped deliberately, together
# with a check that the slugs in the agents' stacks are served at that version.
# `scripts/check-codex-pin.py` only guarantees the two copies of this file agree.
#
ARG OPENAI_CODEX_NPM_VERSION=0.160.0
# Claude Code: pinned like codex and opencode (clodia-platform#535). Until then
# it was installed unpinned, so every rebuild took whatever npm served that day
# and two runtimes could change in one layer with only one of them visible in
# the diff. 2.1.197 is not a pick: it is the version the production agent-server
# was running when the pin was introduced (read on 21 Nov 2026 inside the
# container: `claude --version` and `npm ls -g` -> @anthropic-ai/claude-code@2.1.197).
# Scope: this is the `claude` on PATH (the `/auth` login flow and anything that
# shells out to `claude`). The Claude runtime of the agent-server spawns the CLI
# bundled with the Python `claude-agent-sdk` (`_bundled/claude`), whose version
# follows that package, not this ARG.
# Who bumps it, and how: same as codex — a PR that changes BOTH copies of this
# file (`scripts/check-codex-pin.py` fails otherwise), after a test turn of a
# `agent_sdk: claude` agent on an image built with the new version. Never
# `latest`: claude-code releases often, and a rebuild must not upgrade silently.
ARG ANTHROPIC_CLAUDE_CODE_NPM_VERSION=2.1.197
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
# All three are pinned: the agents run inside the agent-server worker and must
# find a binary that does not change under them between rebuilds.
RUN npm install -g @anthropic-ai/claude-code@${ANTHROPIC_CLAUDE_CODE_NPM_VERSION} \
    @openai/codex@${OPENAI_CODEX_NPM_VERSION} \
    opencode-ai@${OPENCODE_NPM_VERSION} docx

# Verifica installazione: se un runtime manca si scopre QUI, non quando un agente
# "non parte" senza spiegazione in produzione.
RUN claude --version
RUN codex --version
RUN opencode --version

ENV CLODIA_DATA=/datadir
WORKDIR /clodia
