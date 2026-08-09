# Gap analysis — specification against the running platform

What `specification.md` requires, and what the platform actually does. Measured on venere
(gateway 1.56.0, agent-server 6.151.0) on 7 August 2026.

**This document is the implementation objective.** A specification without it reads as
though everything in it were true.

Three states, and the middle one is the dangerous one:

| | |
|---|---|
| **built** | specified, implemented, and covered by a test that would fail if it broke |
| **partial** | implemented in one place and not another, or built and not enforced. A partial is worse than a gap: whoever reads the specification assumes it works |
| **gap** | specified and not built |

---

## 1. Actors

| § | requirement | state | evidence / what is missing |
|---|---|---|---|
| 1.1 | seed is a type, spawn is a live instance, uid per spawn | **built** | measured on the running instance |
| 1.1 | a spawn cannot reach another's scratch | **built** | the yard root is no longer a destination (tools 1.55.0), but the gateway validates "under `spawns/<something>/`" and cannot require *the caller's own* directory: it knows the seed, while the instance is `"-"` everywhere. **One spawn can still write into another's.** |
| 1.2 | ordinals never reused | **built** | persisted counter, logic 6.150.0 |
| 1.2 | a human is a named spawn, not numbered | **built** | — |
| 1.3 | the archseed exists | **built** | specified 7 Aug. `memory.*` is still a universal namespace granted invisibly to every agent |
| 1.4 | `parents` resolved, default not ceiling | **built** | the field is declared and **nobody resolves it**: `workspace.py` logs «ancestor 'clodia-primal' di clodia non risolto nel registry» and continues |
| 1.4 | inheritance is subtractable | **built** | `denied_tools` exists and beats the allow list; it is not connected to inheritance because inheritance does not exist |
| 1.4 | `abstract: true` enforced at spawn | **built** | — |
| 1.4 | resolved set visible with provenance | **built** | `agents.show` shows the declared set only |
| 1.5 | verbs, skills, prompt+memory, inference vector | **built** | — |
| 1.5 | one model per provider, by design | **built** | the constraint is the current behaviour |
| 1.6 | no rules, no sandbox | **partial** | the sandbox is settled (the kernel separates). `rules` is still a live field — `clodia`/`ophelia` carry `['*']`, `segretario` one entry — and `workspace.py` still copies from `rules-catalog/` |
| 1.7 | two human seeds, `admin` and `member` | **built** | tools 1.49.0–1.50.0; the member matrix is the eleven verbs all three members already carried |
| 1.7 | an individual declaration may only narrow | **built** | intersection evaluated on the verb |
| 1.7 | `superadmin` is an attribute, not a third seed | **partial** | `is_instance_owner()` exists; the field is still spelled `role: superadmin`, because renaming it touches authentication |
| 1.7 | the human system prompt is absent, not inert | **built** | not written at creation |

## 2. Scopes

| § | requirement | state | evidence / what is missing |
|---|---|---|---|
| 2.1 | a spawn lives in exactly two kinds of scope | **built** | the scopeless default chat retired, logic 6.149.0 |
| 2.3 | a job is a scope with its own tier | **built** | logic 6.148.0 — a non-conformant provider fails the run |
| 2.3 | …and its own lists | **gap** | a job falls back to the global lists: `current_channel()` is None, so no per-scope list applies |
| 2.3 | the job's tier reaches the gateway | **built** | it does not travel in the signed claim, so a carried topic in a job is allowed and merely logged — **the one place where the portability rule is written and not enforced** |
| 2.4 | portability declared by the topic | **built** | the mechanism works but is declared on the **seed** (`carries`). Wrong side: an agent that adds a topic to its own list gives itself a channel |
| 2.4 | a carried topic obeys the room's tier, and says so | **built** | tools 1.56.0 |
| 2.5 | the mailbox is global, senders/recipients per scope | **partial** | the lists carry both axes (tools 1.43.0); the mailbox is not modelled as a global resource anywhere — it is a credential, which is the same thing by accident rather than by declaration |
| 2.5 | the terminal is a channel, not a provenance | **built** | `AGENTS.md` and feedback are both wrapped as untrusted context |
| 2.6 | one file view | **built** | tools 1.40.0–1.41.1 |
| 2.6 | **many** remote mounts, each of a kind | **built**, **unexercised** | tools 1.67.0: `meta["mounts"]` is a collection, the legacy singular converted on read, the mount name an identifier rather than a derivation of the kind. Measured on venere 9 Aug: **no topic has a second mount yet** — the shape is right and nobody has used it in anger |
| 2.6 | a kind exists for a scope only if an integration exists | **partial** | integrations exist as a concept and Drive works through one; nothing ties "which kinds a scope may mount" to "which integrations are enabled" — the link is by convention, not by check |
| 2.7 | the gateway holds a **list** of scope credentials per integration | **built** | tools 1.68.0/1.70.0: names derived from `(tier, name, kind, mount)`, one per mount, for git and for Drive. Derived and not chosen: a free name would let two mounts point at one credential without anyone seeing it |
| 2.7 | the owner supplies the credential at mount time | **partial** | git: done (tools 1.68.0). Drive: the **credential** is done (1.70.0, web 0.134.0 pastes the OAuth bundle) but the **consent flow** is not — and it is blocked on one measurement Google's public documentation does not settle: whether picking a folder under `drive.file` grants access to its contents or only to the chosen file. Needs real credentials |
| 2.7 | no fallback to a platform credential | **deliberately not** | the fallback exists and is **visible**: `mount → scope → platform`, with the provenance on the card — the UI, which is Italian, says «credenziale della piattaforma · è un account Google intero, non questa cartella»: *the platform's credential — an entire Google account, not this folder*. Removing it would strand every mount connected before 9 Aug. It stops being a gap and becomes a decision the day a real credential is attached to each mount |
| 2.7 | adding/removing a mount is an owner's act | **built** | it is a `walls` gate |
| 2.7 | export for every member | **built** | reading is every member's |
| 2.7 | the control plane has no path in the data tree | **built** | tools 1.39.0; migration automatic |
| 2.8 | graded membership | **built** | tools 1.44.0, logic 6.146.x; legacy lists read as contributor |
| 2.8 | a reader agent cannot mutate | **built** | tools 1.45.0 — it did nothing before: the role was enforced only on the human path |
| 2.8 | **a scope owner is always human** | **built** | enforced for the configuration topic only, where `owner` would otherwise have defaulted to `clodia`. **The general invariant and its test do not exist** |

## 3. Authority

| § | requirement | state | evidence / what is missing |
|---|---|---|---|
| 3.1 | intersection of seed matrix, scope role, profile | **built** | tools 1.46.0 |
| 3.1 | the refusal says which term blocked | **built** | `reason` distinguishes `ruolo-nello-scope` from `profilo` |
| 3.2 | access belongs to the spawn | **built** and **enforcing** | `CLODIA_SPAWN_COMPARTMENT=on` |
| 3.3 | the origin chain, intersection over every link | **built**, **not enforcing** | `CLODIA_ORIGIN_ENFORCE=report`: it observes and blocks nothing |
| 3.4 | scoped grants, per spawn, with a TTL | **built** | — |
| 3.4 | revoking need not reach a live spawn | **accepted** | known cost |

## 4. Gates

| § | requirement | state | evidence / what is missing |
|---|---|---|---|
| 4.1 | a gate is a crossing, not a verb property | **partial** | the rule is **visible and now said out loud** — the request carries what it crosses and who has standing, from one function (logic 6.160.0). Still **four** gating mechanisms rather than one: the route to collapsing them ran through the configuration topic, which is repealed, so it needs a new one |
| 4.1 | no gate on ordinary work inside a scope | **built** | asserted by test |
| 4.2 | the class travels with the request | **built** | tools 1.48.1 |
| 4.3 | the scope owner decides `walls` and `outward` | **built** | logic 6.147.0 |
| 4.3 | denying needs the same standing | **built** | it had **no check at all** before |
| 4.3 | three outcomes, including "we don't know" | **built** | 503 rather than 403 |

## 5. Perimeter

| § | requirement | state | evidence / what is missing |
|---|---|---|---|
| 5.1 | two lists, two axes | **built** | tools 1.43.0 |
| 5.2 | a repository is a list entry | **built** | the `github.*` verbs land in tools 1.69.0: the gateway clones into the spawn's scratch, `push`/`pull_request` are gated outward, and the credential never enters the agent's process — asserted against the disk, not only intended. `remote: git` still exists as the way an owner *declares* the repository; the verbs no longer go through it |
| 5.2 | the credential is the owner's, not the platform's | **built** | tools 1.68.0: the credential belongs to the **mount**, resolved narrowest-first (mount → scope → platform) with the provenance always visible |
| 5.2 | a Drive folder is a list entry | **built** | tools 1.52.0 |
| 5.3 | membership of the perimeter is vetted | **built** | tools 1.51.0 |
| 5.3 | an undeclared source taints | **built**, **inert** | `source_allow` is **empty** in production, so everything taints — which is the pre-#77 behaviour, not the intended one |

## 6. Tiers

| § | requirement | state | evidence / what is missing |
|---|---|---|---|
| 6.1 | weakest link over data, provider, storage, channel | **built** | — |
| 6.2 | the clearance is the provider's, for **this** spawn | **built** | logic 6.151.0 — it was the seed's, so a spawn moved onto a weaker provider kept the stronger clearance |
| 6.3 | Drive capped at SEAL-2, Telegram at SEAL-1 | **built** | — |

## 7. Invariants

| # | invariant | asserted by a test? |
|---|---|---|
| 1 | a scope owner is always human | yes |
| 2 | the archseed cannot be spawned | yes |
| 3 | every gated verb has a class, and vice versa | yes |
| 4 | no gate on ordinary work inside a scope | yes |
| 5 | the room comes from the signed claim | yes, in three places |
| 6 | a spawn ordinal is never reused | yes |
| 7 | no spawn lives outside a scope | yes |
| 8 | a spawn cannot reach the vault, the topic store or the seeds | yes — from inside, at boot |
| 9 | the clearance is the provider's | yes |
| 10 | authority-bearing writes go through the merging function | **no** |

---

## The work, in order

Ordered by what unblocks what, not by size.

1. **The archseed** (§1.3, §1.4) — five gaps in one piece: the abstract seed, `parents`
   resolved in exactly one place, subtractability, `abstract` enforced, provenance visible.
   It also removes the last universal namespace.
2. **The spawn identity in the signed claim** (§1.1) — closes "a spawn cannot reach
   another's scratch", which the specification claims and the code does not deliver.
3. **The job's tier in the claim, and per-job lists** (§2.3) — closes the one place where
   the portability rule is written and not enforced.
4. **Portability declared by the topic** (§2.4) — turning `carries` around.
5. **Two invariants that do not exist**: a scope owner is always human (§2.8), and the vault
   mask asserted from inside (§7.8).
6. ~~**Mounts, plural, with the owner's own credential**~~ (§2.6, §2.7, §5.2) — **done**
   in rc4: tools 1.67.0 (`meta["mounts"]` a collection, the legacy singular converted on
   read), 1.68.0 (the credential belongs to the mount), 1.69.0 (the `github.*` verbs; the
   gateway clones into the spawn's scratch), web 0.133.0 (the mounts in the sidebar, added
   by the owner). What remains of this item is **Drive's per-scope consent flow**, which is
   product work rather than a vault change. tools 1.70.0 puts the **credential** in place —
   a Drive mount uses the owner's, resolved narrowest-first, with the platform account no
   longer lent silently — and web 0.134.0 lets the owner paste the OAuth bundle. What is
   still missing is the **consent flow itself** (an in-product OAuth round rather than a
   pasted bundle), and it is blocked on one open measurement: whether picking a folder under
   `drive.file` grants access to its **contents** or only to the chosen file. Google's public
   documentation does not say; it has to be measured with real credentials.
7. **`super` away from `ophelia`** — the concept survives in seven places with three
   independent definitions, two of which are not agent authority at all but the
   agent-server's service identity. Untangling those is the work.
8. **Retire the `/clodia/channels/…` prefix** — the same `(tier, name)` is addressed under
   four prefixes.
9. **A new route for collapsing the four gating mechanisms** (§4.1) — the old one ran
   through a repealed entry.
10. **Enforcement** (§3.3, §5.3) — `CLODIA_ORIGIN_ENFORCE=on` and `source_allow` populated.
    **Last, and not without saying so first**: it is the only step that removes capability
    rather than adding it. Before flipping it, read what `report` mode has collected — that
    log is precisely the list of who would lose what.

7bis. ~~**Trello and workflows removed for real**~~ — **done** in rc5 (tools 1.71.0, logic
   6.159.0, web 0.135.0). Measured before removing: no Trello credential in the vault, zero
   workflow runs. Two couplings made the removal dangerous and were found by measuring:
   `gate_public` also served **job** proposals while being mounted behind the workflow
   feature flag, and the gate badge on a topic card counted **run** gates — it would have
   sat at zero forever. Both repointed rather than deleted.

7ter. ~~**The gate card says what it crosses and who decides**~~ (§4.3) — **done** in rc5
   (logic 6.160.0, web 0.136.0). One function serves both the check and the explanation: a
   second copy written in the frontend had already diverged, telling an owner they could
   approve a **system** gate they cannot.

**Out of scope, repealed rather than pending**: the configuration topic, the account
ceiling for Drive, and the per-scope git credential. What shipped of the first is inert.

---

## Is v9 ready? — measured 9 Aug 2026 on venere

**No.** Not because something is broken: because three things that the specification calls
load-bearing have never been exercised.

1. **Enforcement is off** (§3.3, §5.3). `CLODIA_ORIGIN_ENFORCE` is unset and `source_allow`
   is empty: the origin chain observes and blocks nothing, and everything taints. These are
   step 10, and step 10 is the only one that removes capability — it is not to be flipped
   without saying so first.
2. **Nothing has been tested with a real credential.** The mount work, the `github.*` verbs
   and the Drive credential all run against mocks and local git repositories by agreement:
   the real-credential pass was deferred to the end and has not happened.
3. **The new shapes are unexercised in production.** No topic on venere has a second mount;
   the two Drive/git topics still carry the legacy singular, converted on read. The code is
   right and no one has used it in anger.

What is honestly finished is the **model**: scopes, authority, gates, tiers, the perimeter,
and the identity that reaches the gateway. What is not finished is the **evidence** that it
holds outside the test suite.
