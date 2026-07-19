# Roadmap — Clodia Platform

Roadmap della **piattaforma Clodia** (prodotto modulare unico: `clodia-logic`,
`clodia-tools`, `clodia-web`, `clodia-pwa`, versionati con tag globali coordinati —
vedi [CHANGELOG.md](CHANGELOG.md)).

Questo documento traccia il **lavoro pianificato per la prossima release** e lo
stato di ogni milestone. Il lavoro già rilasciato vive nel CHANGELOG; qui c'è
solo ciò che è *in corso* o *da fare*. Convenzione stato: ✅ fatto · 🚧 in corso ·
⏳ da fare.

> Stato repo alla stesura: tutti e quattro i moduli sono a **v6.2**. La **v6.3**
> non è ancora rilasciata (nessun tag). Ultima verifica: 2026-07-20.

---

## v6.3 — Sicurezza dei pack + least-privilege degli agenti

Tema della release: rendere sicura la **terraformazione** di un sistema agentico
via pack (skill + MCP + provider di terze parti) e togliere agli agenti di
sistema (clodia/ophelia) il potere permanente di "super", sostituendolo con
un'escalation controllata da un umano.

### Struttura pack + agenti nativi

| # | Milestone | Contenuto | Stato |
|---|-----------|-----------|-------|
| **M0** | base-pack | I nativi (skill, rule, agent-seed) diventano un **pack vero** (`base-pack`), **non rimuovibile**. Gli agent-seed sono nativi *dentro* il base-pack; le costituzioni sono **preamboli** allo system-prompt del seed. | ✅ |
| **M0b** | pack di terze parti | Pack esterni come placeholder (non bundlati nel repo AGPL); **licenza per-pack** (SPDX) dichiarata a grana fine (per plugin/skill); badge **licenza / terzi / DPA** nella pagina Packs della webui. | ✅ |
| **M1–M2** | remit janitor & sysadmin | **janitor** → *WebUI navigator* read-only (naviga alla pagina giusta via marker `goto`, spinner di elaborazione nel widget). **sysadmin** → remit ristretto: install/rimozione pack + dipendenze sul gateway + accesso ai **log** del server (`logs.tail`, solo log di piattaforma, segreti redatti). | ✅ |

### M-sudo — least-privilege + escalation *(inserito out-of-band)*

Nato dall'exploit **confused-deputy** (un utente in un topic induceva clodia-super
a leggersi/aggiungersi a un altro topic). Non era in piano ma ha priorità di
sicurezza (Prima Legge).

| Fase | Contenuto | Stato |
|------|-----------|-------|
| Core | Rimozione del bypass "super" sull'accesso ai topic (asse a due assi: clearance≥tier **AND** participants). `add_participant` diventa azione **sudo**. Gruppo **sudoer** (clodia, ophelia, sysadmin) least-privilege di default; tool super-only (`packs.`/`providers.`/`mcp.`/`agents.`/`settings.`/`pki.`/`ca.`) dietro grant. | ✅ |
| Escalation UX | Flusso *request → popup owner → approva/nega*: il sudoer chiama `sudo.request`, l'owner (approvatore umano) vede un popup nella webui e concede un grant **time-boxed**. | ✅ |
| Capability firmata | Il grant è una **capability-token firmata dalla CA** (`ccap1`), non un record mutabile: il gateway ri-verifica firma + scadenza + `jti` non revocato ad ogni op; **revocabile** (lista di revoca). Coniata dall'agent-server (CA privata), verificata dal gateway (CA pubblica). | ✅ |
| Instance-boxing | Promuovere la **sola istanza** dell'agente nella chat (non l'agente globale): richiede id-sessione nel token. | ⏳ |
| Flip completo | Portare *tutti* i tool super-only a base-by-default in `list_tools`. | ⏳ |
| Multi-admin | Più approvatori umani — dipende da **bootstrap-admin-auth**. | ⏳ |
| Scope-binding | Legare il grant alla classe di op approvata (niente assegno in bianco nella finestra). Rimandato per scelta (nessuna frizione aggiunta). | ⏳ |

### M-authz — RBAC unica per agenti e umani *(lato umano di M-sudo)*

Nato da una seconda Broken Access Control: gli endpoint REST della webui
(create agent, packs, providers, workflows, plugins/MCP…) non facevano alcun
check admin — un umano non-admin (o anche una richiesta anonima nel tailnet)
poteva terraformare la piattaforma. Fix: il **gateway diventa il PDP unico** per
agenti E umani.

| Fase | Contenuto | Stato |
|------|-----------|-------|
| Gateway PDP umano | claim firmati `on_behalf`+`human_role`; `call_tool`/`list_tools` autorizzano sul RUOLO umano (super-only → admin) invece che sul carrier-agent; facade `/internal/tool` (autorizza+esegue) e `/internal/authorize` (solo decisione) che riusano authz+dispatch di `call_tool` | ✅ |
| Enforcement endpoint | `gateway_pdp.require_authz` sugli endpoint privilegiati agent-server: packs (import/import-url/delete), providers (pause/resume/key/login/disconnect), agents (create/reload), workflows (start/cancel/delete), plugins (import/import-url/delete = MCP). Decisione al gateway, esecuzione locale (preserva l'orchestrazione degli endpoint) | ✅ |
| Verificato | admin→consentito, non-admin→negato, anonimo→401, letture invariate, admin NON lockato (webui allega il token, nessuna modifica FE) | ✅ |
| Convergenza "pura A" | far sparire il path REST duplicato spostando l'esecuzione sui tool gateway dove non c'è divergenza di orchestrazione | ⏳ |
| Copertura residua | audit degli altri router mutanti minori (profile, connectors[già admin], settings) | ⏳ |

> Nota di scope: consegnato il **PDP unico** (una sola RBAC decide per agenti e
> umani) con enforcement su tutti gli endpoint privilegiati noti. La "purezza A"
> piena (ogni azione UI = un unico tool gateway anche per l'esecuzione) è
> incrementale: alcuni endpoint agent-server fanno orchestrazione extra (es.
> guardia base-pack) che il tool gateway grezzo non replica — spostarli va fatto
> senza regressioni. **workflows start/cancel/delete** resi admin-only: decisione
> di policy rivedibile.

### Sicurezza dei pack — blocco ancora da fare

| # | Milestone | Contenuto | Stato |
|---|-----------|-----------|-------|
| **M3** | sandbox-runner | Runner sandboxed sull'host per l'auditor (decisione **runc vs gVisor** — a discrezione di Clodia). | ⏳ |
| **M4** | security-auditor | Nuovo **agent-seed `security-auditor`** in sandbox: **nessun** tool read/write, rete **solo** verso fonti whitelisted. Fa code-review / security-review di skill e MCP di un pack. | ⏳ |
| **M5** | install pack sicuro | Flusso di installazione: **gate bloccante** dell'auditor + **override owner** + **chat interattiva** col sysadmin. I pack possono portare **provider** di inferenza (con adapter-code, auditato). | ⏳ |
| **M6** | release | Rilascio + **tag v6.3** coordinato sui quattro moduli + sezione CHANGELOG. | ⏳ |

---

## Note

- **Dipendenze**: M4/M5 dipendono da M3 (il sandbox-runner ospita l'auditor).
  Multi-admin (M-sudo) dipende da bootstrap-admin-auth.
- **Fuori scope v6.3**: adozione SPIFFE/SPIRE — valutata e rimandata a quando il
  runtime diventerà multi-nodo (agenti come workload separati su host diversi);
  senza SPIRE dietro, allinearsi al solo formato SPIFFE creerebbe confusione.
- La roadmap **strategica** di lungo periodo (topic = canali, Clodia pura
  clonabile, tool via MCP) vive nel topic `clodia-roadmap` e nella board Trello
  "Clodia roadmap"; questo file traccia solo la **release corrente**.
