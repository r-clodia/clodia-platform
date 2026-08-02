# Changelog — Clodia Platform

Changelog centrale della **piattaforma Clodia**, prodotto modulare unico composto da quattro moduli versionati con **tag globali coordinati**:

- **`clodia-logic`** — backend / agent-server (agenti, job, topic & canali, routing, auth/PKI, API)
- **`clodia-tools`** — gateway (MCP tools, vault/credenziali, connettori, provider di inferenza)
- **`clodia-web`** — web UI (SvelteKit)
- **`clodia-pwa`** — app installabile (PWA)

Formato ispirato a [Keep a Changelog](https://keepachangelog.com/); versionamento SemVer a livello di piattaforma. ⚠️ = breaking / migrazione richiesta.

---

## [7.1] — 2026-08-02

> From this release on, changelog entries are written in **English**: the
> platform repos are open source and the audience is not Italian. Earlier
> entries are left as they were written.

Minor release driven by **security posture**: the lethal trifecta gets measured
instead of guessed, the gateway's decision state leaves the volume it shared
with the agents, and seeds lose the one verb that let any of them pull any agent
into a channel. Ships also **multi-spawn participation** (a seed can now work as
N concurrent instances), **inference stacks** (a seed can hold more than one
(model, provider) pair) and **actionable notifications** in recent topics.

### 🔺 Lethal trifecta: measure, then reduce

The three capabilities that make an agent structurally exposed to indirect
prompt injection — private data, untrusted content, external write — are now
**computed from the effective grants**, not declared.

- **Danger score per agent and per context**, as the OR over the channel's
  transitive closure (participants + agents reachable by whoever can widen the
  composition). Shell is a **separate flag, not a fourth side**: it does not make
  a channel riskier, it makes the control *bypassable* (`curl` never reaches the
  gateway). Exposed on the topic and shown in the UI with a per-side, per-agent
  breakdown — the number alone is not actionable.
- **Verb classification is versioned configuration** (`catalogs/trifecta.yaml`),
  refined by review instead of hard-coded. The v2 pass realigned it to the
  gateway's **actual** verb list: `fs.list_dir` was a false positive (it lists a
  directory inside the agent's own workspace, never file contents), the
  third-party connectors were **not classified at all** (Calendar, Docs, Trello,
  image generation, pack installs — all writes that leave the instance), five
  exceptions pointed at verbs that do not exist, and `email.reply` — which sends
  in-thread **with attachments** — did not light up egress at all.
- **Instance overrides merge, they no longer replace**: a partial override
  declaring only `egress` used to zero the other two sides, reporting a genuinely
  3/3 agent as 0/3. False reassurance is the one direction this measure cannot
  afford.
- **`topic.add_participant` removed from every seed except the two supers**, by
  expanding the `topic.*` wildcard into its 26 remaining verbs. Composing a team
  stays gated even for the supers, and human principals are unaffected — they add
  participants through an endpoint that never touches the agents' PDP. Side
  effect worth having: a *future* `topic.*` verb is no longer granted implicitly.

Measurement is deliberately separate from enforcement: **nothing is blocked by
this release**. Context gates, taint tracking and per-seed egress allow-lists are
specified but not shipped.

### 🛡️ Control plane isolated from the agents ⚠️

Per-agent whitelists, gate consents and delegations **are** the reference
monitor's authorization decisions, and they used to live on the datadir the
compose mounts **into the container where agents run**: rewriting your own entry
granted you a tool, and later calls passed "legitimately" because the *state* had
been tampered with, not the control bypassed.

They now live in a directory owned by the gateway alone
(`CLODIA_TOOLS_STATE_DIR`, mounted only by the `clodia-tools` service). Legacy
copies migrate once, and the state directory is inside the restic backup
perimeter — isolating it would otherwise have quietly dropped it from backups.

⚠️ **Deployment action required**: the volume and the environment variable must
be added to existing compose files; without them the code keeps the previous
behaviour (no breakage, no protection either). Known gap: migration is currently
lazy, so it should be forced at gateway startup — see platform issue #112.

### 👯 Multi-spawn participation

A seed can declare `multi_spawn` and materialize **N concurrent instances** in
one context, addressed by ordinal (`@agent#2`):

- a generic mention goes to the **lowest free ordinal**; if all are busy a new
  instance is **forked**, up to `max_spawns`, then work queues on the lowest;
- **only ordinal #1 writes the seed memory** — the others receive a read-only
  snapshot, so concurrent instances cannot race on `MEMORY.md`;
- mentions with ordinals are parsed into the message's structured `mentions`
  field, and delegation compares by *seed*, so `agent#2` mentioning `@agent`
  does not delegate to itself;
- the Participants panel shows a **tree of live instances** with a status light,
  served by an endpoint scoped to channel members and closed to four fields
  (`agent`, `instance`, `label`, `state`) — presence, never work: an instance may
  be running in a topic classified above the viewer's clearance.

Verified in production with four concurrent instances of one seed.

### 🧠 Inference stacks: one seed, N (model, provider) pairs

The old model was "one seed, one LLM; one LLM, N providers". A provider could
already serve a different model, so the assumption was already broken in
practice. It is now explicit:

```yaml
stacks:
  - { model: gpt-5.6-sol, provider: codex }
  - { model: claude-opus-5, provider: claude-team }
```

Legacy fields keep working and are normalized in both directions — the old model
is a special case of the new one, so no migration is needed. The UI picks a
**stack**, and cards, tables and profile show the **effective** model instead of
the top-level one, which used to lie whenever a fallback was active. Topic turns
also pick the cheapest provider eligible for the topic's tier.

### 🔔 Actionable notifications in recent topics

The badge counted every new message, which turns a notification into noise. It
now lights up **only for items that wait for you** — unread mentions addressed to
you, plus workflow gates assigned to you — and counts *items, not messages*.
Ordinary traffic gets a small neutral dot with no number.

- computed **per principal**, never shared: a topic you do not participate in is
  absent from the response, not reported as zero;
- authorization is re-evaluated on every call, so revoking a grant removes the
  badge immediately;
- visiting a topic clears the dot but **not** the gates: a gate is not an unread
  message, and it goes away only when resolved or reassigned;
- mentions are matched against a **structured** field written at post time, not a
  regex over raw text — escapes, code blocks and quoted lines no longer produce
  false mentions.

### 💬 Topic UX

- **One box per agent** for reasoning and tool calls, in sequence. Two data bugs
  made the feature impossible before: the expand state was a single page-wide
  variable (opening one agent's reasoning opened all of them) and tool steps
  overwrote each other, so the sequence never existed. Net effect on the page is
  **−52/+21 lines**.
- Markdown files preview in the topic, readable by default.
- Channel aliases: managed in settings, tokenized in the composer (desktop and
  mobile), and **isolated from ingest** — an alias is a composer macro and must
  never be expanded on inbound content.

### ⚙️ Platform operations

- **Pack provisioning**: dedicated gateway verbs, and MCP servers now enter
  reconciliation. Previously a plugin declaring only MCP servers marked the pack
  `setup_pending` — "Finish setup" lit in the UI — without triggering any
  reconciliation, so nobody could close that setup. With `features.rag` off the
  prompt no longer asks for verbs that do not exist.
- `GET /clodia/packs/{name}` resolves a **plugin** name to its containing pack:
  setup declarations are per-plugin, so whoever reconciles always starts from a
  plugin name.
- Encrypted spawn-to-spawn file transfers over a dedicated volume.
- Archived topics enforce access; job run status persists across restarts; job
  run history refreshes; Codex usage accounting hardened; GET requests cached
  within a web session.
- Routing: **one responder per message** by default (fan-out is opt-in), routing
  feedback actually applied, and the state-writer seed no longer picked as a
  generic conversational responder.

### 📦 Modules

| module | version |
|---|---|
| `clodia-logic` | 6.105.0 |
| `clodia-tools` | 1.0.0 |
| `clodia-web` | 0.117.0 |
| `clodia-pwa` | — (fixes only) |

`clodia-tools` crosses 1.0.0 with this release: isolating the reference
monitor's state is a change of posture, not an increment of features.

---

## [7.0] — 2026-07-29

Primo **major** dopo la linea 6.x. Il salto è trainato dalla **ristrutturazione
dei topic (meta v2)** e dal **modello Drive come storage live** — entrambi
**breaking** sul formato/contratto dei topic, con migrazione dati inclusa.
Consolida inoltre il ciclo di **governance** (M-gate + deleghe + Chat Hooks),
il **routing multi-agente**, la **gestione dei pack** (update da GitHub, diete e
capability per ruolo) e la nuova identità **Clodia Colony**. Include il
contenimento keyless/M3++ già in rc0, ora in produzione (personal).

### 🗂️ Topic meta v2 ⚠️ (trigger major)
- Schema `meta.json` **v2**: `schema_version`, `status` e `deadline` espliciti e
  normalizzati; vocabolario status coerente su backend/UI. Migrazione con
  **backup** pre-flight; `minutes/` non più negli snapshot (spostate in
  `.migrated-from-v1/`, recuperabili). Migrati 153 topic in produzione, 0 errori.
- **Read-path tollerante**: un `meta` legacy non conforme viene **coerciato**
  (status→`active`, deadline→`null`), mai un errore — un topic non diventa più
  invisibile/non-apribile. La validazione stretta resta ai soli endpoint di
  scrittura `set_status`/`set_deadline`.
- `files/AGENTS.md` come **boot-instructions** del topic, iniettato però come
  materiale **non autorevole** (framing anti prompt-injection) e con **cap** di
  dimensione. Controlli status/deadline (owner-only) nella sidebar del topic.

### 📁 Drive = source of truth del topic ⚠️
- Collegare un topic a una cartella Drive rende **Drive la fonte**: nessun
  upload dei file locali, navigazione diretta del remoto; l'editing di un agente
  passa da uno **scratch** (download→modifica→re-upload), mai dal topic-fs.
  Rimosso l'apparato di migrazione/clear (era la causa di un loop di upload che
  saturava il gateway). Guardia anti-nascondimento + cap SEAL. `remote_disable`
  materializza Drive→locale.
- `topic.read_file`/`write_file` rifiutano binari >128KB → `topic.fetch`/`put`.
- ZIP **download-all** dei file di un topic (streaming, cap 500MB).

### 🔐 Governance: M-gate + deleghe + Chat Hooks
- **M-gate**: consenso umano per-uso sui soli verbi **mutanti** (letture libere),
  RBAC-scoped (`gate:<verb>`), block-and-wait sulla tool-call; card di
  approvazione **inline** nella chat. Eliminato il sottosistema **sudo** legacy
  (cross-topic unificato nel gate).
- **Deleghe firmate** (verifica CA + `covers`), store permanente, endpoint
  register/list/revoke, finestra d'attesa async (~2h) con notifica sui canali di
  contatto del principal.
- **Chat Hooks** F1–F3: un hook per topic (create-or-regenerate), ingress
  webhook con **firma CA**, **audit-log** e **rate-limit** per-minuto; pannello
  owner-only in webui.

### 🧭 Routing dei canali
- **Alias** di canale instance-wide (`$alias` → prompt completo).
- **Routing multi-intent**: decomposizione in sotto-task e fan-out ai
  specialisti pertinenti, con **cap** anti-amplificazione (embed bloccante) e
  filtro d'idoneità (clearance/SEAL, partecipanti) prima dello scoring.
- **Feedback di routing** in UI (conferma/correzione dell'agente scelto) e
  tuning delle soglie del router semantico (threshold/margin/soft-ratio).

### 📦 Pack & agenti
- **Check update / Update da GitHub** (upstream) dei pack first-party: replace +
  restart agenti; flag `setup_pending` + "Finish setup".
- **base-pack a dieta**: primitivi di piattaforma separati da editoriale
  (`editorial-pack`) e comms/supporto (`comms-pack`); capability dei seed
  **per ruolo** (basta wildcard grab-bag) con **migrazione datadir** idempotente
  per i deployment esistenti. Consolidati janitor+sysadmin in un unico steward
  `sysadmin`; nuovo seed `segretario`; `messaggero` con `check-email`/reconcile.
- Skill **`adversarial-code-review`** (security-engineer). **Auto-mount MCP** dei
  plugin solo da fonti **trusted** (update first-party); gli import esterni
  restano opt-in (pending) — barriera Prima Legge. `rag_collections` dichiarate
  dal pack.
- Forward degli **embedded text resource** MCP dal gateway; pin `mcp<2`.

### 🔑 Clearance & contenimento
- **SEAL effettiva** di un agente = SEAL del **provider** che usa (non quella
  dichiarata nel seed), regola **uniforme per tutti** (super inclusi).
- Consolidato il runtime **keyless** + gateway trust-anchor e il volume-split
  M3++ (già in 6.4-rc0), ora in produzione sul personal.

### 🎨 Branding
- Identità **Clodia Colony** su web e PWA (asset dalla sorgente canonica
  approvata); rimosso il widget helpdesk flottante.

---

## [6.4-rc0] — 2026-07-21

**Release candidate.** Runtime **keyless** + gateway **trust-anchor** + document
store per-seed. Il contenimento M3++ (volume-split) è **validato end-to-end su
testbed** (`clodia-test`); la migrazione in produzione (personal) è il passo
successivo. Tag RC come punto di ripristino prima della migrazione.

### 🔑 Runtime keyless + gateway trust-anchor
- **Minting** dei token di sessione (`ckt1`) e delle capability (`ccap1`) spostato nel **gateway** (`/internal/mint`), autenticato dal **secret di bootstrap** `CLODIA_ORCHESTRATOR_SECRET` (non ckt1: sarebbe circolare). L'orchestrator **delega** con cache per-identità e fallback locale (rollout reversibile via flag).
- **Issuance** certificati (enrollment umani/agenti) e **PKI bootstrap** (`init-ca` + `issue-all`) spostati nel gateway, unico detentore di CA key e identity key. `entrypoint`: in modalità keyless agent-server **salta** la PKI bootstrap (evita CA divergente nel volume runtime).
- `child_env` degli spawn: **strip** di `CLODIA_ORCHESTRATOR_SECRET` e `GIT_TOKEN` (un agent via bash non li legge).

### 📦 Contenimento M3++ — volume-split ⚠️
- Topologia **two-dir**: `runtime` (condiviso agent-server↔gateway) vs `sensitive` (solo-gateway: `topics`/`secrets`/`clodia-vault`). agent-server **non monta più** i dati sensibili → bash dell'agente contenuta a livello filesystem. `pki/` (certi pubblici) resta in runtime. Validato su testbed; **personal pending**.

### 🗂️ Document store per-seed + trasferimento file
- `memory.put_document`/`read_document`/`get_document`/`list_documents`/`delete_document`: libreria **persistente per-seed** (`agents/<seed>/files/`, cap 25MB), caricata **on-demand**.
- `topic.read_file`/`write_file` **rifiutano** payload binari >128KB e indirizzano a `topic.fetch`/`topic.put` (byte via scratch, fuori dal modello). Nuovo **principio 6** in costituzione.

---

## [6.3] — 2026-07-20

Release di **sicurezza & governance**: l'RBAC passa da *convenzione* a *confine
reale*, dal gateway come unico punto di autorizzazione (umani e agenti, UI e
agentico) fino al contenimento del runtime degli agenti. ~74 commit sui quattro
moduli. La sicurezza-pack (security-auditor + install-pack) è rinviata a v6.4.

### 🔐 M-sudo — least-privilege + escalation
- Rimosso il bypass "super" sull'accesso ai topic; **compartimentazione** `topic.*` (fix confused-deputy).
- `add/remove_participant` = azione **sudo** (chiude auto-invito cross-topic).
- Propagazione del **principal umano** del turno al gateway (Claude SDK).
- Gruppo **sudoer** + grant admin; flusso **request → popup owner → approva**.
- Grant sudo = **capability-token firmata dalla CA** (`ccap1`), revocabile; verifica firma+scadenza+jti a ogni op; rimosso il fallback non-firmato.

### 🛂 M-authz — RBAC unica per agenti e umani ⚠️
- Il **gateway diventa il PDP unico**: claim firmati `on_behalf`/`human_role`, facade `/internal/tool`+`/internal/authorize`; RBAC identica per agente/umano e UI/agentico.
- Enforcement su **tutti** gli endpoint privilegiati REST (packs/providers/agents/workflows/plugins) — chiusa la Broken Access Control (un non-admin/anonimo poteva terraformare).
- `/tools/*` (integrations/credenziali/backup) → **admin-only** (chiuso il buco della rimozione MCP).
- **topic status/archive → owner-only**; **jobs con owner** e azioni owner-only.

### 🧱 M3 — contenimento del runtime (perms-based)
- Il subprocess dell'agente gira **non-root** (wrapper `setpriv`): il suo bash NON legge i segreti root-only (ca.key/identity.key/vault).
- **uid unico per-spawn** (isola l'istanza) + **gid per-seed** (famiglia); scratch `700`.
- `secrets/` e `clodia-vault/` → **700** (root-only). Sandbox **ON di default** sui cloni.

### 📦 Struttura pack + seed (M0–M2)
- **base-pack** come pack vero, **non rimuovibile**; seed nativi + costituzioni come preamboli.
- Placeholder pack di terzi + **licenze/DPA** (API + badge FE).
- **janitor** → navigator WebUI (`goto`); **sysadmin** → remit ristretto; tool **`logs.tail`**.

### 🖥️ UI
- Gating dei widget privilegiati **per ruolo** (defense-in-depth): sezioni sidebar, rimuovi-MCP, import/delete pack, provider, nuovo agente, azioni job/topic per-owner.
- Fix sidebar (collasso/troncamento), colonna destra topic full-height+ridimensionabile, "sta scrivendo" nel widget, etichetta versione, toggle archiviati.

### 🩹 Fix
- Provider `aws-region-eu`: default **Sonnet** corretto (`eu.anthropic.claude-sonnet-4-6`).
- **Clearance** clodia/ophelia (erano assenti → bloccate): tetto SEAL-3 + **effettiva = min(tetto agente, SEAL provider)** — dinamica sul provider.
- **clodia non si intrufola più nei DM** (i DM non prendono i partecipanti di default).
- **Igiene output** (costituzione, principio 5): nessun ragionamento/istruzioni nel corpo del messaggio.

### 📄 Docs
CHANGELOG centrale, ROADMAP, `architecture.md` (invariante gateway PDP/PEP + perimetri + audit tool), `m3-sandbox.md`.

---

## [6.2] — 2026-07-18

Release ricostruita dai ~212 commit `v6.1..v6.2` sui quattro moduli e sintetizzata come singolo prodotto.

### 📨 Messaggistica & Telegram — nuovo modello *telegram-proxy* ⚠️
- **`messaggero` unico corriere** verso Telegram: unica superficie che spedisce; non risponde né esegue l'inbound. Abbandonato il vecchio modello "mirror" (rimossi channel adapter e agente "Eco").
- **Relay meccanico (no-LLM) a contesto-finestra**: bufferizza la chat verbatim, riversa nel topic **solo** quando il bot è interpellato (menzione o reply a un suo messaggio) → niente intrusioni/spam/leak di policy nei gruppi.
- **Whitelist mittenti in `MEMORY.md`** con fallback **fail-closed** (assente/rotta → tutti negati); handle autenticati via **uid numerico** dall'API (anti-spoofing).
- **ACK/deny immediati** al mittente; **long-poll** su `getUpdates` → latenza da ~45s a ~0.
- **Allegati bidirezionali** (download inbound in `files/` con nome sanitizzato; invio con `chat_id`+`path`).
- Binding `chat_id ↔ istanza messaggero` in `telegram-bindings.json` (`telegram.listen/unlisten`), sganciato dal `meta` del topic; `send` senza più lease per-chat, accetta chat_id o nome gruppo.

### 🧵 Topic, Canali & Canvas
- **Canvas live inline**: appare da solo quando un agente produce `artifact.html` (nuovo verbo `artifact.render`), iframe sandbox + fit-to-window, **toggle show/hide** e modalità wide.
- **Sync file per-file stile git** (synced/modified/staged/unsynced, `unstage`), filtro `remoteinclude`/`remoteignore` con **hard-deny non bypassabile** su segreti/chiavi, **pull Drive incrementale** (confronto md5).
- **Composizione squadra** alla creazione del topic: `suggest_team` (rilevanza + costo), welcome "di cosa tratta?" (skill `team-composition`), **widget "Invita la squadra"** (owner-only).
- Gestione partecipanti da agente; toolbar uniformata; "Archiviati" come toggle; fix chip delle card di preview.

### ⚙️ Workflow (ex *Kanban*) — motore dichiarativo ⚠️
- **Workflow dichiarativi dai pack** (`stages: [{lane, skill, human_gate}]`), store file-per-run, assegnazione lane per capability (specialisti prima, super in fallback), protocollo `ESITO: OK|BLOCCATO|FALLITO`. La feature `kanban` è rinominata `workflows` (alias legacy retrocompatibile).
- **Run conversazionali → interazione inline sulla board** (pills/campo testo sotto la card; il topic resta infrastruttura di audit).
- **Gate** con notifica Telegram + email e **link monouso firmato** (HMAC, TTL, nonce) alla pagina `/gate/{token}` senza login; possibilità di **"Torna a &lt;stadio&gt;"** (rework indietro).
- **Job: `propose` → approve owner** (Prima Legge) con popup di conferma in chat o link firmato — un agente non crea più job direttamente.
- **Workspace repo per-run**: clona repo privati via PAT dal vault, passa il path agli stadi, cancella a fine run.
- Catalogo `/workflows`, pagina di dettaglio, board per lane, step navigabile (input/output per stadio), Stop/Delete, nomi auto-incrementali, recupero run orfani post-restart.

### 🧭 Routing del risponditore (per rilevanza) — *nuovo*
- Instradamento allo **specialista idoneo** via embedding MiniLM locale (nessun turno LLM di dispatch); profilo di dominio **auto-derivato** (expertise + skill + titoli RAG), scoring **max-sim multi-vettore**.
- Calibrazione **route-the-confident** (soglia 0.50); il caso ambiguo va a Clodia in fallback. Idoneità SEAL/clearance invariata.
- **Trasparenza**: evento `routing_decision` sul bus SSE + blocco **🧭 Routing** in chat (agente scelto, motivo, candidati con punteggio, soglia/margine).

### 🤖 Agenti & Seed di sistema
- **Rename seed** ⚠️: `mercuria → messaggero`, `saimon → sysadmin`, `wainston → janitor` (stesso ruolo/capability; richiede migrazione istanze).
- **`sysadmin` → platform-ops**: osservazione/controllo runtime, jobs, packs, workflows, providers, mcp, settings — con confini hard (mai topic/SEAL-2/segreti) e lettura **read-only** dei sorgenti della platform.
- **`memory.*` universale**: ogni agente scrive la propria memoria senza grant per-agente; **tab Memories** in webui + endpoint `GET /{name}/memories`.
- **/agents come tabella** con colonna **costo /1M token** (in/out) o "abbonamento"; rimosse colonne Stato/Skill.

### 🧠 Provider di inferenza
- **Nuovo provider Claude Team** (SEAL-1, DPA commerciale Anthropic) preferito nei seed `clodia`/`sysadmin`/`janitor`.
- **Default Sonnet EU (Bedrock) → Claude Sonnet 5** (upgrade per sysadmin/avvocato/commercialista; `claude-sonnet-4-6` ora legacy).

### 🔐 Credenziali, Vault & Connettori
- **Google unificato** (Gmail + Drive + Docs + Calendar) ⚠️: un solo consenso OAuth → **una sola credenziale `google_<account>`** con un unico refresh token. Elimina il cross-invalidation dei consensi separati `gmail_`/`gworkspace_`. Fallback ai grant legacy.
- `email.save_attachment` e `topic.read_document` (PDF/DOCX/XLSX → testo) **server-side**: niente più base64 troncato nel contesto del modello.
- Nuovi verbi `gdrive.rename` / `gdrive.move` (Shared Drive supportati).
- **Test connection reale** delle integrazioni (github/trello/telegram/openai/topic-storage): distingue "connesso" da "credenziale valida" (es. PAT scaduto).
- Vault: endpoint interno PAT scopato per il runner dei workflow; fix lettura chiave `api_key`.

### 🛡️ Sicurezza & Governance (Prima Legge)
- Job solo via **propose → approve** owner; **platform-ops gated + log** (non più shell); hard-deny segreti nel sync remoto; whitelist Telegram fail-closed con uid anti-spoofing; il corpo delle skill non finisce più nell'output/streaming (`_BlockFilter`).

### 🖥️ Web UI
- **Topics**: canvas live, blocco Routing, invita squadra, popup conferma job, paste immagini nel composer, sync git-style, toolbar uniformata, fix card.
- **Workflows**: catalogo/dettaglio/board, interazione inline, step navigabile, pagina `/gate`.
- **Providers/Tools**: card **Google unificata**, bottone **Test connection**.
- **Packs**: nodo auto-descrittivo (workflow con lane/gate + datastore).
- **Sidebar collassabile** (solo iconcina in modalità collapsed).

### 🔑 Auth & Backup
- **Sessione PWA valida 30 giorni** (niente ri-pairing; la masterkey non viene mai trasmessa al telefono).
- Backup: `status` distingue **ultimo backup eseguito** (anche fallito, con errore) da **ultimo snapshot valido** (restic); Settings più informativo.

### 🚑 Stabilità & performance
- Risolto **deadlock sync-in-async** gateway↔agent-server (dispatch offloadato su threadpool).
- **Incidente 17 lug**: il polling della webui saturava il gateway (~60 chiamate HTTP sincrone per poll) fino al blocco → cache TTL sui provider + handler caldi fuori dall'event loop; `/internal/topics` con cache 6s (basta read-timeout MCP a 15s).
- Recupero sessioni OpenCode morte (404 → nuova sessione); download filename non-ASCII (RFC 5987); no-cache sull'HTML in preview (UI stale); fix proxy `/gate`.

### ⚖️ Legale
- Aggiunto il copyright **"© 2026 Davide Carboni"** nei README di tutti i moduli.

---

## [6.1] — 2026-07-07

Primo tag globale coordinato sui quattro moduli (baseline del versionamento di piattaforma). Nessun changelog centrale antecedente.
