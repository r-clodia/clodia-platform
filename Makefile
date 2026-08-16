# Comandi di verifica della piattaforma. `make test` esegue le suite dei
# componenti clonati sotto `repos/`, poi controlla che ogni voce dei notebook
# sia citata da un test (decision record 34).
.PHONY: test test-components test-coverage help

REPOS ?= repos

help:
	@echo "make test              suite dei componenti + copertura dei notebook"
	@echo "make test-components   solo le suite sotto $(REPOS)/"
	@echo "make test-coverage     solo: ogni voce dei notebook ha un test che la cita"

test: test-components test-coverage

# Ogni componente porta il proprio Makefile: qui non si duplica il comando, si
# chiede a chi lo conosce. Un componente non clonato viene saltato con un avviso
# invece che far fallire il giro — ma l'avviso c'è, perché "saltato in silenzio"
# è il modo in cui una suite smette di essere eseguita.
test-components:
	@for r in clodia-logic clodia-tools; do \
	  if [ -f "$(REPOS)/$$r/Makefile" ]; then \
	    echo "── $$r"; $(MAKE) -s -C "$(REPOS)/$$r" test || exit 1; \
	  else \
	    echo "── $$r: non clonato sotto $(REPOS)/, SALTATO"; \
	  fi; \
	done

test-coverage:
	@echo "── notebook coverage"
	@python3 scripts/notebook-coverage.py --repos $(REPOS) --strict
