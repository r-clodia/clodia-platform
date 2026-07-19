# Changelog — Clodia Platform

Changelog centrale della **piattaforma Clodia**, prodotto modulare unico composto da quattro moduli versionati con **tag globali coordinati**:

- **`clodia-logic`** — backend / agent-server (agenti, job, topic & canali, routing, auth/PKI, API)
- **`clodia-tools`** — gateway (MCP tools, vault/credenziali, connettori, provider di inferenza)
- **`clodia-web`** — web UI (SvelteKit)
- **`clodia-pwa`** — app installabile (PWA)

Formato ispirato a [Keep a Changelog](https://keepachangelog.com/); versionamento SemVer a livello di piattaforma. ⚠️ = breaking / migrazione richiesta.

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
