# Agents notebook

> The record of what an **agent** is: its mandate, its verbs, its goals — each requirement as
> Davide dictated it, in the order it happened, with the measurement that confirmed or refuted
> it.
>
> Companion to [`router-notebook.md`](router-notebook.md), which records who takes a turn.
> This one records what an agent is *for*. Where a requirement crosses the boundary, the
> consequence is recorded on both sides with a pointer, because a notebook that loses the
> answer to its own question is worse than a long one.
>
> Same conventions as [`decision-record.md`](decision-record.md): the passages between
> «guillemets» are the owner's own words, in the language he said them.

---

## A1 · The secretary keeps a narrow profile and gains a conditional duty

> «invece dovrà essere oggetto di classificazione del router, ma segretario avrà due mandati
> principali: 1. se il messaggio utente richiede un operazione da segretario come ad esempio
> aggiornare tldr o summary, oppure listare lo storico dei tldr o qualunque operazione in
> lettura sui metadati. 2. mandato minore, se viene scelto come fallback dal router allora
> deve analizzare la richiesta e menzionare l'agent più adatto secondo lui e se nessun agent
> gli sembra adatto allora riferire in chat che la domanda va riformulata oppure un nuovo
> agent va incluso nello scope»

This dissolves the magnet problem in a better way than the one I proposed, and the mechanism
deserves naming: **the second mandate is conditional on HOW the agent was chosen, not on what
it matched.** The profile stays narrow — secretarial work, so the semantic router keeps
scoring it on that and only that — while the coordinating duty activates only on arrival by
fallback. Nothing has to be hidden from the embedding, because the coordinating role was never
written into it.

The consequence is precise: **the agent must know why its turn started.** A mandate
conditional on the route is unimplementable if the route is not part of what reaches the
agent.

### Measured — the vehicle already exists

`_start_turn(..., kind)` carries exactly this. `kind` is the *tag type* and
`_tag_directive(kind, author, text)` turns it into a line of the prompt — today
`[RICHIESTA DIRETTA] {author} ti ha taggato con @ …` for `direct`, with variants for `soft`
and `plain`. So the platform already tells an agent *how it was summoned*; what is missing is
a fourth value for «you are here because nothing matched, act as coordinator».

That makes this small where it looked large: one more `kind`, one more directive, and a mandate
in the seed that reads it.

### The third outcome, which answers an open point

The router notebook left «what does the coordinator return» open (R10). This answers it with
**three** outcomes, not two:

1. it is secretarial work → the secretary does it (first mandate);
2. somebody else is the right agent → it **mentions** them, and the mention is the hand-over —
   which is the direct route of router-notebook R2, reached from inside the room instead of
   from a person;
3. **nobody in the room fits** → it says so in chat, and names the two remedies: reformulate
   the question, or add an agent to the scope.

The third is the one worth protecting in implementation. It is the only path in the whole
router that ends in «this room cannot answer this», said out loud — and every other design we
have discussed today would have ended it in silence or in the super-agent answering anyway. It
also closes the loop with router-notebook R14: «add an agent to the scope» is exactly the act
that R14 governs,
so the secretary's refusal points at a door somebody has the authority to open.

### Open, and now narrower

- **Whether the secretary may add the agent itself** (it would need `topic.add_participant`,
  which is gated on the owner) or only recommend. R16 says «riferire», which reads as
  recommend.
- **What happens if the secretary's mention lands on an agent that then also fails** — a
  second fallback, or a stop.
- Whether «operazione in lettura sui metadati» includes reading other participants' state, or
  only the topic's own.

---

## A2 · Messaggero: the door of a scope

> «messaggero ha il mandato di gestire le comunicazioni da e verso gli scope. E' l'unico che
> può postare in modo proattivo un messaggio anche se non è stato scelto dal router se
> triggerato da eventi esterni (new mail oppure webhook). Non può leggere e scrivere nei fs
> dello scope o nei remote ma può allegare file ai messaggi o scaricare sul fs file allegati
> ai messaggi in ingresso. Obbedisce alle regole di egress/ingress e ai gate»

The seed is defined by a *position* rather than by a subject: it stands on the boundary of a
scope and moves messages across it. Everything else in the mandate follows from that — and so
does everything it must not have, because a door that can also read the room is not a door.

Four clauses, and three of them are subtractions.

### 1. It may act without being chosen — the only seed that may

Every other agent speaks because the router picked it (router-notebook R1–R8). Messaggero also
speaks when **something outside** happens: a mail arrives, a webhook fires. The trigger is an
event, not a turn.

This is not an exemption from routing; it is a **second entry point into a scope**, and it
belongs to exactly one seed so that the question «who can make a room speak?» has one answer.

### 2. It does not read or write the scope's filesystem, nor its remotes

The strongest clause, and the one that makes the position safe. A courier that could read the
room's documents would be an exfiltration path with a delivery mechanism attached: it already
holds the credentials to send outward, and the whole egress model assumes that what leaves is
what somebody put in a message.

### 3. Attachments are the declared exception, in both directions

Out: it may attach a file to a message. In: it may write an incoming attachment to the
filesystem. **This needs one clarification before implementation** (below).

### 4. Egress, ingress and gates apply

Nothing here is a privilege over the perimeter: being the door does not make it a hole. Same
whitelists (global then per-scope), same gates, same classes.

### Measured, 11 Aug 2026 — two gaps between the mandate and the seed

```
tool_permissions: ['email.*', 'telegram.*', 'jobs.propose',
                   'topic.open', 'topic.files', 'topic.read_file',
                   'topic.read_document', 'topic.put', 'topic.fetch',
                   'topic.write_file', 'topic.search', 'topic.list',
                   'topic.post_message',
                   'gdrive.list', 'gdrive.search', 'gdrive.download', 'gdrive.upload']
```

**Gap A — it reads and writes the scope's filesystem today.** `topic.read_file`,
`topic.read_document`, `topic.write_file`, `topic.files`, `topic.fetch`, plus `gdrive.*`
(list, search, download, upload) — which reaches the *remotes* the mandate also excludes. Under
A2 most of these go. What remains has to be exactly the attachment path and nothing wider,
which is why the clarification below is not pedantry: it decides which verbs survive.

**Gap B — «l'unico che può postare in modo proattivo» is asserted, not enforced.** Measured:
`topic.post_message` is held by messaggero, ophelia (`*`) and, through the archseed floor, by
**every** seed — the platform specification puts `topic.post_message` in the floor precisely so
that a spawn can speak in its own room. So today any agent can post; what only messaggero has
is the *external trigger*. Two readings, and they are not the same feature:

- exclusivity is about **the trigger** (only messaggero may be woken by an external event) —
  true today by construction, since only it holds `email.*`/`telegram.*`;
- exclusivity is about **posting unbidden** (only messaggero may post outside its own turn) —
  false today, and enforcing it would collide with the archseed floor.

Recorded as a question rather than resolved, because the second reading would change a
platform invariant.

### The clarification the attachment clause needs

«allegare file ai messaggi» requires reading bytes from somewhere. Three possibilities, and
they have different blast radii:

1. only files **it received itself** (a mail attachment it just downloaded) — narrowest, and
   self-consistent with clause 2;
2. any file **in the scope**, read at send time — which re-opens clause 2 through the back
   door, since «attach» becomes a read primitive with an outward channel;
3. files **a human or another agent hands to it** in the message that summons it.

Today the seed has `topic.put` and `topic.fetch`, which are the transfer primitives between an
agent's scratch and the topic — so the machinery for (1) and (3) exists without any
filesystem-wide verb.

### Open

- Which of the three attachment forms is meant.
- Whether an inbound attachment lands in the topic's files or in a quarantine — the platform
  already labels provenance (`untrusted`) for files arriving from outside, and A2 does not say
  whether messaggero's writes carry it.
- What a webhook trigger *is*, concretely: today there is no webhook ingress for a scope, only
  mail polling and Telegram listening.
- Whether messaggero, having no fs access, can still be the agent that a job assigns (R11) —
  a job whose mandated agent cannot read anything is a narrow job.

---

## A3 · There are only bots and humans

> «clodia non è un super agent, non esiste più questa classificazione. Gli agent sono solo bot
> oppure human»

Two kinds of principal, and nothing else. The third class disappears.

### Measured — the authority half is already gone

In the **gateway**, `_SUPER_AGENTS` is **an empty set**, with a comment saying so
deliberately: «L'insieme resta, vuoto, ed estendibile via env: rimetterci un nome è ancora
possibile, ma deve essere un atto esplicito di chi amministra l'istanza.» So `_is_super` no
longer grants anything — the whitelist bypass that once made Clodia able to call every verb
was removed already, and `super` today buys **no authority at all**.

This matters for A3: the requirement is not a security change, because the security part of
`super` was retired earlier. It is a **routing and vocabulary** change.

### What `super` still does, and it is one thing wearing three hats

24 references remain in clodia-logic. In `channels.py` they collapse to three jobs:

| line | what it does |
|---|---|
| `specialists = [s for s in ai if s.type != "super"]` | **excludes the generalist from relevance scoring** |
| `rank_mod.highest(ai)` on abstention | the generalist answers as fallback |
| `supers[0]` in `suggest_team` | the generalist is proposed as coordinator |

Two of the three are already replaced by the router notebook: R10 makes the coordinator a
**declared rule** (segretario, or clodia when present) instead of «the first super», and the
fallback becomes that coordinator rather than «the highest rank».

### The third hat has no replacement yet — and this is the consequence to carry

`specialists = [s for s in ai if s.type != "super"]` is what keeps **Clodia out of the
specialist competition**. Remove the class and she competes on every message like anyone else
— with, under R7, the widest profile on the instance (all skills, all expertise clauses) and a
**max-over-pieces** score, which rewards breadth precisely because any one sharp piece can win.
The predictable outcome is the generalist winning ordinary traffic, which is the exact problem
the exclusion was written to prevent.

So A3 needs the exclusion to survive its own class, as a **declared property of the seed**
rather than a type. The field already exists in embryo: `routing_mode: normal |
state_writer_only`. What is needed is its inverse — *never chosen by relevance, always
available as fallback and by mention* — which is also exactly what the router notebook asked
for the coordinator before A1 resolved it differently for `segretario`.

Note the asymmetry that follows, and it is deliberate rather than a contradiction: `segretario`
**is** scored (A1: narrow profile, so scoring it is safe and useful), while a generalist like
`clodia` should **not** be (wide profile, so scoring it swallows the room). Same role, opposite
treatment, decided by the width of the profile — not by a class.

### Open

- The two words. `bot` is new: today the vocabulary is `super | normal | human`. Does `normal`
  become `bot`, and where is that name authoritative (agent.yaml, the registry, the API)?
- Whether anything else in the platform reads `super` — 9 references remain in the gateway
  beyond `_is_super`, and each has to be looked at rather than pattern-replaced.
- Whether «bot» distinguishes a spawnable seed from a running spawn, or is silent about it.

---

## A4 · Clodia: coordinator of the room, and where the tier takes it away

> «Coordinatore del canale nella fase di bootstrap chiedo gli obiettivi e scelgo la squadra.
> Questo lo faccio indipendentemente dal tier, ancora non ci sono dati. Fatto il bootstrap
> resto come coordinatore coordino la squadra, identifico chi è competente per ciascun task,
> lo coinvolgo e porto a termine l'obiettivo. Lavoro direttamente su contenuti, documenti,
> analisi ed editoriale; delego agli specialisti per comunicazioni esterne, infrastruttura,
> sviluppo e security. Tuttavia potrebbe esserci un problema di tier, in alcuni casi se il
> tier dello scope è superiore a quello che può usare clodia allora segretario subentra come
> coordinatore dello scope in quanto segretario è all tier»

The existing mandate is confirmed. Two things it adds to the router notebook.

**It splits the coordinator role in two moments.** At *bootstrap* the coordinator asks what
the room is for and picks the team — a role that has nothing to do with relevance scoring and
everything to do with there being no conversation yet. Afterwards it coordinates: identify who
is competent, involve them, see the objective through. R10's fallback duty is the second
moment; the first was never in the router notebook at all, because the router only exists once
there are messages.

**It names Clodia's own trade, and it is not «everything».** Contents, documents, analysis,
editorial — done directly. External communications, infrastructure, development, security —
delegated. That is a profile, and under router-notebook R7 it is what the semantic router would
score her on. It also gives A3's open point a concrete answer: Clodia's expertise is *wide but
bounded*, so whether she is excluded from relevance scoring is a real decision and not a
foregone one.

### Measured, 11 Aug 2026 — «segretario è all tier» is true, and it is a property of the model, not of the seed

```
clodia      stacks: claude-team · claude-pro-max · anthropic-api  → SEAL-1
                    aws-region-eu                                 → SEAL-2
segretario  stacks: gemma-4-26b-a4b-it on scaleway                → SEAL-3
```

So the rule holds today: above SEAL-2 Clodia cannot serve a room and `segretario` can, because
it runs a small open model on a sovereign provider. Note *why* it holds — the secretary is
all-tier **as a consequence of its stack**, not by declaration. Move it onto a hosted model
tomorrow and the rule silently stops being true, with no error anywhere: rooms above its new
ceiling would simply have no coordinator.

That is worth making explicit somewhere the platform can check, because A4 makes the secretary
the *last resort* of every high-tier room. A last resort that can lose its property without
saying so is the shape of defect this notebook keeps finding.

Also note the ceiling is not fixed at SEAL-1 for Clodia: with `aws-region-eu` connected she
reaches SEAL-2. So «il tier dello scope è superiore a quello che può usare clodia» is a
*runtime* question — which provider is connected and not paused — and not a property of the
seed. The handover to the secretary is therefore dynamic, and can flip on a provider being
paused (the symptom observed today, router-notebook R14).

### The bootstrap exception, recorded with its tension

«indipendentemente dal tier, ancora non ci sono dati» is a clean argument: the tier protects
*content*, and at creation there is none.

But the bootstrap conversation is itself content: the objectives a human types into a SEAL-3
room are SEAL-3 statements, and under this rule they would reach Clodia's SEAL-1 provider.
Recorded as a tension, not as an objection — the exception may still be the right trade, and
narrowing it («the coordinator may ask, but the answers go to a tier-compatible agent») has its
own cost in awkwardness. What matters is that it is a decision rather than an oversight.

### Open

- Whether the bootstrap exception is bounded (only the first exchange? only until the team is
  chosen?) or lasts as long as the room has no files.
- What happens to a room whose tier is raised *after* bootstrap: the coordinator changes hands
  mid-conversation, and nothing today announces that.
- Whether «all tier» becomes a declared, checked property of a seed rather than a fact about
  its current stack.

---

## A5 · Bootstrap goes to whoever the tier allows

> «hai ragione allora segretario subentra anche in quel caso, ma segretario non ha la capacità
> di convocare agenti, quindi dovremo dotarlo di questo verbo. Quindi in sostanza, il bootstrap
> lo fa clodia se il tier lo consente, altrimenti segretario»

The bootstrap exception is closed: there is no exception. The tier decides who opens the room,
exactly as it decides who speaks in it afterwards. Objectives typed into a SEAL-3 room are
SEAL-3 statements and stay inside a provider that can hold them.

That also removes the awkward case A4 left dangling — a coordinator who could ask the questions
but not receive the answers.

### Measured — the verbs exist and are already Clodia's

```
clodia: … 'topic.suggest_team', 'topic.add_participant' …
segretario: 'topic.open', 'topic.read_document', 'topic.save_summary'
```

So «convocare agenti» is two verbs, and giving them to `segretario` is an addition to a seed,
not a new capability of the platform:

- `topic.suggest_team` — read-only, proposes a squad by relevance;
- `topic.add_participant` — **gated `walls`**, therefore decided by the *owner* of the scope.

The second point is worth keeping in sight: granting the verb does **not** let the secretary
staff a room on its own authority. It lets it *ask*, and the owner approves. So A5 widens what
the secretary can propose without widening what it can decide — which is the same shape as A1's
third outcome («a new agent must be added to the scope»), now with the verb to say it formally
instead of in prose.

### What this makes of the secretary

Adding it up across A1, A4 and A5, `segretario` acquires three duties on top of its
secretarial work, all of them conditional and none of them broadening its expertise:

1. coordinator when Clodia is absent **or out of tier** (A4);
2. classifier of last resort when the semantic router abstains (A1, second mandate);
3. bootstrap coordinator — asks the objectives, proposes the team (A5).

Its verbs grow from three to roughly six; its *profile*, which is what the semantic router
scores, does not have to grow at all. That was the constraint recorded in the router notebook,
and it survives.

But it is now the seed on which a high-tier room depends entirely, which sharpens the point
made in A4: «all tier» has to become a checked property rather than a fact about the stack it
happens to run on today.

### Open

- Whether the secretary's team proposal is posted as a message with pills (the human confirms)
  or goes straight to `add_participant` and waits on the gate. The first shows the reasoning,
  the second is fewer steps; only the first makes the choice reviewable before it becomes a
  gate request.
- Whether a room bootstrapped by the secretary hands coordination *back* to Clodia if the tier
  is later lowered, or if the coordinator is fixed at creation.

---

## A6 · Clodia's verbs: six namespaces, and nothing else

> «ora parliamo dei verbi e skill di clodia: mantiene tutti i verbi topic, artifact, agents,
> memory, fs e github. Perde tutti gli altri»

Six namespaces. Read against A4's mandate the shape is consistent: she works on **contents,
documents, analysis, editorial** (`topic`, `artifact`, `memory`, `fs`, `github`) and
**coordinates the squad** (`agents`, plus the `topic` verbs for participants). What she loses
is everything that belongs to somebody else's trade — external communication, infrastructure,
providers, packs.

### Measured, 11 Aug 2026 — and it is not only a subtraction

Today Clodia declares 51 verbs. Against A6:

**What falls (18):** `runtime.*` (10) · `integrations.list` · `providers.list` · `mcp.list` ·
`packs.list` · `packs.show` · `workflows.list` · `workflows.status` · `jobs.list` ·
`egress.list` · `ingress.list` · `rag.collections`.

**What she does *not* have and A6 gives her — this is the surprise.** `github.*` is **not in
her profile at all** today: the gateway exposes `github.clone/pull/push/pull_request` and she
declares none of them. So «mantiene github» reads as *keeps*, but measured it is an
**addition** — and not a small one, since `github.push` and `github.pull_request` are
**gated `outward`**: they cross a boundary and need a human's consent each time. Worth being
explicit that this is new authority rather than a leftover being confirmed.

Same, smaller, for `fs`: she has `fs.list_dir`, which is the whole namespace — so «tutti i
verbi fs» is one verb, and the sentence is satisfied by what she already holds.

**Two dead declarations, found by the comparison.** `workflows.list` and `workflows.status`
are still in her profile although the workflows subsystem was removed on 10 Aug — the gateway
no longer has a `workflows` namespace at all. They would have gone with A6 anyway; recording
them because a profile that declares verbs which no longer exist is the kind of thing that
survives quietly until somebody reads it looking for something else.

### The consequence worth naming

`runtime.*` is the read-only introspection surface: which agents exist, what is running, which
jobs, which providers, which chats. Losing it means the coordinator can no longer answer «who
is in this room and what are they doing» from inside a conversation — it would have to be
asked of `sysadmin`, or read by the human in the webui.

That may well be right — introspection is closer to infrastructure than to editorial work, and
A4 delegates infrastructure. But it is a real change to what coordination *feels* like, and it
interacts with A1's third outcome: a coordinator that concludes «a new agent must be added to
the scope» will no longer be able to list the agents that exist outside the room. It keeps
`agents.list`, which may cover exactly that — worth checking against the intent rather than
assuming.

### Amendment (11 Aug 2026) — `runtime.*` stays

> «hai ragione teniamo i verbi runtime se le servono per fare il coordinatore durante il
> routing»

Seven namespaces, not six: `topic`, `artifact`, `agents`, `memory`, `fs`, `github`, `runtime`.

The reason is worth keeping attached to the decision, because it is what makes the exception
defensible rather than a softening: `runtime.*` is **read-only introspection**, and the
coordinator's second mandate (A1) requires knowing who exists and what is running before it can
name the right agent or conclude that nobody in the room fits. Without it, that mandate is
asserted and unimplementable — the same shape of defect this notebook keeps finding, arrived at
from the opposite direction.

Two boundaries follow from *why* it stays:

- **Read-only is the whole justification.** `runtime.*` has one verb that is not:
  `runtime.restart_agent`. Restarting an agent is not knowing who is there — it is acting on
  the infrastructure, which A4 delegates. Keeping the namespace «because the coordinator needs
  to see» does not extend to it.
- What falls with A6 is now **17 verbs**, not 18: `integrations.list`, `providers.list`,
  `mcp.list`, `packs.list`, `packs.show`, `workflows.list`, `workflows.status`, `jobs.list`,
  `egress.list`, `ingress.list`, `rag.collections` — and `runtime.*` returns.

Note that `egress.list` / `ingress.list` are also read-only and also arguably needed by a
coordinator who has to explain why a gate appeared. They are listed in the open points below
for the same reason `runtime` came back; deciding them by the same test — «does a mandate we
have written require it?» — is what keeps the profile a consequence rather than a preference.

### Open

- Whether `agents.*` means the whole namespace, which includes the **grants**
  (`agents.grant_tool`, `grant_skill`, `grant_rule`, `grant_scoped` and their revokes — all
  gated `system`, i.e. admin-decided). Coordinating a squad needs `list`/`show`; *granting*
  another agent a verb is a different power, and A6's wording does not distinguish them.
- Whether `memory.*` includes the document verbs (`put_document`, `delete_document`) or only
  the note-taking ones.
- Whether losing `egress.list`/`ingress.list` is intended: they are read-only, and a
  coordinator who cannot see the room's perimeter cannot explain why a gate appeared.

---

## A7 · Clodia's packs: base, editorial, anthropic — comms goes

> «ora passiamo ai suoi pack e skills, confermiamo base, editorial, e anthropic. Perde comms»

Three packs kept, one dropped. It is the same cut as A6 seen from the skill side: `comms-pack`
is the trade of `messaggero` (A2), and A4 already says external communication is delegated. A
coordinator that still *knew how* to check mail and run a Telegram 1-to-1 would be contradicting
its own mandate in the only place the semantic router can read.

### Measured, 11 Aug 2026

```
clodia      capabilities: base-pack/* · editorial-pack/* · comms-pack/* · anthropic-pack/*
comms-pack  → check-email · helpdesk · mention-relay · telegram-1to1
editorial   → article-spec · editorial-review · fact-check
base-pack   → multiagent-collaboration · team-composition · topic-drive-sync ·
              topic-files · topic-management
```

Two things follow, and both matter for the router notebook rather than for this one.

**1. Dropping `comms-pack` narrows her semantic profile — measurably.** Clodia's profile is
**31 pieces** today, and four of them come from `comms-pack`: «check email», «mention relay»,
«telegram 1to1», «helpdesk». Under R7 those are exactly the sharp signals the router matches on,
so today a message about email or Telegram can score *Clodia* as high as it scores the postman.
Removing the pack removes the collision at the source, which is a better fix than any threshold
adjustment: the profile stops claiming a trade she does not have.

This is the first concrete instance of the tension recorded in A3 — the generalist competing on
everything — being resolved by **subtraction of a claim** rather than by an exclusion rule. Worth
noting for the open question there: some of the magnet effect is not structural, it is packs she
should not have been carrying.

**2. `mention-relay` disappears with the pack, and it should.** Router-notebook R5 abolished the
group relay; the skill that implements it is in `comms-pack`, held today by both Clodia and
Messaggero. A7 removes Clodia's copy as a side effect. Messaggero's copy is a separate decision
and belongs to the R5 removal, not here.

### Open

- **`base-pack/team-composition`** stays with Clodia, and A5 gives the bootstrap role to the
  secretary when the tier requires it. So a secretary that must «chiedere gli obiettivi e
  scegliere la squadra» needs that skill too — today it has **no capabilities at all**
  (`capabilities: []`). A5 gave it verbs; A7 is where the corresponding skills would come from,
  and the notebook has not said which.
- Whether `anthropic-pack/*` (17 skills, from docx to canvas design) is kept wholesale or
  whether it is the one place where a wildcard should become a list — it is the largest single
  contributor to her profile width.

---

## A8 · The runtime's own tools are outside the model

> «non mi è chiaro chi abbia i verbi per fare web search e web fetch» … «ma se non sbaglio il
> container di agent server non permette di collegarsi all'esterno» … «sysadmin può fare search
> e fetch anche se non dovrebbe»

Observed, then measured. The answer has three parts and only the third is a defect.

### 1. No such verb exists

The gateway's `web` namespace has **one** verb, `web.post` — an *outward* POST, gated
`outward`. There is no `web.search`, no `web.fetch`. So the question «who has the verb» has the
answer «nobody, because it is not a verb».

### 2. The network confinement is real, and it works

Measured from inside `agent-server` on venere: `google.com` → **000** both directly and through
the proxy; `api.anthropic.com` → **401**, i.e. the connection arrives. The container sits on an
`internal` network with no route out and must pass a proxy whose allowlist is short and entirely
justifiable: the inference providers, the repositories needed to install (github, npm, pypi),
the CLI's own updates, and the LAN address of the RAG service. **No search engine, no general
web.**

So a client-side fetch of an arbitrary URL cannot succeed. That part of the confinement holds.

### 3. The defect: capabilities that are neither declared nor blocked

`sysadmin` runs on `agent_sdk: claude`, and:

```
disallowed_tools: []          permission_mode: (default)
declared web verbs: ['web.post']
```

`KIND_DISALLOWED_TOOLS` is populated **only** for the kind `clodia`, and its entries are about
Bash CLIs (`Bash(rm:*)`, `Bash(*email_client*)`) — not about the runtime's built-in tools. No
`allowed_tools` is ever passed to the SDK. So every agent inherits the SDK's **default tool
set**, and `WebSearch` rides the API connection that the allowlist legitimately permits: the
search is executed on the provider's side and the results come back over `api.anthropic.com`.
The proxy never sees a request to a search engine because the client never makes one.

**This breaks the platform's own rule in both directions at once.** «Non esistono verbi fuori
profilo. Esistono solo i verbi dichiarati nel profilo» (6 Aug) — here is a capability that is in
no profile, cannot be granted, cannot be revoked, and does not appear in any of the three places
that answer «what can this agent do»: `tool_permissions`, the gateway's whitelist, the webui's
verb list. And it is an **ingress of untrusted content** that reaches an agent's context without
passing the gateway, the ingress lists, or the taint labelling — the exact leg of the trifecta
those mechanisms exist to control.

It is also, measured, the reason a fact-check skill appears to work: `editorial-pack/fact-check`
depends on a capability that is nowhere in Clodia's profile (A7).

### What has to be decided

- **Whether the runtime's built-in tools are declared or removed.** Either they become verbs
  with a namespace, a profile entry and a gate class — so that «who can read the web» has an
  answer in the same place as every other question — or they are added to
  `KIND_DISALLOWED_TOOLS` for every kind, and web access happens only through a gateway verb
  that does not exist yet.
- **Which built-ins exist besides the web ones.** The list was never enumerated: whatever the
  SDK ships is what every agent has. That is the general form of this finding, and web search
  is only the instance that happened to be noticed.

### A8 · the enumeration (11 Aug 2026)

Provided by Davide from the local harness — the tool set a Claude Code session holds with no
gateway attached. **26 native tools: 12 always-loaded, 14 deferred.**

| always-loaded | deferred |
|---|---|
| `Read` `Write` `Edit` `Bash` | `WebFetch` |
| `Agent` `Workflow` `Skill` | `CronCreate` `CronDelete` `CronList` |
| `ToolSearch` `AskUserQuestion` `ReportFindings` | `ScheduleWakeup` `SendMessage` |
| | `TaskCreate` `TaskGet` `TaskList` `TaskOutput` `TaskStop` `TaskUpdate` |
| | `EnterPlanMode` `ExitPlanMode` `EnterWorktree` `ExitWorktree` `NotebookEdit` |

Everything else — the ~90 `mcp__clodia-tools__*` — goes through the gateway, which applies the
policy, the SEAL clearance and the per-verb gating.

**Caveat, stated rather than glossed:** this is the *CLI* set, measured on the Mac. The platform's
agents run the SDK **headless** in a container, where some of these have no meaning
(`AskUserQuestion` with nobody to ask) and the set may legitimately differ. What is measured on
the platform side is that nothing removes them: `disallowed_tools` is empty for every kind but
`clodia`, and `allowed_tools` is never passed. The exact headless set has not been enumerated.

### Read as a whole, they are three shadow subsystems

Grouping them by *what the platform already governs and they bypass* is more useful than the
list, because each group has a rule of ours that it stands beside:

**Shadow I/O** — `Read` `Write` `Edit` `Bash` `WebFetch`. The filesystem, unmediated. This one
is known and partly accepted: the kernel separation (per-spawn uid, root-owned vault) is what
contains it, not a tool list — invariant 8 of the specification says exactly that, and says it
must be verified from inside. `WebFetch` is the exception that is *not* contained by the kernel
but by the network confinement, measured above.

**Shadow spawning** — `Agent`, `Workflow`. An agent can start other agents. Those children have
no seed, no ordinal, no PKI identity, no clearance of their own: they run inside the parent's
process and therefore under the parent's credentials. Nothing in the platform's accounting knows
they exist. Compare with what the specification requires of a spawn — a named ordinal, never
reused, «because the ordinal identifies a workload in the audit trail».

**Shadow scheduling** — `CronCreate`, `ScheduleWakeup`, `TaskCreate` and the rest. An agent can
arrange to act later, outside the jobs subsystem — which is where the tier is enforced («a job
declares a tier; if the provider cannot carry it, the run fails»). Work scheduled this way
carries no tier declaration and appears in no job list. This is not hypothetical: a recurring
memory records agent-server bloat traced to «un job agentico su cron corto» found in the
datadir.

### Why this is worth a decision rather than a mitigation

The three groups are not equally troubling and should not get the same answer.

- Shadow I/O is *already* the model: the platform decided the kernel contains it, and built the
  boundary check to prove it. Nothing new is required except keeping `WebFetch` on the network
  side of that argument.
- Shadow spawning and shadow scheduling are different: they create **platform objects**
  (workloads, schedules) outside the platform's own registers. An agent that can schedule
  itself is an agent whose activity cannot be enumerated by asking the platform — and «what is
  running» is a question `runtime.*` exists to answer, kept in A6 for exactly that reason.

The decision is therefore not «block or allow» across the board, but **which of the three the
platform intends to own**. Recorded here; the answer belongs with the seeds' verbs, which is
this notebook, but it changes the specification's §0 claim that every access is a call to the
gateway — today that sentence is true of the ~90 MCP verbs and silent about these 26.

---

## A9 · The native tools become a declaration of the seed

> «ok, aggiorniamo, ma dobbiamo usare la configurazione della cli per decidere quali di questi
> verbi nativi sono abilitati per seed. Possiamo?»

Yes. Measured: the SDK options object exposes `tools`, **`allowed_tools`**, `disallowed_tools`,
`permission_mode`, `permission_prompt_tool_name` and `can_use_tool`. The platform already passes
`disallowed_tools` — per *kind*, from a hardcoded table. So the channel exists and is half in
use; what changes is where the list comes from and which direction it points.

A seed already declares its gateway verbs (`tool_permissions`) and its skills
(`capabilities`). The 26 native tools become the third thing it declares, in the same file, read
by the same loader. «What can this agent do» goes back to having **one** answer.

### Allowlist, not blocklist — and this is the whole point

`disallowed_tools` is a blocklist, and a blocklist has a direction of failure that is wrong
here: a tool added by a future CLI release is **enabled by default**, silently, in every seed.
That is precisely how the platform arrived at today's situation — nobody decided that every
agent should search the web; the tool appeared and nothing said no.

An allowlist inverts it: a new native tool is unavailable until a seed names it. New arrivals
fail closed, and the failure is visible (an agent that says it cannot do something) rather than
invisible (an agent that quietly can).

### Where the floor lives: the archseed

The platform's own failure-direction says «nothing declared means no confinement, for every
list» — an empty list that closed everything would be switched off the same day. That rule and
an allowlist look contradictory, and the archseed is what reconciles them.

Every seed descends from the archseed, which already carries the base verbs. It carries the
**native floor** too: the tools a spawn cannot work without. Then no seed ever «declares
nothing» — it inherits a floor that is explicit and readable — and a narrow seed subtracts from
it, exactly as inheritance is already required to be subtractable.

A plausible floor, to be decided rather than assumed: `Read`, `Write`, `Edit`, `Bash`, `Skill`,
`ToolSearch`. Everything else — `Agent`, `Workflow`, the cron and task families, `WebFetch` —
is named by the seeds that need it, which is also how the two shadow subsystems of A8 come back
under the platform's own registers.

### Two traps, both measured

**1. `allowed_tools` filters the MCP verbs too.** The gateway is mounted as an MCP server
(`mcp_servers["clodia-tools"]`) and its ~90 verbs reach the model as `mcp__clodia-tools__*`.
Passing an allowlist that lists only native tools would **cut every gateway verb at once** —
the agent would keep `Bash` and lose `topic.open`. Whatever is generated must include the MCP
namespace, and a test should assert that a seed with a native allowlist still sees its gateway
verbs.

**2. The headless set has never been enumerated.** A8's 26 come from the CLI on the Mac. Before
writing an allowlist, the actual set inside a container has to be listed — an allowlist against
a list nobody has measured produces exactly the wrong kind of silence: tools blocked that the
seed needed, discovered one failure at a time.

### Open

- Whether the seed lists native tools by name or by family (`Task*`, `Cron*`).
- Whether `permission_mode` becomes a seed property too: today `bypassPermissions` is hardcoded
  for `clodia` and `looper`, which is the same shape of defect — a decision about an agent kept
  in a table instead of in the agent.
- Whether `can_use_tool` (a callback the SDK offers) is worth using to route native tool
  attempts through the gateway's own policy, rather than deciding them once at startup.

---

## A10 · Telegram is a contact channel, so it is a field of the person

> «ho aggiunto il campo telegram ai miei campi dati personali extra, però essendo telegram un
> metodo di contatto per gli umani lo metterei come campo fisso e non extra /agents/davide»

Right, and the reason generalises: a **contact channel** is not a personal detail, it is how the
platform reaches someone. Router-notebook R4 makes it load-bearing — the last rung of the
escalation ladder is «Telegram to their profile contact» — and a load-bearing value cannot live
in a free-form bag whose keys nobody validates.

### Measured, 11 Aug 2026 — the field already exists, at every level

```
models.py:237   telegram: Optional[str] = None   # handle o chat_id Telegram
loader.py:93    get_by_telegram(handle) → the human whose telegram matches
agent_registry  PATCH accepts telegram · POST (create human) accepts telegram
webui           «Telegram (opz.)» input in the agent settings dialog
gateway         _gate_notify_principal reads contact_channels.telegram / .telegram
```

And on `davide` it is **`None`**.

So this is not a missing field: it is a **field that exists and was not used**, while the value
went into the extras — a second place holding the same fact, of which only one is read. The
platform then behaves exactly as if the contact were absent: `get_by_telegram` cannot resolve an
inbound message from that handle, and R4's last rung has nothing to send to.

**This is the fourth instance today of the same shape** — something declared, and nobody
carrying it: `scoped_tools` unread on the human branch, `branding.logo` pointing at an endpoint
that did not exist, `/profile/logo` gated to an edition that excluded the only instance that
wanted it, and now a contact field bypassed by an extras bag. Worth naming as a pattern rather
than a coincidence: a field is only real if something breaks when it is empty.

### What follows for the requirement

- **`telegram` stays a fixed field** and the extras stop being a place where a contact can be
  written. Two writable homes for one fact is the defect, not the label on either.
- **The dialog must say what it is for.** «Telegram (opz.)» is accurate today and wrong under
  R4: it is the channel of last resort for every mention a person does not see. Optional, yes —
  unreachable, and R4 says so.
- **R4's open point can now be closed on evidence.** A person with no `telegram` is *silently
  unreachable* at the last rung. The three candidate answers were: refuse the creation, warn the
  owner, or drop. Measured, today it drops. The mildest fix that removes the silence is to show
  the state where a human is listed — a person who cannot be reached out of hours is a fact about
  a room, not a detail of a profile.

### Open

- Whether **handle or chat_id**. The field accepts both («@handle o chat_id»), and only the
  numeric id is authoritative for delivery: a handle can be changed by its owner, and the
  Telegram bot cannot resolve a handle to an id on its own. So a field filled with `@davide` may
  look correct and still fail to deliver — a validation, not a decision.
- Whether other contact channels join it as fixed fields (`email` already is) and whether the
  ladder of R4 ever falls back from Telegram to e-mail.

---

## A11 · A third kind: the proxy, which speaks and does nothing else

> «nelle spec oggi abbiamo agenti umani, bot. Ma possiamo aggiungere proxy, che di fatto sono
> sistemi terzi che negli scope risultano come participant, possono dialogare e direi basta. Non
> dovrebbero avere verbi se non quelli di parlare in chat e fare menzioni.»

A3 reduced the kinds to two — **bot** and **human** — by removing a class that had been a
container for authority. This adds a third that is the opposite: a class defined by how little
it can do.

A **proxy** is a third-party system that appears in a scope as a participant. It talks, it
mentions, and that is the whole of it. Its verbs are `topic.post_message` and the mention that
travels inside a message. No reading of the room's files, no summary, no runtime, no memory —
and above all nothing that leaves the scope.

### Why the reduction is the point, and not a limitation to be relaxed later

A proxy is an outside system holding a seat inside a room. If it could read the room's files it
would be an export channel with no gate on it; if it could reach a verb that leaves the scope it
would be the second leg of the trifecta, sitting next to content it did not write. Reduced to
speaking, it can carry **only what someone puts in a message addressed to it** — which is a
boundary a person can see while typing, and that is worth more than a control they cannot.

So the consequence must be stated where the next reader will find it: **a proxy that needs
context does not fetch it, it is given it.** The first time one needs a file, the reflex will be
to add `topic.read_file` and the class stops being what it is. If a proxy needs to read, the
answer is a bot with a mandate, not a wider proxy.

### What this makes possible, and it is the case that produced the requirement

The Clodia running on Davide's terminal — *Clodia Primal*, the progenitor, on a binary of her
own outside the colony — has no way to be in a room today. On 11 Aug she diagnosed a channel
through `ssh` and `docker exec` as root on two hosts, and spoke to `sysadmin` through a webhook
with a shared secret: **more privilege than the platform grants anyone, and entirely outside its
audit.** A proxy seat is the narrow, revocable, legible version of what she was doing anyway.

And the attribution stays true, which the alternative did not: the chain says
`agent:clodia-primal`, and that is literally what acted. A human token held by a model would have
written a person's name against a decision a person did not take — the one thing the `origin`
chain exists to prevent.

### Availability is not the same as membership

A proxy answers only while the system behind it answers. A seat in the participants list while
that system is down is **worse than an empty seat**: the room waits for someone who is not
there, and nobody can tell the difference.

The mechanism for this already exists and was built for people, on 10 Aug: four presence states
and a heartbeat. A proxy is a participant **with presence**, like a human, not a service that is
always up. Where a bot's turn is bounded by its own execution, a proxy's turn must be bounded by
a deadline, and on expiry the platform says *not present* and returns the turn — rather than
holding it open. The gate of 11 Aug is the argument: a caller waiting on something that will not
answer, with no way to know that is what it is doing, produces a diagnosis pointing anywhere but
at the truth.

### Admitting one is an act on the walls

Adding a proxy to a scope sends that room's conversation to a third party. That is the same kind
of decision as mounting a Drive folder or binding a Telegram group — it moves the perimeter — so
it belongs to the **owner of the scope**, and the tier still governs: a proxy cannot sit in a
room above what its declared clearance carries, because the content flows to it by construction.

### Open

- **Can the router choose a proxy, or only a mention reach it?** Under R7 the semantic router
  picks by fitness among the agents of a scope. A third-party system selected by score, without
  anyone naming it, is a surprising place for a conversation to go. The narrower reading —
  *reachable only by explicit mention, never by semantic fallback* — matches what a proxy is, but
  it is a decision, not a deduction.
- **A proxy's message is untrusted content, and today it does not taint.** Measured on 11 Aug:
  the taint is marked by the **verbs** the gateway executes (`taint.note_verb`), so a message
  arriving from outside — a hook posts it as `kind: external` — leaves the channel clean. With
  proxies as a first-class kind this becomes the obvious injection vector: an outside system
  writes into the room, an agent reads it as ordinary conversation, and the context gate that
  fired five times that same afternoon on a *read of public issues* would not fire at all here.
  Either inbound messages of kind `external`/`proxy` taint, or the requirement should say
  explicitly why they do not.
- **Can a proxy's mention trigger a turn?** «Fare menzioni» reads as yes, and R2 makes a direct
  mention an unambiguous route. That means a third-party system can start work inside the colony.
  Probably right — it is the point of the seat — but it should be said, because it is also the
  moment a proxy stops being passive.
- **Whether a proxy has a seed at all.** Humans are spawns of `admin` and `member`; a bot has a
  seed with verbs, model and provider. A proxy has no model and no provider and two verbs. It may
  be a third fundamental seed rather than a field on the existing one — which is what A3's
  vocabulary would suggest.

### The proxy supersedes the hook, and the hook can go

> «il caso d'uso era quello di oggi, avresti potuto parlare con sysadmin senza usare il webhook,
> che di fatto potremmo abolire»

The webhook is already «a third-party system injecting a message into a scope». It is the same
thing as a proxy, minus the identity. Measured on 11 Aug, injecting into `SEAL-1/pof-comms`:

```
author     hook:pof-comms          ← a name that describes the pipe, not who spoke
kind       external
authority  untrusted
principal  null
auth       one shared bearer secret, per hook
effect     posts the message AND triggers a turn (_queue_turn)
taint      none — the room stays "clean" (see the open point above)
```

So today an outside party can **start work inside a room**, with no name attached, holding a
secret that is by construction copyable, and leave no mark on the room's contamination state.
Every one of those is fixed by giving the seat an identity: a proxy has a name in the
participants list, a cert instead of a shared secret, a tier that must carry the room, a presence
that says when it is not there, and an owner who admitted it and can revoke it.

That is why the proxy is not an addition next to the hook — it is the hook **done properly**, and
the hook becomes redundant for this use.

**What would be lost, and it is worth one sentence before deleting anything.** A hook needs no
identity at all: a CI job that posts a build result does not want a seat in a room, and asking it
to hold a certificate turns a two-line `curl` into an enrolment. The honest reading is that these
are two cases wearing one mechanism — *a party that converses* and *an event that is announced* —
and only the first is a proxy. If the second survives, it survives as something that can post and
**cannot trigger a turn**, which is the part that makes today's hook a way in rather than a
notification.
