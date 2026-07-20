# Architettura di sicurezza — Clodia Platform

> Documento di riferimento (nord) per la separazione dei perimetri di fiducia.
> Stato: **target** (parte è già realizzata, parte è la milestone M3). Vedi
> [ROADMAP.md](ROADMAP.md). Ultima revisione: 2026-07-20.

## L'invariante unico

> **Un solo gateway = PDP + PEP.** Ogni accesso a *dati, segreti, tool* è una
> **chiamata al gateway**, che la analizza e la autorizza via **RBAC
> sull'identità del chiamante**. Il filesystem di chi chiama contiene **solo i
> dati della propria esecuzione** (`/proc`-like), mai i dati veri.

L'RBAC è **identica** lungo due assi che storicamente trattavamo diversamente:

- **chi** — agente **artificiale** *o* **umano**: entrambi sono un `principal`
  con identità firmata (PKI). Stessa decisione: whitelist per-agente, tiering
  super-only, ruolo umano (admin/user), clearance (SEAL/tier), ownership
  (topic/job).
- **da dove** — chiamata **agentica** (runtime SDK) *o* da **UI** (PWA/webapp):
  stesso choke point, stesso motore di decisione. La UI non è un backend
  privilegiato: è un **client del gateway** come un agente, con identità umana.

Corollario: non esistono "porte di servizio". Il filesystem non è un canale di
accesso ai dati — è solo lo scratch di esecuzione. Tutto ciò che conta passa dai
**verbi** del gateway.

## I perimetri

| Perimetro | Filesystem montato | Ruolo | Ha le chiavi? |
|---|---|---|---|
| **Agent runtime** (sandbox per-spawn) | **solo** `spawns/<id>/` — volume effimero `/proc`-like | processo di ragionamento; ogni accesso esterno = chiamata al gateway col token iniettato | **No** |
| **PWA / webapp** | nessuno | client del gateway con identità umana | No |
| **Gateway** | vault, `secrets` (letti come credenziali d'esecuzione), certs pubblici, topic-store, cataloghi, stato decisionale | **unico** a toccare i dati veri; analizza + autorizza ogni chiamata; esegue i tool | Sì (o delega al minter) |
| **Minter** (trusted, isolato — può coincidere col gateway) | **solo** le chiavi di firma (`secrets/ca`, `secrets/agents`) | emette i token ckt1/capability per-sessione | Sì |

Il **runtime dell'agente non ha mai le chiavi**: riceve un token già firmato,
iniettato per-sessione. Così la catena di escalation
(leggere `ca.key` → coniare token → sudo/impersonation) è tagliata alla radice,
perché la chiave non è nel suo filesystem.

## Stato attuale vs target

Il **modello concettuale è già quello**: gli agenti raggiungono i dati solo via
verbi MCP (la skill `topic-management` lo dice all'agente: *"Non hai accesso
diretto ai file del topic… è voluto: il gateway controlla chi può leggere
cosa"*). L'RBAC esiste ed è enforced (whitelist + tiering + M-sudo + M-authz +
owner-check su topic/job). **Manca che sia un confine reale**, non solo una
convenzione. Tre gap:

1. **Runtime `/proc`-only e keyless (M3).** Oggi il subprocess SDK condivide
   l'intera datadir e legge `secrets/ca/ca.key` (root, stesso volume). Con `bash`
   può leggere segreti, coniare token, scrivere lo stato del gateway → **bypassa
   l'intero RBAC dall'interno**. Fix: eseguire il subprocess in una **sandbox**
   (runc/gVisor) che bind-monta **solo** lo spawn, con token iniettato ed egress
   **solo** verso il gateway. Con quel rootfs, `bash`/`Read`/`Write` diventano
   innocui (vedono solo il `/proc` dello spawn).
2. **Minter separato dal runtime.** Le chiavi di firma escono dal container degli
   agenti; il minting resta in un tier trusted (gateway/orchestrator).
3. **Copertura tool completa + collasso del path UI duplicato.** Perché "tutto
   passa dal gateway" sia vero senza perdere funzioni (Asse 4), e perché la
   webapp diventi *client del gateway* invece che un backend REST parallelo
   (convergenza "A pura", vedi M-authz in ROADMAP).

## Audit di copertura tool (2026-07-20)

Mappa: cosa un agente deve fare vs il verbo gateway che lo copre. Se un verbo
manca, oggi lo si farebbe via fs/bash → **è un buco da chiudere prima della
sandbox**, altrimenti l'agente perde la capability.

### ✅ Coperto (verbi presenti)
| Dominio | Verbi |
|---|---|
| Topic (incl. **file**) | `topic.open/new/list/search/save_summary/add_minute/archive` + **`topic.files/read_file/read_document/write_file/put/delete_file/fetch`** + participants + remote + `suggest_team` |
| Memoria agente | `memory.read/write/append/list` |
| Email | `email.list/read/search/send/reply/folders/get_attachment/save_attachment` |
| Drive | `gdrive.list/search/download/upload/move/rename/mkdir/share` |
| Trello / Telegram | `trello.*` / `telegram.*` |
| Workflow / Job | `workflows.start/cancel/status/list/delete_run` · `jobs.list/propose` |
| Immagini / artefatti | `image.generate` · `artifact.render` |
| RAG / corpus UE | `rag.*` · `eu_corpus.*` |
| Admin piattaforma | `packs.* · providers.* · mcp.* · agents.* · settings.* · profile.* · runtime.*` |

### ⚠️ Gap (nessun verbo → oggi solo via fs/bash)
| Capability | Nota | Azione |
|---|---|---|
| **`fs.list_dir`** | tool-fs generico: è un escape-hatch | scoparlo al **solo spawn** o rimuoverlo (i file dei topic si leggono con `topic.*`) |
| **CRM / dati** (`contacts.db`, `data/aziende.yaml`) | nessun verbo `contacts.*`/`data.*` | wrappare come tool gateway (read-only, RBAC) |
| **Tool non ancora wrappati**: `markdown_pdf`, `slide_renderer`, `web_render`, `search`, `image_caption`, `linkedin`, `aruba_fattura`, `firma_client`, `sedia_client`, `aws_invoicing` | oggi **vietati via bash** (denylist) e **senza equivalente MCP** → buco transitorio già noto (F1.5) | wrapping MCP incrementale per frequenza d'uso |
| **`claude-home`/`codex-home`** | contengono l'auth del provider per far girare l'SDK | **iniettare effimeri** per-sessione nel sandbox, non montare dalla datadir |

## Prossimi passi

1. Chiudere i gap dell'audit (wrapping dei tool mancanti + `fs.list_dir` scoping + CRM verb).
2. **M3** — sandbox launcher: il subprocess parte con bind-mount del solo spawn + token + egress-gateway.
3. Minter isolato + volume split (`secrets`/vault fuori dalla portata del runtime).
4. Collasso del path REST UI duplicato → webapp/PWA come client puri del gateway.
