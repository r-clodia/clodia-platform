# Comandi di verifica della piattaforma. `make test` esegue le suite dei
# componenti clonati sotto `repos/`, poi controlla che ogni voce dei notebook
# sia citata da un test (decision record 34).
.PHONY: test test-components test-coverage test-egress test-pins help

REPOS ?= repos

help:
	@echo "make test              suite dei componenti + copertura dei notebook"
	@echo "make test-components   solo le suite sotto $(REPOS)/"
	@echo "make test-coverage     solo: ogni voce dei notebook ha un test che la cita"
	@echo "make test-egress       egress proxy suite (docker/egress, #463)"
	@echo "make test-pins         le due copie di base.Dockerfile pinnano uguale"

test: test-components test-egress test-pins test-coverage

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

# The egress proxy (#463). Stdlib only; the join test with the gateway runs when
# $(REPOS)/clodia-tools is there with its dependencies, and skips otherwise.
test-egress:
	@echo "── egress proxy"
	@CLODIA_TOOLS_SRC=$(REPOS)/clodia-tools python3 -m unittest discover -s docker/egress -p "test_*.py"

# Il pin dei runtime agentici esiste in due copie (#493): questa istanza e il
# template del builder. Niente build qui — si confrontano i valori degli ARG.
test-pins:
	@echo "── pin dei runtime (base.Dockerfile ×2)"
	@python3 scripts/check-codex-pin.py
