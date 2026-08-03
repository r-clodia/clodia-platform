<!-- markdownlint-disable MD033 MD041 -->
<h1>Clodia Agency</h1>

**Una piattaforma agentica self-hosted, con governance e sicurezza by-design.**

Clodia Agency è un'agenzia di agenti AI che esegui sulla *tua* infrastruttura:
chat e canali tipo-Slack con gli agenti, topic di lavoro condivisi, tool via
MCP, gestione credenziali in un keystore/vault, identità degli agenti con PKI, e
un modello di permessi per-agente. Pensata per chi vuole l'automazione agentica
**senza** mandare i propri dati a una SaaS di terzi.

> **Licenza:** [AGPL v3 (dual licensing: vedi LICENSING.md)](LICENSE). Self-host completo: i tuoi dati restano sulla tua macchina.

---

## ⚠️ Prima di installare — leggi questo

Clodia Platform è distribuito **"COSÌ COM'È" (AS-IS), senza alcuna garanzia**, e
**lo installi ed esegui a tuo rischio e pericolo**. Il progetto è in sviluppo
attivo: contiene difetti noti, alcuni con impatto sulla sicurezza.

**Passo obbligatorio prima del deploy — leggi i difetti noti:**

1. **[Issue aperte con label `security`](https://github.com/r-clodia/clodia-platform/issues?q=is%3Aissue+is%3Aopen+label%3Asecurity)** — difetti di sicurezza noti e non ancora risolti.
2. **[Tutte le issue aperte](https://github.com/r-clodia/clodia-platform/issues?q=is%3Aissue+is%3Aopen)** — limiti funzionali e bug noti.
3. **[`SECURITY.md`](SECURITY.md)** — stato dei controlli tecnici, controllo per controllo, e clausola as-is completa.
4. **[`SECURITY-MODEL.md`](SECURITY-MODEL.md)** — da quale attacco ci si difende
   (la *lethal trifecta*) e come, con i limiti noti dichiarati. Da leggere prima
   di `SECURITY.md`: dice *perché* i controlli sono quelli.

I difetti noti sono tracciati **pubblicamente e in chiaro**: la loro assenza da
questo README non significa che non esistano — significa che devi guardare nel
tracker. Valuta ogni issue aperta rispetto al *tuo* modello di rischio prima di
mettere il sistema in produzione o di affidargli dati di terzi.

**Limite corrente da conoscere subito:** la piattaforma è, di fatto,
**mono-utente**. Le credenziali dei connettori esterni (Google, email, e ogni
altra integrazione nel vault) sono identità **a livello di piattaforma**: un
secondo utente umano, pur privo di grant sui topic altrui, può ottenere per il
tramite di un agente autorizzato l'accesso ai dati esterni raggiungibili con
quelle credenziali. Vedi
**[#68](https://github.com/r-clodia/clodia-platform/issues/68)**. Non aggiungere
utenti umani a un'istanza con connettori attivi finché non è risolta.

Se questo modello di rischio non è accettabile nel tuo contesto, **non usare il
software in produzione** senza una valutazione di sicurezza indipendente.

---

## Quickstart (Docker, build-from-source)

Requisiti: Docker + Docker Compose, `git`, e una `ANTHROPIC_API_KEY` (oppure un
account Claude da collegare via OAuth dalla UI).

```bash
git clone https://github.com/r-clodia/clodia-platform.git
cd clodia-platform
./setup.sh                       # clona i repo sorgente + prepara datadir e .env
nano .env                        # ANTHROPIC_API_KEY, CLODIA_DATA, CLODIA_BASE_EMAIL
docker compose --profile build-only build base bundle
docker compose up -d --build
```

Poi apri **http://localhost:7843**, esegui il **bootstrap admin** (rivendichi il
primo account amministratore) e collega provider/credenziali dalla sezione
**Tools** (OAuth o paste-key per-tool). Da datadir vuota la piattaforma
auto-inizializza schema, PKI (CA + identità dei super-agent) e struttura dati.

## Architettura

| Componente | Ruolo | Repo |
|---|---|---|
| **agent-server** | runtime degli agenti, API, orchestrazione, PKI | `clodia-logic` (clonato a runtime) |
| **clodia-tools** | gateway MCP (reference monitor): whitelist tool per-agente, vault | `clodia-tools` |
| **webui** | interfaccia web (chat, topic, agenti, admin) | `clodia-web` |
| **pwa** | app mobile (Topics + Agents/DM) | `clodia-pwa` |

Tutto lo stato dell'istanza vive in una **datadir** separata (`CLODIA_DATA`):
secrets, topic, database, PKI, definizioni agenti. Le immagini Docker non
contengono dati: sono clonabili e usa-e-getta.

## Sicurezza & dati

- **Self-hosted**: nessun dato lascia la tua infrastruttura.
- **Credenziali nel vault/keystore**, mai nel codice né nelle immagini; si
  collegano dalla UI (OAuth o paste-key) — la datadir non viene mai pubblicata.
- **Gateway come reference monitor**: ogni agente vede solo i tool nella sua
  whitelist; i super-agent hanno accesso pieno.
- **Identità con PKI**: ogni agente ha un certificato firmato dalla CA locale.

> Questi sono i controlli **implementati**, non un livello di assurance
> certificato: non c'è stato audit indipendente né penetration test. Lo stato
> reale controllo-per-controllo è in [`SECURITY.md`](SECURITY.md), i difetti
> aperti nel [tracker](https://github.com/r-clodia/clodia-platform/issues?q=is%3Aissue+is%3Aopen+label%3Asecurity).

## Vuoi questa piattaforma nella tua organizzazione?

Clodia è pensata per chi vuole l'automazione agentica con governance e sicurezza
by-design (ISO 27001 / ISO 42001, NIS2). Se vuoi adottarla, integrarla o adattarla
al tuo contesto — o ti serve supporto su governance e compliance dell'AI —
**[parliamone](https://r-clodia.github.io)**.

---

<sub>Progetto open-source. Contributi benvenuti — vedi `CONTRIBUTING.md` (in arrivo).</sub>

## License & Copyright

Copyright (C) 2026 Davide Carboni.
