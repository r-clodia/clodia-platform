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
