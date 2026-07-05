# Licensing — Clodia Platform

## Modello: dual licensing

Questo repository fa parte della **Clodia Platform** ed è distribuito con
doppia licenza:

1. **GNU AGPL v3** (file `LICENSE`) — per la community: puoi usare,
   studiare, modificare e ridistribuire il codice. Se offri una versione
   modificata come servizio in rete, devi rendere disponibile il sorgente
   delle tue modifiche agli utenti del servizio (art. 13 AGPL).
2. **Licenza commerciale** — per chi non può o non vuole rispettare i
   termini AGPL (uso in prodotti/servizi proprietari, policy aziendali che
   escludono AGPL, edizioni personalizzate senza obbligo di pubblicazione).
   Contatto: **Davide Carboni** — dcarboni@gmail.com.

## Confine di versione

- Le versioni pubblicate **fino al tag `apache2-final`** incluso restano
  disponibili sotto **Apache License 2.0** (irrevocabile per quelle
  versioni).
- Tutte le versioni **successive** al tag sono sotto **AGPL v3** (o licenza
  commerciale).

## Pack, skill, agent seed e MCP server: NON sono opere derivate

Per chiarezza verso chi costruisce sopra la piattaforma:

- i **pack** (skill in Markdown, rules, agent seed YAML, template) sono
  **contenuti/dati caricati** dalla piattaforma, non codice derivato: possono
  avere qualunque licenza, inclusa proprietaria;
- i **server MCP** montati sul gateway girano come **processi separati** che
  comunicano via protocollo (Model Context Protocol): non costituiscono
  un'opera derivata della piattaforma;
- le **edizioni** terraformate (blueprint, profili, branding) sono
  configurazione del cliente, di proprietà del cliente.

L'obbligo AGPL riguarda le **modifiche al codice della piattaforma** offerte
in rete, non i contenuti che vi girano sopra.

## Contributi esterni

I contributi esterni sono benvenuti previa accettazione di un **CLA**
(Contributor License Agreement) che concede al titolare del progetto il
diritto di rilicenziare il contributo — necessario per mantenere il dual
licensing. Aprire una issue prima di una PR sostanziale.

---
Copyright (C) 2026 Davide Carboni
