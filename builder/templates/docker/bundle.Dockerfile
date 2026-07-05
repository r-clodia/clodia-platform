FROM clodia-personal-base

# L'entrypoint clona/aggiorna il bundle da GitHub all'avvio.
# Il codice NON è baked nell'image — viene sempre preso dal repo.
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
