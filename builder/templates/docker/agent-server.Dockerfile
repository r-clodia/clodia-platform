FROM clodia-personal-bundle

# Le dipendenze Python vengono installate dall'entrypoint dopo il git pull.
# Qui installiamo solo quelle note al momento del build per velocizzare i restart.
COPY docker/install-deps.sh /install-deps.sh
RUN chmod +x /install-deps.sh && /install-deps.sh

EXPOSE 7842

# L'entrypoint (ereditato da clodia-bundle) clona/aggiorna il repo,
# poi lancia uvicorn direttamente (non cli.py che usa Popen+daemon mode).
CMD ["sh", "-c", "cd /clodia/tools/system/agent-server && python3 -m server.main"]
