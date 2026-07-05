# Clodia Agency — deploy build-from-source.
# Tutti i dati dell'istanza vivono in ${CLODIA_DATA} (datadir). Le immagini si
# costruiscono dal sorgente: l'agent-server clona clodia-logic a runtime
# (GIT_REPO), gli altri servizi buildano dai repo clonati in ./repos da setup.sh.
services:

  # ── Build helpers (catena di immagini base) ────────────────────────────────
  base:
    build: { context: ., dockerfile: docker/base.Dockerfile }
    image: ${CLODIA_PROJECT}-base
    profiles: ["build-only"]
    command: ["true"]

  bundle:
    build:
      context: .
      dockerfile: docker/bundle.Dockerfile
      args: { BASE_IMAGE: "${CLODIA_PROJECT}-base" }
    image: ${CLODIA_PROJECT}-bundle
    profiles: ["build-only"]
    command: ["true"]

  # ── Servizi ────────────────────────────────────────────────────────────────
  agent-server:
    build:
      context: .
      dockerfile: docker/agent-server.Dockerfile
      args: { BUNDLE_IMAGE: "${CLODIA_PROJECT}-bundle" }
    image: ${CLODIA_PROJECT}-agent-server
    command: ["sh", "-c", "cd /clodia && python3 -m server.main"]
    ports:
      - "${AGENT_SERVER_PORT:-7842}:7842"
    environment: &common-env
      CLODIA_DATA: /datadir
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:-}
      CLODIA_BASE_EMAIL: ${CLODIA_BASE_EMAIL:-}
      GIT_REPO: ${GIT_REPO:-r-clodia/clodia-logic}
      GIT_BRANCH: ${GIT_BRANCH:-main}
      # Solo se il sorgente è un repo privato (mirror enterprise o pre-release).
      # Per i repo pubblici lascialo vuoto.
      GIT_TOKEN: ${GIT_TOKEN:-}
      SERVER_HOST: "0.0.0.0"
      CLODIA_TURN_WATCHDOG_SILENCE: ${CLODIA_TURN_WATCHDOG_SILENCE:-180}
    volumes:
      - ./entrypoint.sh:/entrypoint.sh:ro
      - ${CLODIA_DATA}:/datadir
      - ./.vault-mask:/datadir/clodia-vault
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "python3", "-c", "import httpx; httpx.get('http://localhost:7842/health', timeout=2)"]
      interval: 30s
      timeout: 5s
      retries: 5

  clodia-tools:
    build: { context: ./repos/clodia-tools, dockerfile: Dockerfile }
    image: ${CLODIA_PROJECT}-tools
    ports:
      - "${TOOLS_PORT:-7849}:7849"
    environment:
      <<: *common-env
      CLODIA_CA_CRT: /datadir/secrets/ca/ca.crt
      CLODIA_PKI_CERTS: /datadir/pki/certs
      CLODIA_PKI_REVOKED: /datadir/pki/revoked.json
      CLODIA_WORKSPACE_ROOT: /clodia
      CLODIA_SECRETS_DIR: /datadir/secrets
      CLODIA_VAULT_DIR: /datadir/clodia-vault
      CLODIA_PROFILE_ADMINS: ${CLODIA_PROFILE_ADMINS:-}
    volumes:
      - ${CLODIA_DATA}:/datadir
    restart: unless-stopped

  webui:
    build: { context: ./repos/clodia-web, dockerfile: Dockerfile }
    image: ${CLODIA_PROJECT}-webui
    ports:
      - "${WEBUI_PORT:-7843}:7843"
    restart: unless-stopped

