# Router notebook

> The record of what the **router** must be: each requirement as Davide dictated it, in the
> order it happened, with the measurement that confirmed or refuted it.
>
> This file is not the specification. When the picture is stable it folds into
> [`specification.md`](specification.md); what is missing goes to
> [`gap-analysis.md`](gap-analysis.md) and becomes issues. Kept separately, like
> [`decision-record.md`](decision-record.md), because the arguments that *lost* are worth
> more later than the conclusions that won — a lost argument is the one somebody
> reconstructs from scratch a month afterwards.
>
> **On the Italian.** The passages between «guillemets» are the owner's own words, in the
> language he said them. Translating them would replace what somebody said with a rendering
> of it, and the value of a record is that the ruling is quoted rather than summarised.

---

## R1 · What the router is

> «il router è un componente che in una conversazione analizza l'ultimo messaggio e
> stabilisce quale agente ai **o umano** lo deve trattare»

Four things are said here, and the fourth is new.

1. **It is a component**, not a behaviour scattered through the channel. Something one can
   name, test, and replace.
2. **It reads the last message.** Not the thread, not the topic's state: the last message.
3. **It decides who takes the turn** — one decision, one outcome.
4. **The outcome can be a human.** Not "an AI, or nobody": a *person* can be the one who
   has to handle it.

### Measured, 11 Aug 2026

Point 4 does not exist today, and its absence is structural rather than accidental.

- `_pick_responder` (`clodia-logic/server/api/channels.py`) considers only
  `s.type in ("super", "normal")` — that is, **AI agents only**. A human participant is not
  a candidate and cannot be returned.
- Consequently «route to a human» is expressed today as an **absence**: `_humans_tagged`
  detects that a person was named and the channel answers `{"posted": True, "responder":
  None}` — nobody takes the turn. That was dictated on 10 Aug and is correct as far as it
  goes: an AI must not answer in a person's place.
- But an absence carries nothing. There is no assignee, no state, no "waiting on Matteo",
  and nothing to notify — the Telegram relay works off *mentions*, which is a different
  mechanism that happens to overlap.

So R1 reframes a decision taken a day earlier. «Nessuna AI risponde» and «tocca a Matteo»
produce the same behaviour today and are not the same statement: the first is a silence,
the second is an assignment. Everything that a room might want to do with the second — show
it, chase it, escalate it when it goes unanswered — is impossible while it is modelled as
the first.

**Not yet asked, and deliberately not assumed:** whether an assignment to a human has a
state of its own (open/handled), whether it can be reassigned, and what happens when nobody
picks it up. Recorded here as open, not filled in with something plausible.

### Also measured, because it bears on "the last message"

`_routing_plan` today may **decompose** a message into several intents and route each one
separately (`_decompose_intents`), when `CHANNEL_MULTI_RESPONDER` is on. It is off by
default, and on 10 Aug the single-answer cap was made to hold on the relevance branch too.
R1 says «analizza l'ultimo messaggio» in the singular; whether one message may still
legitimately produce more than one assignment is not settled by R1, and is left open rather
than read into it.

---

## R2 · A direct mention is not a suggestion

> «se l'ultimo messaggio contiene una menzione diretta @agente il routing è diretto e non
> ambiguo verso l'agente menzionato»

Two words carry the requirement. **Diretto**: the mention *is* the decision — no scoring, no
ranking, no relevance. **Non ambiguo**: the outcome is knowable from the message alone,
before anything runs.

### Measured, 11 Aug 2026

The happy path holds. `_pick_responder` puts the tag first, and a `@nome` that names an
eligible participant is returned without consulting relevance or rank.

**But the decision is silently overridable, in two ways.**

1. **An ineligible tagged agent falls through.** The code reads
   `if tagged: t = next((s for s in ai if s.name == tagged), None); if t: return …` — and
   when `t` is `None` it *keeps going* into relevance routing. `ai` is filtered by
   eligibility (the agent's provider must carry SEAL ≥ the topic's tier). So naming
   `@minerva` in a room her provider cannot serve does not fail: **somebody else answers**,
   and nothing says why. That is precisely the complaint of 24 Jul — «la barra routing […]
   spesso indica un agente ma in realtà poi ne parte un'altro».
2. **A name that is not a participant behaves the same way.** Not a member, no target, fall
   through to relevance.

Both are the same shape: an **explicit instruction degraded into a hint** because the
preferred answer was unavailable. Silence is the wrong direction here — the person named a
specific agent for a reason, and the useful answer is «he cannot, and here is why», not a
different agent answering as though nothing happened.

### What R2 does not settle

- **Several `@` in one message.** Today the first tag wins and the others are dropped with a
  log line and a note on the routing bar (single-answer cap, 10 Aug). Whether R2's «non
  ambiguo» means *the first*, *all of them*, or *a refusal to guess* is not stated.
- **`$nome` (soft tag).** A second, weaker form of mention exists. R2 speaks of `@`; whether
  soft tags are also "direct" is not stated, and the current code treats them as targets of
  lower priority.
- **`@agente#N`** addresses one instance of a multi-spawn seed; unaffected by R2 as written.

### Tension with R1, recorded rather than resolved

R1 says the outcome may be a human. R2 says a direct mention routes to the mentioned agent.
Today `@matteo` (a person) produces *no* turn — an absence. Under R1 it should produce an
assignment to Matteo, and under R2 that assignment should be direct and unambiguous. The two
requirements agree; the code implements neither.

---

## R3 · Two mentions ask; three refuse

> «se vengono menzionati due agenti nello stesso messaggio il router apre un dialogo
> chiedendo come gestire: agente1 , agente2 , entrambi ... se vengono menzionati 3 o più
> agenti il dialogo informa che route con 3+ non sono supportate e il turno resta agli
> umani»

This settles the first open point of R2, and it settles it by **not deciding for the
person**. Two names are an ambiguity the router genuinely cannot resolve — «ask Aitiero and
Minerva» may mean *both*, or *whichever of you can*, and the message does not say which.
Guessing is what produces the "why did HE answer" that has now been reported twice.

Three thresholds, and each one is a different kind of answer:

| mentions | outcome |
|---|---|
| 1 | direct route (R2) |
| 2 | **a dialog**: agent1 · agent2 · both |
| 3+ | **a dialog that refuses**: not supported, the turn stays with the humans |

The refusal at 3+ is the part worth noticing. It is not "route to the best of the three":
it is a declared limit, said out loud, with the turn left where it already was. A limit that
announces itself is a different thing from a silent truncation — and today the code does
exactly the silent truncation.

### Measured, 11 Aug 2026

- **Today the first tag wins.** `targets` is built from all hard tags, then, with
  single-answer enforced, `targets = targets[:1]` and the rest become `dropped_tags`: a log
  line plus a note on the routing bar. Nobody is asked anything. With three names the
  behaviour is the same as with two — the first answers.
- **The dialog does not need to be invented.** The conversation already renders inline
  choice pills from an invisible marker in a message: `<!-- choices=A,B,C -->` (single) and
  `<!-- choices-multi=… -->`. It is used today by agents asking a question. The router can
  post the same marker; the webui already knows how to draw it and how to send the answer
  back.
- **`_multi_responder_enabled()` still exists** and is off by default. Under R3 "both" needs
  two turns from one message, so the capability stays — what changes is the trigger.

### Recorded as a deliberate reversal, not a contradiction

On 30 Jul: «rimuovere la possibilità che due agenti rispondano simultaneamente». On 10 Aug:
«deve essere solo uno». R3 allows two agents to answer the same message.

The two rulings are not in conflict once the trigger is named: what was removed is
**automatic** fan-out — the router deciding by itself that a message had several intents.
What R3 adds is fan-out **by explicit human choice**, on a question the human was asked.
Same outcome, different authority. The distinction must survive into the implementation, or
the guard that was put in place twice will be taken out a third time by accident.

### What R3 does not settle

- **Who sees the dialog, and who may answer it.** Any participant, or only the author of the
  message? If two people answer differently, which wins?
- **What happens meanwhile.** The message sits unrouted until somebody replies to the
  dialog: does it expire, and if so what then?
- **Mentions of humans mixed in.** `@aitiero @matteo` is two mentions but only one agent —
  under R1 a human is a possible assignee, so is this the two-way dialog, or the human rule
  of 10 Aug?
- **Soft tags (`$nome`)**, still unresolved from R2, now matter more: do they count towards
  the two/three thresholds?

---

## R4 · A mention of a person escalates by how present they are

> «se la menzione riguarda un umano, allora valgono i seguenti casi: umano presente nel
> topic (pallino verde) -> nessuna azione; umano presente nella webui ma in topic diverso
> (pallino giallo) -> toast box in basso a destra che lo avvisa della menzione con link di
> navigazione al topic e incremento del contatore di menzioni non viste nella sezione topic
> recenti della sidebar; umano loggato ma non attivo sulla webui (pallino blu) -> stessi
> segnali del caso precedente ma aggiunge blink della caption/favicon della tab del browser;
> caso umano off (pallino grigio) -> messaggio al suo telegram di contatto con avviso che è
> stato menzionato e link che naviga verso il topic, naturalmente questo assume che ogni
> umano abbia un telegram registrato nel profilo»

The escalation is **monotone**: each rung adds to the one below, and the ladder is climbed
only as far as the person's distance requires. Nothing is sent to somebody who is looking at
the message — the loudest signal goes to the person who cannot see anything at all.

| presence | signal |
|---|---|
| 🟢 here | nothing |
| 🟡 elsewhere in the webui | toast (bottom right, link to the topic) + unread counter in *recents* |
| 🔵 webui in the background | the same, plus the browser tab blinks (title/favicon) |
| ⚪ away | Telegram to their **profile contact**, with a link to the topic |

This is the first requirement that consumes the presence states as *input to a decision*
rather than as decoration — and it is the reason the four states had to exist before it.

### Measured, 11 Aug 2026

Most of the machinery exists; almost none of it is wired to a mention.

- **🟢 nothing** — already true, by a different route. The Telegram relay built on 10 Aug
  suppresses a notification when the person was present at the moment of the message
  (`_era_presente`). The rule agrees; the mechanism is narrower (see below).
- **🟡 toast** — a toast store exists (`toastSuccess/Error/Info`) and is used for outcomes of
  the user's own actions. Nothing today raises a toast for an event that arrives from
  elsewhere, and the SSE stream that would carry it (`channel_message`) is already consumed
  by the layout.
- **🟡 unread counter in recents** — exists: the sidebar renders an actionable badge from
  `GET /api/topics/signals`, whose count is *mentions not yet acked + gates pending*. So the
  counter R4 asks for is the one already there; what is missing is the toast beside it.
- **🔵 blinking tab** — does not exist in any form. Title and favicon are set once from the
  branding.
- **⚪ Telegram to the profile contact** — the *capability* exists and is used elsewhere:
  `_gate_notify_principal` reads `contact_channels.telegram` from the person's agent card
  and sends. **But the mention path does not use it.** The relay of 10 Aug requires the
  TOPIC to have a bound Telegram group and a handle map inside that mount; it delivers into
  the group, not to the person. Under R4 the recipient is the person's own contact, which
  works for a topic with no group at all.

**So R4 and the 10 Aug relay are two different features that look alike.** One notifies a
*room's group* (Messaggero relays into a shared channel, `excerpt` mode, handle
translation); the other notifies a *person* wherever they are. Keeping both means deciding
whether an absent person mentioned in a room with a bound group gets one message or two —
recorded as open below rather than assumed.

### The assumption R4 states, and what it implies

«questo assume che ogni umano abbia un telegram registrato nel profilo». Today that is not
enforced anywhere: `contact_channels.telegram` is optional. A person without it is, under
R4, unreachable at the last rung — and the ladder would end in silence exactly where it is
supposed to be loudest. What the system does then (refuse to create the human, warn the
owner, fall back to e-mail, or simply drop) is not stated.

### What R4 does not settle

- **One message or two** when the room also has a bound Telegram group (above).
- **What "not seen" means for the counter.** The badge already counts un-acked mentions; R4
  reuses the same word without saying whether the two are the same set.
- **Whether the ladder re-fires.** If a person stays away for an hour and is mentioned six
  times, is that six Telegram messages?
- **The blink's end condition** — until the tab is focused, or until the mention is read?

### R4 · clarifications (11 Aug 2026)

> «menzioni ripetute non provocano messaggi di notifica ripetuti nella finestra temporale di
> 10 minuti a partire dalla prima notifica. Notifiche non viste significa che l'umano non ha
> riaperto la pagina del topic, il blink continua indefinito finche o l'umano naviga nella
> tab o la tab viene chiusa»

Three of the four open points of R4 are settled, and the shape that emerges is worth naming:
**the three signals have three different end conditions**, and each one matches what that
signal is *for*.

| signal | ends when | because |
|---|---|---|
| Telegram | 10 minutes after the first | it is an interruption; repeating it is what teaches people to mute a channel |
| counter in *recents* | the person reopens the topic | it is a debt: it stays until the thing is actually seen |
| tab blink | the tab is focused, or closed | it is an attention-grab: once it has attention, it has done its job |

The blink deliberately stops **before** the mention is read. It ends on focus even if the
person then goes somewhere else in the webui — because at that point the counter carries the
rest. Two signals, two jobs, no overlap: one gets you to look, the other remembers what you
still owe.

**The window is per person, not per message.** «a partire dalla prima notifica» measures
from the moment somebody was told — so ten mentions in nine minutes produce one Telegram.
The eleventh, after eleven minutes, produces another.

### Measured

- **The 10-minute window does not exist.** The queue built on 10 Aug dedups per *message*
  («una menzione notifica una volta»), which is a different guarantee: it prevents the same
  mention going twice, not five distinct mentions in five minutes. Under R5 that queue is
  going away anyway; the window is a property of the new per-person path.
- **"Non viste" nearly matches today's ack, but not exactly.** The counter is decremented by
  `ackMentions(tier, name, last.ts)`, which fires when the topic is open **and the view is
  near the bottom** — i.e. the message has actually scrolled into sight. R4's definition is
  «non ha riaperto la pagina del topic», which is satisfied by opening it. The stricter
  behaviour is the one already shipped; whether to relax it to «opened» or keep «opened and
  reached» is a real choice, recorded rather than resolved. Keeping the stricter one means a
  person who opens a busy topic and does not scroll still owes the mention.
- **The blink does not exist**, so it has no end condition to correct — it is built to the
  rule as stated: `visibilitychange` → stop; page unload → moot.

### Still open in R4

Only one of the original four remains: **whether a person without `contact_channels.telegram`
is refused, warned, or silently unreachable** at the last rung.

---

---

## R5 · The group relay is abolished

> «aggiungo che il meccanismo preesistente che segnala via telegram tramite messaggero e
> verso un gruppo telegram collegato al topic è abolito»

This settles the first open question of R4 — one message or two — by removing one of the
two. A mention of a person is delivered **to that person**, on their own contact, and never
into a room's shared group.

### Why this is coherent rather than a change of mind

The two mechanisms answer different questions, and only one of them is the router's.

- The group relay answers «how does this room reach the outside?» — a property of the
  **room**: a bound group, an authorised egress, a handle map, an excerpt policy.
- R4 answers «how do we reach this person?» — a property of the **person**: their contact,
  wherever they are, in whatever room.

A mention is about a person. Routing it through a property of the room made the delivery
depend on something unrelated to the recipient: with no bound group, an absent person got
nothing; in a room with a group, the notice went to everyone in it, including people who are
not on the platform at all.

### The consequence, stated because it is a real loss

The group relay reached **people in the group who are not registered humans**. R4 reaches
only registered humans with a profile Telegram. Abolishing it therefore narrows the
audience, deliberately: whoever is not a participant of the room is no longer told that
somebody was mentioned in it — which is, on reflection, what a compartment means.

If a room ever needs to speak to an outside group again, that is an *outward* feature with
its own name and its own gate, not a side effect of somebody typing `@matteo`.

### Measured, 11 Aug 2026 — what this makes dead

Built on 10 Aug, now without a purpose:

- `clodia-tools/server/topics/telegram_notify.py` — 316 lines: queue, `enqueue_for_message`,
  `render()`, presence check, retry with cap.
- 21 references in the gateway to `telegram_bind` / `telegram_unbind` / `telegram_mounts`,
  plus the `telegram` mount kind, the gate classes for those two verbs, and the
  `telegram.notify_flush` entry in the logic-job allowlist.
- 5 references in clodia-logic (the relay job, the client).
- 14 in the webui: the whole «Telegram» section of the topic sidebar — chat id, mode
  (`notify`/`excerpt`), the handle↔username map.

**Not to be deleted blindly.** `telegram.listen`/`unlisten` and the messenger's own
capability are a different feature (a person talking to Clodia over Telegram, 18 Jul) and
are not in scope here. The removal must be scoped to the *mention relay into a room's
group*, and the boundary between the two runs through the same files.

### What R5 does not settle

- **Existing bindings.** One room on venere (`SEAL-2/uncommon-digital-casa`) has a bound
  group with a people map. Removal has to decide between dropping it silently and telling
  the owner it is gone.
- **Whether the `telegram` mount kind survives** for any other purpose, or goes with it.

## R6 · Semantic routing is the fallback, not the default path

> «ora veniamo al routing semantico, questo si attiva in mancanza di menzioni dirette»

Stated as a **precedence**: mentions decide; semantics only runs when nothing was named.
Consistent with R2 (a mention *is* the decision) and R3 (two mentions ask rather than guess)
— the semantic router never overrules a person who said a name.

### Measured, 11 Aug 2026 — what exists today

The order is already right. `_pick_responder` tries the tag first and reaches relevance only
with `tagged=None`. What follows is the state of the machinery R6 is about, so the
requirements that come next land on facts rather than on the docstring.

**How it decides.** `responder_routing.py`: the message is embedded (multilingual-e5-small,
via the local `/embed` micro-service), each candidate's *profile* is embedded once and
cached, and the best cosine wins **if** it clears two bars:

- `THRESHOLD = 0.80` — an absolute floor of pertinence;
- `MARGIN = 0.015` — it must beat the runner-up by that much, otherwise the answer is
  «nobody clearly» and the pick is abandoned.

That second bar is the interesting one: a near-tie is treated as *no decision*, not as a
coin toss.

**Who is a candidate.** Only eligible agents (`type` super|normal, provider SEAL ≥ tier),
and among them only those whose `routing_mode` allows automatic routing — an agent may
declare `state_writer_only` and be reachable **only** by explicit mention. So a form of «do
not route to me by guessing» already exists at seed level.

**Where it lands when it fails.** Three distinct failure paths, all ending in the same
place — the highest-ranked eligible agent, in practice the super-agent (Clodia):

1. no specialist over threshold;
2. a tie inside the margin;
3. **the embedding service unreachable** — `embed_text` returns `None` and the caller falls
   back to rank «nessuna dipendenza dura».

The third deserves naming: when the semantic router is *down*, routing silently becomes
"the super-agent answers everything". It works, which is exactly why nobody notices; and it
is indistinguishable, from the outside, from a message that genuinely matched nobody.

**Two mechanisms not yet consequential.** `soft_matches` (a lower threshold, 0.87×) exists
for the multi-responder fallback, which is off. An *exemplar* classifier (learning from
confirmations and corrections, `EXEMPLAR_MARGIN`) runs in **shadow mode**: it records what it
would have chosen and changes nothing.

### Prior complaint on record

24 Jul: «Anche il routing lascia spesso a desiderare, serve una selezione semantica più
forte. Usiamo embeddings più accurati». The model was changed afterwards
(MiniLM-paraphrase → multilingual-e5-small with query/passage prefixes) and the thresholds
were re-based on it, with the comment stating they are «valori di partenza, da rifinire con
l'osservazione». Whether that observation ever happened is not recorded anywhere — noted
because R6's next requirements may rest on it.

---

## R7 · What the semantic router compares, and against what

> «il router semantico analizza gli ultimi N-messaggi e poi attraverso un modello di
> embeddigs li confronta con le skill e descrizioni degli agent e esegue una classificazione
> selezionando l'agent più adatto»

Three parts, and they are in three different states: one already built as described, one
absent, one built more finely than the sentence suggests.

### The agent side is already this — and more

`_profile_pieces` does not embed one blob per agent. It cuts the agent into **sharp pieces**
and scores the agent as the **maximum** cosine over them:

- each clause of its `expertise` (split on `; , . \n`, ≥4 chars);
- **each skill**, with pack wildcards (`pack/*`) expanded into the real skill names — without
  that expansion an agent installed from a pack keeps only the wildcard and loses precisely
  its sharpest domain signals (measured then: a commercialista with only the wildcard scored
  0.08 on «bilancio provvisorio», against 0.80 from the skill slugs);
- the **titles of its RAG documents**, per collection;
- `description` **only as a last resort**, when nothing above yields a usable piece.

Max-over-pieces rather than one average vector is the design decision that matters here: a
broad profile no longer dilutes its own peaks, so one precise skill wins when it is
pertinent and stays quiet otherwise.

Two filters are already in place and worth keeping in view: pieces shorter than 8 chars or
of a single word are discarded as noise (an acronym like «AGA» embedded alone matched «ciao
come va» at 0.61), and `base-pack`/`logic` skills are excluded because every agent has them
— a signal everyone shares discriminates nobody.

So «skill e descrizioni» is satisfied, with the nuance that `description` is the *fallback*,
not the primary signal. If R7 means the description should carry more weight, that is a
change and not a confirmation.

### The message side is not this

`score_specialists(specialists, message)` embeds **one** string: the message just posted.
There is no window, no N, no history. R7's «ultimi N-messaggi» does not exist.

This also **amends R1**, which said «analizza l'ultimo messaggio». The two are compatible
once the roles are separated: the last message is what *triggers* the router; the last N are
the *evidence* it reasons on. Recorded as an amendment rather than a contradiction — but the
distinction has to be explicit in the specification, or somebody will implement one of the
two sentences and believe they implemented both.

### What R7 does not settle

- **N.** A number, or a time window, or "since the last routing decision"?
- **How the N are combined**: one embedding of the concatenation, N embeddings averaged, or
  N scored separately with a decay by age? These give different answers on a conversation
  that changes subject, which is the case the window exists for.
- **Whose messages count.** Only the humans', or also the agents' replies? An agent's own
  answer in the window would bias the next choice toward itself — the failure mode where
  whoever spoke last keeps being chosen.
- **«classificazione»**: today the decision is a ranking with two bars (threshold and
  margin) and an explicit *no decision* when they are not cleared. A classifier that always
  emits a class would remove that abstention, which is the mechanism that currently prevents
  coin-toss routing on near-ties.

### R7 · clarifications (11 Aug 2026)

> «direi gli ultimi 3 messaggi inclusi quelli degli agenti. Tale parametro N=3 dovrà essere
> nel config del router e modificabile senza ribuildare il codice»

**N = 3, agents included.** The window is the conversation, not the human turn.

**The bias this accepts, named once.** Including the agents' own replies means the last
speaker's vocabulary is part of the evidence for choosing the next speaker — which pulls
towards *whoever answered last keeps answering*. It is a real effect and it was chosen
knowingly: three messages is also how a person reads a thread, and excluding the agents
would make the router judge a question stripped of the answer it follows. Recorded so that,
if routing ever appears to «stick» to one agent, this is the first thing to measure rather
than the first thing to be surprised by.

**Configurable without a rebuild** is a requirement about *where the knob lives*, and today
the router has this backwards.

- Every threshold in `responder_routing.py` — `THRESHOLD`, `MARGIN`,
  `FALLBACK_SOFT_RATIO`, the exemplar margins: **eleven** `os.environ.get(...)` read at
  **import time**. Changing one means editing `.env` and recreating the container. Worse on
  these instances, where the entrypoint re-clones from GitHub at every boot: a value tried
  by hand does not survive.
- The one knob that *is* a live file — `topics_defaults.responder_routing` (relevance vs
  rank), read from `profile.yaml` in the datadir through `instance_profile.load()` — proves
  the mechanism already exists and is simply not used by the rest.

So R7's `N` should not be born as a twelfth environment variable. It belongs to a **router
config in the instance profile**, alongside the mode that is already there, read live. That
also gives the thresholds a home: `THRESHOLD` and `MARGIN` were left as «valori di partenza,
da rifinire con l'osservazione» (§R6) and observation is impossible while every adjustment
costs a container recreate.

This connects to an open platform item, *D1 — configuration as live files*, which is
pending. R7 makes the router the first concrete consumer of it.

### Consequence for the earlier fix of 7 Aug

`RESPONDER_FALLBACK_SOFT_RATIO=1.0` was set **in `.env` on the instances**, by hand, to kill
the multi-match fallback after two agents answered a single message. That value lives
exactly where R7 says configuration should not live: it is invisible from the webui, absent
from the repository, and a fresh clone of the platform does not have it. Whatever the router
config becomes, that ratio has to move into it — or the next instance will reproduce the
7 Aug defect out of the box.

---

## R8 · Ambiguity is a question, and the answer is remembered

> «la selezione dell'agente da parte del router deve avvenire tramite dei punteggi di
> fitness, entro una certa tolleranza punteggi simili significano ambiguità, in quel caso il
> router apre un dialogo in chat con le pills per far scegliere all'umano. Tale scelta viene
> conservata in uno storage speciale del router che sarà usato come primo riferimento per
> successivi route actions»

Three claims. Two of them describe something that **already exists and is switched off**;
the middle one is the change.

### Fitness scores and tolerance — built

Scores are cosine similarities, max over the agent's profile pieces (§R7). The tolerance is
`MARGIN = 0.015`: when the winner does not beat the runner-up by that much, `decide()`
returns `None`. The concept R8 asks for is in place, under a different name.

### What ambiguity does today — the change

Today an ambiguity **falls silently to rank**: the super-agent answers. Nobody is asked, and
nothing distinguishes «two specialists were equally plausible» from «nobody matched at all»
— both look like Clodia answering.

R8 makes ambiguity **a question**, with the same pills mechanism as R3. This is the same
shape as R3 twice over: *when the router genuinely cannot tell, it asks instead of guessing*,
and the fallback to rank stops being used to paper over a decision that was never made.

### The «storage speciale» already exists — and is inert

`server/api/routing_feedback.py`, writing `<CLODIA_DATA>/routing/corrections.jsonl`:

- stores **the embedding of the message, never its text**, plus the correct target, the kind
  of signal (`confirm` / `correction`), tier, topic and who gave it;
- `responder_routing.pick_by_exemplar` reads it as a k-NN vote (`EXEMPLAR_K = 5`) with
  corrections weighted above confirmations, temporal decay (half-life 90 days), a relative
  margin and an absolute floor (0.80) added after measuring that a winner with no rival has
  margin 1.0 whatever its similarity — six out of eight out-of-domain phrases were being
  routed before the floor;
- it is consulted **before** relevance in `_pick_responder` — exactly the «primo riferimento
  per successivi route actions» R8 asks for;
- and it is in **shadow mode by default**: it computes and records the decision it would
  have taken, and does not apply it. The docstring says why — leave-one-out accuracy is
  21–30% on 39 votes over 9 agents, and «applicarla peggiorerebbe il routing». Switching to
  `enforce` is described as an explicit decision to take once `GET /clodia/routing/stats`
  shows adequate accuracy, indicatively ≥70%.

So R8 does not need a new store; it needs **the store to be fed by something better**. And
that is precisely what R8 supplies: today the exemplars come from ad-hoc confirmations and
corrections — a sparse, noisy, voluntary signal. Under R8 every ambiguity produces a
question, and every answer is a labelled example, at the exact moment the router did not
know. That is the highest-quality training signal available and it is generated by the
mechanism itself.

**The 21–30% accuracy is therefore not an argument against R8 — it is an argument for it.**
It measures a store fed by whoever happened to bother; R8 feeds it from the cases that
matter.

### What R8 does not settle

- **When the remembered choice stops being «primo riferimento».** A stored preference that
  always wins is indistinguishable from a hard rule, and a conversation changes subject. The
  floor and margin exist today for this; whether R8's storage keeps them is not stated.
- **Scope of a memory**: does a choice made in one topic apply to another? The record already
  carries `topic` and `tier`, so both are possible.
- **Whether an ambiguity dialog can also be answered «neither»** — and what happens then.
- **Whether the shadow→enforce switch stays a manual decision**, or whether R8 implies the
  store is authoritative from the first answer.

---

## R9 · The human may overrule a confident router, and the turn restarts

> «quando il router decide e non ha dubbi comunque l'umano deve poter aprire la routing box
> ed esprimere "come avrebbe scelto lui". In questo caso il turno dell'agent scelto dal
> router viene interrotto e parte il turno nuovo dell'agent segnalato dall'umano. Anche in
> questo caso la scelta dell'umano viene inserita nello storage speciale di routing»

R8 covered the case where the router *doubts*. R9 covers the case where it does not — and it
is the more important of the two, because a router that only listens when it is unsure never
learns where it is confidently wrong.

### Measured, 11 Aug 2026 — three pieces, all built, none connected

1. **The routing box exists, and it already asks the question.** The 🧭 bar in the
   conversation expands into per-candidate scores with threshold and margin, and carries a
   corrector: `POST /clodia/routing/correct` takes `correct_agent`, re-embeds the last
   *human* message, and calls `record_correction` into the same store as R8. The webui shows
   «✓ imparato: i messaggi simili andranno a X».
2. **Interrupting a turn exists.** `POST /clodia/channels/{tier}/{name}/interrupt` cancels
   the running turn of every responder of that channel (`_require_contributor`), leaving the
   human message in place.
3. **Starting a turn for a named agent exists** — it is the direct-mention path of R2.

So R9 asks for a **sequence**, not for new capability: correct → interrupt → re-route →
record. Today the correction teaches the store for *next time* and lets the wrong agent
finish talking; the human then has to interrupt by hand and re-ask with a mention.

### The prompt on record

24 Jul: «invece del voto up/down io apro il componente routing e seleziono quello che avrei
usato io come agent, così acquisisci un informazione più accurata per i prossimi routing».
That is where the corrector came from. R9 extends the same idea from *learning* to *acting*:
the correction now also fixes the present, not only the future.

### Where this needs care

- **The correction re-embeds «the last human message».** Under R7 the router will decide on
  a window of three messages including the agents'. If the correction keeps learning from
  one message while the router decides on three, the store teaches something the router does
  not consume — a mismatch invisible in both places.
- **Interrupting is not free.** The interrupted agent may have already spoken, called tools,
  or written to the topic. What the conversation shows afterwards — a truncated bubble, a
  note, nothing — is not stated, and «il turno viene interrotto» hides a real question: a
  turn that already sent an email cannot be un-sent.
- **The signal is stronger than a correction of an ambiguity.** In R8 the human breaks a
  tie; here the human contradicts a confident router. Recording both with the same weight
  would waste the difference — the store already distinguishes `confirm` from `correction`
  and weights them differently.

### What R9 does not settle

- **Who may overrule.** The corrector is `_require_contributor` today; readers are excluded.
- **Whether an overrule is possible after the turn has finished** — a late «you should have
  asked X» that only teaches, with nothing to interrupt.
- **What the overruled agent is told**, if anything. Silence risks it resuming; a message
  costs a turn.
