ARG BASE_IMAGE=clodia-personal-base
FROM ${BASE_IMAGE}

# L'entrypoint clona/aggiorna il bundle da GitHub all'avvio.
# Il codice NON è baked nell'image — viene sempre preso dal repo.
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
