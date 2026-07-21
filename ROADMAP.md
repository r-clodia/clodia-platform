# Roadmap — Clodia Platform

Roadmap della **piattaforma Clodia** (prodotto modulare unico: `clodia-logic`,
`clodia-tools`, `clodia-web`, `clodia-pwa`, versionati con tag globali coordinati —
vedi [CHANGELOG.md](CHANGELOG.md)).

Questo documento traccia il **lavoro pianificato per la prossima release** e lo
stato di ogni milestone. Il lavoro già rilasciato vive nel CHANGELOG; qui c'è
solo ciò che è *in corso* o *da fare*. Convenzione stato: ✅ fatto · 🚧 in corso ·
⏳ da fare.

> Stato: **v6.3 rilasciata** il 2026-07-20 (tag coordinato sui quattro moduli) —
> release di sicurezza & governance (M-sudo, M-authz, contenimento runtime M3,
> struttura pack M0–M2 + fix). Vedi [CHANGELOG.md](CHANGELOG.md).
> **Prossimo obiettivo: v6.4** — sicurezza-pack (security-auditor + install-pack)
> + rifiniture M3 (minter isolato / `/proc` pieno).

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
| Integrations admin-only | `/tools/*` (gestione MCP/credenziali/backup) era aperto se `CLODIA_TOOLS_UI_TOKEN` assente → un non-admin ha rimosso l'MCP 'sedia'; ora richiede admin (ckt1 + ruolo) | ✅ |
| Jobs owner-only | i job hanno un `owner`; modifica/cancella/esegui riservati a owner+admin; chi crea diventa owner; job di sistema (owner vuoto, es. backup) solo admin. Prima un non-owner poteva cancellare il job di backup. + gating UI dei controlli | ✅ |
| Topic owner-only | cambio stato/archiviazione di un topic ristretto all'**owner** (o admin) — prima un partecipante non-owner poteva; sibling `set_participant` webui-side ancora da gatare | ✅ |

> Nota di scope: consegnato il **PDP unico** (una sola RBAC decide per agenti e
> umani) con enforcement su tutti gli endpoint privilegiati noti. La "purezza A"
> piena (ogni azione UI = un unico tool gateway anche per l'esecuzione) è
> incrementale: alcuni endpoint agent-server fanno orchestrazione extra (es.
> guardia base-pack) che il tool gateway grezzo non replica — spostarli va fatto
> senza regressioni. **workflows start/cancel/delete** resi admin-only: decisione
> di policy rivedibile.

---

## v6.4 — Runtime senza stato + sicurezza dei pack (prossima)

**Modello target del runtime** (deciso 2026-07-21): l'**agent-server** non monta
più `/datadir`; monta **solo un volume effimero** per gli spawn. `/datadir`
(persistente) lo monta il **gateway**. Gli **agent seed** sono **solo contenuto
di pack** (niente creazione a runtime — già enforced in v6.3.1-fix): quindi non
esiste def di agente user-generated da persistere. L'orchestrator, per creare uno
spawn, **fetcha il seed dal gateway** e lo materializza nel volume effimero; le
**memorie** dei seed persistono in `/datadir` e si leggono/scrivono via `memory.*`.
Risultato: agent-server = **runtime senza stato**, gateway = **unico data-plane**,
chiavi **fisicamente assenti** dal container degli agenti (minting al gateway).

| # | Milestone | Contenuto | Stato |
|---|-----------|-----------|-------|
| **seed-only-via-pack** | fondazione | `create_agent` ammette solo `type=human`; agenti AI solo via import di pack. UI "+ Nuovo utente". | ✅ (fatto) |
| **M3++** | runtime senza stato | agent-server monta **solo** volume effimero spawn; `/datadir` solo-gateway; **minting spostato al gateway** (chiavi fuori dal container agenti); orchestrator **fetcha il seed dal gateway**; memorie via `memory.*`. Niente container-per-spawn (latenza). | ⏳ |
| **M4** | security-auditor | Nuovo **agent-seed `security-auditor`** sandboxed: **nessun** tool read/write, rete **solo** verso fonti whitelisted. Code-review / security-review di skill e MCP di un pack. | ⏳ |
| **M5** | install pack sicuro | Flusso: **gate bloccante** dell'auditor + **override owner** + **chat interattiva** col sysadmin. I pack possono portare **provider** (adapter-code, auditato). | ⏳ |
| **M6** | release | Rilascio + **tag v6.4** coordinato + sezione CHANGELOG. | ⏳ |

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
