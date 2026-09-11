# Datastore notebook

> The record of what a **datastore** (and, alongside it, a **RAG collection**) must be
> reachable by: each requirement as Davide dictated it, in the order it happened, with the
> measurement that confirmed or refuted it.
>
> Companion to [`agents-notebook.md`](agents-notebook.md) and
> [`router-notebook.md`](router-notebook.md): those record what an agent is *for* and who
> takes a turn; this one records **which stored data a seed may touch**.
>
> Same conventions as [`decision-record.md`](decision-record.md): the passages between
> «guillemets» are the owner's own words, in the language he said them.

---

## D1 · Every mediated resource, one access rule

Dictated 11 set 2026, from Clodia Primal (workspace `erre-claudia`, not a colony seed),
mid-conversation about migrating `contacts.db` off the Mac and into the colony:

> «i datastore e anche le rag collection devono essere acceduti tramite verbo mcp che
> consente di leggere, scrivere, fare ricerche. Ogni datastore/collection deve avere una
> lista di seed autorizzati all'accesso e uno seal score. Quindi spawn A accede a risorsa R
> solo se A.provider.seal >= R.seal AND A.seed IN R.members.»

This is the same two-axis rule `topic.*` already enforces (`_topic_is_member` + `_rank`,
`server/main.py` in `clodia-tools`), asked for as the general shape every mediated resource
should share.

### Measured, 11 set 2026 — dictated twice, independently, one day apart

The rule was already built. `clodia-logic` commit `2607bc1` (10 set 2026, 6.204.0),
authored by the colony's own `Clodia Colony <devnullboxx@gmail.com>` identity — a seed
inside the platform, not Clodia Primal — carries the identical design:

> «Davide vuole "contacts" staccato da tomato (un CRM di anagrafiche non è di un'azienda) e
> un controllo di accesso reale, generalizzato a ogni datastore: seed S accede sse
> S.clearance >= datastore.clearance E S nell'elenco seed del datastore — stesso schema a
> due assi già usato per i topic.»

Same rule, same wording almost verbatim, dictated to two different Clodias a day apart
without either knowing about the other's conversation. Recorded because it is evidence the
requirement is stable, not because the coincidence needed proving.

**What exists, measured across three repos (11 set 2026):**

| repo | commit | what it does |
|---|---|---|
| `clodia-tools` | `44567d2` (2.13.0) | `datastore.read`/`datastore.write` verbs; `_datastore_authorize` in `server/main.py` checks `ag in entry["seeds"]` AND `_rank(clearance) >= _rank(entry["clearance"])`; reads only `SELECT`/`PRAGMA`, writes only `INSERT`/`UPDATE`/`DELETE`, single statement, no DDL/ATTACH; every call logged to `~/.clodia/datastore-audit.log` |
| `clodia-logic` | `2607bc1` (6.204.0) | `_sanitize_datastores` accepts `name`/`clearance`/`seeds` in a pack's `datastores:` block; absent → `SEAL-4`/no seeds, fail-closed; `base-pack` declares `contacts` (`SEAL-1`, seeds `messaggero`, `clodia`); `skill_sync._datastore_map` resolves `<DATASTORE:key>` across *every* installed pack, not just the caller's own, so skills that stayed in `tomato` (`osint-lead`, `linkedin-reactions`) keep resolving `<DATASTORE:contacts>` |
| `clodia-packs` | `cb83bbf` (tomato 0.17.0) | `tomato`'s own manifest drops its `contacts` datastore declaration, so there is exactly one owner of the key |
| RAG side | — | `rag.*` verbs exist with the same shape: `_rag_authorize` checks a core grant (`runtime.rag_grants(agent)`, `rag_read`/`rag_write`) AND `_rank(clearance) >= _rank(collection_tier)` via `eu_corpus.collection_tier`. Not part of this dictation — pre-existing. |

`server/datastores.py`'s own docstring states the fail-closed guarantee: a datastore
declared before `clearance`/`seeds` existed grants nothing until someone writes those
fields explicitly — no silent permissive default.

### The gap is not in the code — it is in what has been deployed

Measured on the `personal` instance (terra), 11 set 2026:

```
repo   catalogs/packs/base-pack/pack.yaml   version 7.15.0, has `datastores:`
datadir  packs/base-pack/pack.yaml          version 7.15.0, NO `datastores:`
datadir  plugins/base-pack/plugin.yaml      version 7.0.0,  NO `datastores:`
container clodia-tools                      2.13.0 (image built 10 set 16:59, has the verbs)
```

The gateway that enforces the rule is already running the right version. The pack's own
`pack.yaml` was bumped in the datadir to 7.15.0, but the **imported** plugin manifest
(`plugins/base-pack/plugin.yaml`, the file `datastores.declared()` actually reads) is still
the pre-migration 7.0.0. This matches a known shape recorded in
[`agents-notebook.md` A12](agents-notebook.md#a12-a-seed-summons-itself-and-that-is-how-it-forks):
`sync_seeds` materialises only *missing* entries, so a field added to an already-installed
pack does not reach a running instance until that pack is explicitly re-imported — the
webui **Update** action, per pack, done by the instance owner.

**So `contacts.db` inside the colony (`/datadir/plugins/base-pack/data/contacts.db`,
848 rows, schema identical to the Mac copy) is today invisible to `datastore.read`/`write`
— not fail-closed by clearance, simply not found, because its declaring pack has not been
re-imported.** No code to write, no data to move: the fix is running **Update** on
`base-pack` for the `personal` instance.

### D2 · A second datastore is fail-closed for real, and nobody asked for that

Found while measuring D1, not dictated: `assetti-contabili/plugin.yaml` (`clodia-packs`)
**does** declare a `datastores:` block for `contabilita.db` —

```yaml
datastores:
  - path: data/contabilita.db
    purpose: Contabilità riconciliata e situazioni trimestrali (...)
    pii: true
    backup: true
```

— with no `clearance:` and no `seeds:`. Per the fail-closed rule this resolves to
`SEAL-4`/no seeds: **no seed can read or write it today, declaration notwithstanding.**
Unlike D1, this was never dictated as broken and nobody has decided which seeds should
reach a firm's accounting reconciliation data — recorded as an open point, not fixed here.

### Open

- Which seeds (and at which clearance) should reach `assetti-contabili/contabilita.db` —
  a business decision about accounting data, not inferable from this conversation.
- Whether other installed packs (`bandi-pack`'s `rag_collections: eu-normativa`, tier
  SEAL-1) have their *grant* half wired — the tier lives in the manifest, but read/write
  authority is a separate core grant (`runtime.rag_grants`) not visible in any manifest;
  not measured here.
- Once `base-pack` is updated on `personal`, whether the consumers that read `contacts.db`
  by direct file access today (Mac-side: `tools/crm_integrity.py`, the `osint-lead` and
  `linkedin-reactions` skills' non-`<DATASTORE:>` paths if any) still need migrating to the
  verb, or already resolve through `skill_sync`. Davide's decision (11 set 2026): the colony
  becomes the single source of truth for `contacts.db`; the Mac's local copy is retired once
  this is confirmed working end-to-end.

---
