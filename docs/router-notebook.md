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

## Gap analysis → issue, 12 ago 2026

Ogni requisito è stato misurato contro il codice mentre veniva dettato: le sezioni
«Measured» qui sotto **sono** la gap analysis. Il 12 ago sono state trasformate in
issue di remediation su `r-clodia/clodia-platform`:

| R | issue | il divario, in una riga |
|---|---|---|
| R1 | [#181](https://github.com/r-clodia/clodia-platform/issues/181) | instradare a una persona è un'assenza, e un'assenza non porta stato |
| R2 | [#182](https://github.com/r-clodia/clodia-platform/issues/182) | una menzione che non si può servire scivola, e risponde un altro |
| R3 | [#183](https://github.com/r-clodia/clodia-platform/issues/183) | due menzioni devono chiedere, tre rifiutare: oggi vince la prima |
| R4 | [#184](https://github.com/r-clodia/clodia-platform/issues/184) | mancano toast, blink e il canale personale; il contatore c'è |
| R6·R7 | [#185](https://github.com/r-clodia/clodia-platform/issues/185) | N, soglia e margine sono costanti nel sorgente |
| R8 | [#186](https://github.com/r-clodia/clodia-platform/issues/186) | l'ambiguità abbandona la scelta invece di chiedere |
| R9 | [#187](https://github.com/r-clodia/clodia-platform/issues/187) | i tre pezzi ci sono, la sequenza no |
| R10 | [#188](https://github.com/r-clodia/clodia-platform/issues/188) | nessun coordinatore dichiarato, e il ripiego risponde invece di decidere |
| R12 | [#189](https://github.com/r-clodia/clodia-platform/issues/189) | `$nome` non è ancora inerte |
| R14 | [#190](https://github.com/r-clodia/clodia-platform/issues/190) | l'ineleggibilità è un filtro di vista, non un'appartenenza |
| R15 | [#191](https://github.com/r-clodia/clodia-platform/issues/191) | «coda» e «rifiuto» non esistono; «parallelo» è multi-spawn |

**R5, R11 e R13 non producono issue**, e per ragioni diverse: R5 è stato revocato
lo stesso giorno e ciò che descrive è vivo e misurato funzionante; R11 constata che
gli scope asincroni hanno un agente solo, quindi l'ambiguità non si pone; R13 è
accettato come è.

I punti «To decide first» dentro ogni issue sono le domande aperte del notebook,
portate dove servono: chi implementa le trova nella issue invece di doverle
ricostruire da qui.

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

## R3 · One mention per message; a second one is asked back to whoever wrote it

> «Nuova regola 1 messaggio max 1 menzione. Un messaggio con due menzioni chiede
> conferma. Se l'ha generato un agente A che menziona sia B che C, allora viene chiesta
> conferma all'agente A con una menzione diretta (chi intendevi attivare? B o C)»
>                                                                — Davide, 17 Aug 2026

The norm comes first and it is the whole rule: **a message carries at most one mention
that starts a turn.** Everything below is what happens when it does not.

A second mention is not resolved by the router and not resolved by whoever happens to be
in the room. It is **asked back to the author of the message**, because the author is the
only party that knows what they meant — and this is the part the previous version got
wrong, not the counting.

| author of the message | two or more mentions |
|---|---|
| a human | a dialog in the channel: the named agents as choices |
| an **agent** | a **direct mention back to that agent**: «you mentioned @B and @C: which did you mean to start?» |

### Why the previous rule created confusion

R3 used to say *two mentions ask, three refuse*, and both halves misfired in practice.

**The dialog asked the room, not the author.** When an agent wrote the ambiguous message,
the router posted choice pills addressed to the humans. Nobody was expecting a question:
the pills sat there, the turn never started, and the channel looked stalled rather than
waiting. The one participant who could answer instantly — the agent that had just written
both names — was the one not being asked.

**Two thresholds with two different outcomes.** Two names opened a dialog, three printed a
refusal and dropped the turn. Nothing about three names makes the question harder to ask:
«which of B, C, D did you mean» is exactly as well posed as with two. The extra threshold
bought no safety and had to be remembered.

So the fix is not a new count. It is **asking the right party**, and once the question goes
to the author the special case at three disappears with it.

### What this removes, deliberately

**`both` is gone.** It was the one path by which a single message could still start two
turns — fan-out by explicit human choice. Under «max 1 menzione» a message activates one
agent, and offering *both* would be offering to break the rule the same sentence
establishes. Two agents on the same subject remain possible: two messages.

This is the third time fan-out has been narrowed (30 Jul: no simultaneous answers ·
10 Aug: «deve essere solo uno» · today: not even by choice). Recording it here so the
guard is not removed a fourth time by accident, believing it a regression.

**The turn is no longer dropped.** The refusal at 3+ left the message unrouted with a
notice. Now every ambiguous message gets a question, and the question is addressed to
somebody who can answer it.

### What counts as a mention

Only mentions that **would start a turn**: hard tags (`@nome`) resolving to an eligible
agent in this channel. A mention of a person follows R4 — it notifies, it does not route —
and an unserviceable tag was never a target. Soft tags (`$nome`) do not count, as before:
they are a suggestion, and a suggestion cannot make a message ambiguous.

A seed mentioning **itself** alongside another agent is genuinely ambiguous — A12 says a
self-mention forks a new instance, so `@A @B` from `A#1` may mean *fork me* or *hand it to
B*. It gets the same question as any other pair.

### Asked once, never twice

The answer to the question is an ordinary message, so it goes through the ordinary routing —
which means it could be ambiguous too. Two agents could then trade questions at token cost
without anybody noticing, which is the failure mode this design must not open.

So the question is asked **once per chain**. If the reply is ambiguous again, no turn starts
and a system message says so. A stopped turn that declares itself is recoverable; a loop
between two agents is not.

### Still not settled

- **Who may answer a human-authored dialog.** The author, as today (`routing-request` binds
  the dialog to them), and the constraint carries over unchanged.
- **What happens meanwhile.** The message waits. It does not expire, and an unanswered
  question is visible in the channel rather than silent — but nothing reminds anybody.
- **A mixed pair `@agent @person`.** One mention starts a turn, the other notifies: one
  routing mention, so the norm holds and no question is asked.
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

## R5 · The group relay is abolished — REVERSED on 12 Aug, it stays

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

### ⟲ Reversed, 12 Aug 2026 — the relay stays

> «se non sbaglio in roadmap abbiamo deciso di abolire questa notifica da canale a gruppo
> telegram, invece direi di tenerla. Sembra funzionare» · «quando avviene una notifica dal topic
> a gruppo telegram a seguito di menzione, sarebbe utile che anche un excerpt del messaggio
> venisse mostrato, per esempio 120 caratteri troncati da ... e poi link per navigare sul canale»

R5 is withdrawn. The group relay is **kept**, and everything the section above lists as «what
this makes dead» is alive: the queue, `enqueue_for_message`, `render()`, the presence check, the
`telegram` mount kind, the bind verbs, the sidebar section.

The reasoning of R5 is not wrong — a mention is about a person, and the relay routes it through a
property of the room — but it was decided before the thing had been seen working. **Measured on
venere, 12 Aug: 14 notifications in the queue, 14 with `delivered_at`, none with an error.** It
works, and a room whose people already talk in a Telegram group is served by it in a way R4's
per-person channel does not replace: it reaches people in the group who are not registered
humans on the platform, which R5 listed as the deliberate loss.

So the two coexist. R4 answers «how do we reach this person», R5 «how does this room reach the
group it already lives in», and neither is the other's fallback.

### What the notification carries

Three parts, and all three were already implemented — only the length changes:

```
🔔 @giocasu75 — davide ti ha menzionato in «Proof-of-flex solo esecuzione»
“@giovanni puoi guardare il deck prima di giovedì? mi serve una revisione sulla parte tec…”
https://venere.tail368c4c.ts.net:8443/topics/SEAL-1/proof-of-flex-2#m-20260812-073710-Jgq4xg
```

- **The translated handle.** `@giovanni` in the room is `@giocasu75` in the group — writing the
  platform name would notify nobody there.
- **The excerpt: the LINE of the mention, not the message**, truncated at **120** characters with
  `…`. It was 280. The notification is read on a phone, among other notifications, and its job is
  to make someone decide whether to open the conversation — not to replace it. Past a couple of
  lines it stops being a preview and becomes a partial copy of the message living outside its
  scope, which is the thing an excerpt exists to avoid. The ellipsis is not cosmetic: an excerpt
  cut without saying so reads as a finished message, and nobody opens the room.
- **The link, to the message.** `#m-<id>` is consumed by the topic page; if the anchor ever
  disappeared the link still lands on the topic — losing precision, not the destination.

A mount can still ask for `mode: notify`, which carries no content at all: a room where even one
line is too much keeps the notice and drops the preview.

### Open

- **Whether 120 is a constant or a per-mount setting.** It is a constant today. A room with a
  stricter posture already has `mode: notify` to fall back on, so the middle ground — «an
  excerpt, but shorter here» — has no case behind it yet, and a setting invented before its case
  is a setting nobody sets.
- **The queue never empties.** A delivered notification stays in the file with
  `attempts = MAX_ATTEMPTS` and a `delivered_at`, deliberately, so that «that person was told»
  stays readable. But nothing prunes it, and the same field means *delivered* and *given up on* —
  the discriminator is `delivered_at` vs `last_error`. It cost a wrong reading during this very
  measurement: 14 items at maximum attempts look like 14 failures until the two fields are
  compared.

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

---

# Answers to the six gaps raised on 11 Aug 2026

Asked whether requirements were missing, six were raised and all six were answered. They are
recorded as requirements in their own right, because each one decides something the previous
nine left undecided.

## R10 · When the router cannot choose, an *intelligent* agent chooses

> «quando il router non sa chi scegliere il fallback è l'agent coordinatore che normalmente è
> clodia, il quale dunque farà la classificazione usando la sua conoscenza del contesto e si
> suppone sarà migliore e più accurata della selezione del router semantico, in parole povere
> se il router semantico non sceglie allora la scelta ricade su un agent 'intelligente'. Non
> sempre clodia è presente in uno scope, in assenza di clodia l'agente coordinatore potrebbe
> essere il segretario»

The fallback is not «the strongest agent answers»: it is **a second routing stage, performed
by a model instead of by cosines**. The coordinator classifies with what an embedding cannot
have — the context of the room. That reframes the whole design: the semantic router is a
*cheap first pass*, and its abstention is a **handover**, not a defeat.

### Measured — the difference is bigger than it looks

- Today the fallback is `rank_mod.highest(ai)` with reason `fallback-rank`: the
  highest-ranked eligible agent **answers the message**. It does not classify and it does not
  delegate. So today's fallback produces an *answer by the coordinator*, whereas R10 asks for
  a *decision by the coordinator*, which may well be «this is for Aitiero».
- There is **no declared «coordinator»** anywhere. The word appears in `suggest_team`, where
  `coordinator = supers[0].name` — the first super-agent — and in a bootstrap prompt. So
  «normalmente clodia» is true only as a side effect of Clodia being the highest-ranked super
  in most rooms. Change a rank, or build a room without her, and the fallback moves silently.
- `segretario` is a `normal` seed, not a super. Under today's rule it would be chosen only if
  it happened to outrank everyone eligible. So «in assenza di clodia il coordinatore potrebbe
  essere il segretario» **cannot** be expressed today: the role has to become a declared
  thing (per instance, or per scope) rather than a by-product of ranking.

### What R10 leaves open

- **Who declares the coordinator** — the instance profile, or the topic? A per-topic
  coordinator would let a specialised room name its own.
- **What the coordinator returns.** A name (and the router starts that agent's turn), or an
  answer plus an optional handover? The two produce different conversations: one bubble or
  two.
- **What if the coordinator is not a participant either.** No super, no secretary: no turn,
  or the highest rank as today?

## R11 · Async scopes have one agent, so this ambiguity cannot arise

> «negli scope asincroni (job) c'è un solo agent assegnato. I job con multipli agents non
> sono ancora previsti»

This closes the deadlock I raised: an ambiguity dialog with nobody to answer it cannot happen
in a job, because a job never routes — its agent is assigned when the job is defined.

**The residual case is different and is not a deadlock.** A channel turn can still be
triggered with no human watching (`POST /clodia/channels/{tier}/{name}/trigger`, «nessun
principal», used when the gateway injects a message into a room). There an ambiguity dialog
waits — but waiting is the correct behaviour, and R4's escalation ladder is precisely what
makes the wait visible to whoever should answer it. Recorded so the distinction is not
re-litigated: *jobs never ask; unattended channels ask and wait*.

## R12 · Agents may summon agents, but only to cooperate — and `$` never activates

> «gli agent possono menzionare altri agent, questo è corretto, ma deve succedere solo se un
> agent ritiene che l'obiettivo possa essere raggiunto solo con la cooperazione di un altro
> agent, le menzioni sterili e di riconoscimento tipo 'concordo con @avvocato' devono essere
> evitate. Possono essere usate soft-mentions $agente, le quali non devono attivare l'agente
> menzionato ma al massimo possono essere usate dal router semantico come elemento di tie
> break quando due agenti fittano con lo stesso punteggio»

Two rules of different kinds, and the difference matters for where each is enforced.

**`$` must not activate — enforceable, and today it is violated.** Measured: `for nm in soft:
… targets.append((s, "soft", …))` — a soft tag builds a target exactly like a hard one, only
at lower priority. So `$avvocato` starts a turn today. R12 makes `$` a **signal, not a
summons**, with a precise new job: breaking a tie inside the margin (§R8) — which is elegant,
because it turns the citation into evidence at the one moment the router has none.

**«Menzioni sterili» is not enforceable by the router.** Nothing can distinguish «concordo
con @avvocato» from a genuine hand-off by inspecting the text — sincerity is not a property
of a string. This belongs in the agents' instructions (system prompt / rules), not in the
routing code, and saying so is the difference between a rule that holds and a rule that looks
like it does. What the router *can* do is make the sterile case harmless: with `$` inert, an
agent that wants to acknowledge a colleague has a form that costs nobody a turn.

### Open

- Whether `@` from an agent needs a stated justification (a reason recorded with the hop), or
  whether the prompt rule suffices.
- Whether the tie-break from `$` is a bonus on the score or an outright override.

## R13 · A degraded router says so — accepted

> «ok»

The embedder being unreachable must not look like a decision. Today `embed_text` returns
`None`, routing falls to rank, and the routing box says «Nessun punteggio disponibile (tag
esplicito o embedder non raggiungibile)» — one sentence for two causes that are not the same
thing at all: one is a person naming an agent, the other is a broken component.

## R14 · Ineligible agents are not in the scope at all

> «la selezione del router avviene solo per gli agenti abilitati ad uno scope, agenti senza
> la dovuta clearance non sono mai nello scope»

An invariant, not a filter — and much stronger than what exists.

### Measured — today they *are* in the scope, and hidden

Eligibility is computed **at routing time** (`_provider_seal_ok`) and again for display: the
channel exposes `eligible: false` per participant, and the webui drops them from the list
(`shownParticipants`). So an ineligible agent is a participant that the interface pretends is
not there. Under R14 it should never have been added, or should be removed when the room's
tier rises above its provider's SEAL.

That turns a routing detail into a **membership rule**, enforced at two moments: adding a
participant, and changing a tier. It also dissolves gap #5 as I posed it — there is no «best
candidate silently excluded», because a candidate that cannot serve the room is not in the
room.

### Observed, 11 Aug 2026 — what R14's absence looks like

Reported live: «non riesco ad aggiungere segretario ai canali, e nel canale
uncommon-digital-casa sono spariti tutti gli agent, restano solo gli umani». Cause: the
providers had been paused.

The symptom is worth keeping because it is the shape of the defect R14 removes. A paused
provider makes every agent ineligible; the webui hides the ineligible; so a room appears to
have **no agents at all**, and the humans remain only because they have no provider to judge.
Nothing says «paused» — the room simply looks empty, which is indistinguishable from a room
that was never staffed.

Two lessons for the implementation:

- **Ineligibility must have a visible cause.** Under R14 an ineligible agent is expelled, but
  a provider pause is *temporary* and expelling on it would empty every room on a restart of
  the provider stack. So R14's «espulsi» has to be scoped to a durable change (the tier rose,
  the agent's provider is below it permanently) and a pause needs its own visible state —
  otherwise the fix trades a silent absence for a destructive one.
- **«Cannot add X to the channel» has the same root.** Adding a participant checks the same
  eligibility, so the two symptoms had one cause and looked like two bugs.

### Open

- **What happens to an existing participant when the tier rises** — removed, or suspended
  with a visible reason? Removal is silent authority; suspension needs a state that does not
  exist yet.
- Whether the same rule applies to humans (clearance ≥ tier) — today the two axes are
  checked separately.

## R15 · The seed declares how it activates: queue, parallel, or refuse

> «coda, parallelo e rifiuto sono tutte valide, il profilo del seed dovrebbe riportare la sua
> meccanica di attivazione fra queste tre»

The answer to «the chosen agent is already busy» is not one behaviour but a **declared
property of the seed** — which is consistent with how the platform treats everything else
about a seed: the seed says what it is, and the runtime obeys.

### Measured

- A seed already declares one routing-related field: `routing_mode: normal |
  state_writer_only` (whether it may be chosen without being named). The new field is a
  sibling of that one, not a new concept.
- «Parallel» partly exists as **multi-spawn** (`@nome#2`), where several instances of one
  seed run at once. Whether R15's «parallelo» means multi-spawn or two concurrent turns on
  one instance is the first thing to settle — they are different in cost and in isolation.
- Nothing today expresses «refuse»: a second message during a turn is simply another turn.

### Open

- The default for a seed that declares nothing.
- Whether «coda» is per seed or per scope: two rooms queueing on the same agent are a
  different thing from two messages queueing in one room.

---

## Four decisions closing R10, R11, R14, R15

> «il coordinatore è sempre il segretario per i topic a meno che non sia presente clodia e in
> quel caso è lei. Nei job l'agente mandatario è sempre anche il coordinatore. Se il tier
> sale, gli agenti non in regola sono espulsi dallo scope. Il parallelo significa multi-spawn»

**The coordinator is a rule, not a ranking.** In a topic: `segretario`, unless `clodia` is a
participant, in which case her. In a job: the mandated agent is its own coordinator — which
follows from R11 (one agent) and removes the question entirely for async scopes. No new field
is needed anywhere: the rule reads the participant list.

**Tier rises → the non-compliant are expelled.** Not suspended. So R14 needs no new state:
membership is the state. Expulsion is an act on the walls of the scope, so it will have to
say who did it and why — a participant who disappears without a line in the room is
indistinguishable from one who left.

**«Parallelo» = multi-spawn.** Two turns on one instance is not on the table. R15's three
values therefore map onto things that exist or nearly exist: *coda* is new, *parallelo* is
multi-spawn (built), *rifiuto* is new.

### Measured — and this one changes the work

`segretario` today is **not able to be a coordinator**, in three independent ways:

```
type: normal          routing_mode: state_writer_only
tool_permissions: ['topic.open', 'topic.read_document', 'topic.save_summary']
expertise: «Salvare e aggiornare lo stato di un topic…»
```

1. **`routing_mode: state_writer_only`** means the router may choose it *only* when the
   message is a state-writing request. As the coordinator of last resort it must be
   selectable precisely when nothing else matched — the exact opposite.
2. **Three verbs, none of which can hand over.** A coordinator that classifies must be able
   to name another agent in the room, i.e. post a message with a mention. `segretario` cannot
   post at all.
3. **Its expertise is one sentence about summaries.** Under R7 the profile is what the
   semantic router matches on, so widening the seed to make it a coordinator would also make
   it a *magnet* for ordinary messages — the opposite of the narrowness that made it useful.
   Whatever the coordinator role is, it must not be expressed by enlarging the expertise.

This is worth stating plainly because it inverts the cost estimate for R10: the rule is
trivial, the **capability is not**. Either `segretario` gains a coordinator hat that is
separate from its expertise (a role, with its own verbs, that does not feed the embedding
profile), or the coordinator of a room without Clodia is a different seed built for the job.

Recorded, not decided: the requirement says *segretario*, and it is the requirement that
wins — but it cannot be implemented by editing a rank.

### Consequence for R2/R3, implied and worth confirming

R12 makes `$nome` inert. It follows that soft mentions do **not** count towards the «two
agents mentioned» dialog or the «three or more» refusal — those thresholds count summons, and
`$` is no longer one. Stated here as an inference rather than left to whoever implements it.

### Still open after these answers

- **What the coordinator returns**: a name (the router then starts that agent's turn), or an
  answer with an optional hand-over. One bubble or two.
- **Whether R14 applies to humans** as well (clearance ≥ tier); today the two axes are checked
  in different places.
- **The default activation mechanic** for a seed that declares none.
- **Whether «coda» is per seed or per scope** — two rooms queueing on one agent is not the
  same problem as two messages queueing in one room.
- From earlier: the state of a human assignment (R1), who may answer a routing dialog (R3), a
  person with no Telegram (R4), how the N messages are combined (R7), when a remembered
  choice stops being «primo riferimento» (R8), who may overrule a confident router (R9).

### Ruling on the coordinator (11 Aug 2026)

> «insisto con segretario, il suo mandato andrà modificato. Ma infatti il prossimo notebook
> sarà sugli agenti e i loro verbi e obiettivi»

R10 stands as written: **the coordinator is `segretario`**, and the seed's mandate changes to
fit — not the rule to fit the seed. The mandate belongs to the next notebook (agents, their
verbs and their goals), so it is not settled here.

**One constraint travels with it**, and it is a routing constraint rather than an agent one,
which is why it is recorded on this side: under R7 the semantic router matches on the seed's
expertise and skills. If the coordinator's mandate is written into those, `segretario` becomes
a magnet for ordinary traffic and starts winning messages that belong to specialists — the
opposite of what the fallback exists for.

So whatever the new mandate says, the router must not score the coordinator on it. Either the
coordinating duty is expressed outside the fields `_profile_pieces` reads, or the coordinator
is excluded from the scoring pass and reachable only by mention and by fallback. That second
form already has a name in the code: it is what `routing_mode` does today — and the
coordinator's value is the inverse of `state_writer_only`, i.e. «never chosen by relevance,
always available as the fallback».

Noted so the agents notebook inherits the constraint instead of rediscovering it after the
first room where the secretary answers everything.

## The secretary's mandate → agents notebook

The mandate of `segretario` — the secretarial work it owns, and the coordinating duty it
performs when it arrives by fallback — was dictated on 11 Aug and belongs to the seed, so it
lives in [`agents-notebook.md`](agents-notebook.md) (A1). Two consequences are *routing*
consequences and are recorded here so this notebook does not lose the answer to its own
question:

- **A turn must carry why it started.** A mandate conditional on the route is unimplementable
  if the route does not reach the agent. Measured: the vehicle exists —
  `_start_turn(..., kind)` carries the tag type and `_tag_directive` turns it into a prompt
  line (`[RICHIESTA DIRETTA] … ti ha taggato con @`). What is missing is a fourth value for
  «you are here because nothing matched».
- **R10's open point is answered, with three outcomes and not two.** The coordinator either
  does the work itself, or **mentions** the right agent — which is R2's direct route reached
  from inside the room — or says out loud that nobody in the room fits, naming the two
  remedies (reformulate, or add an agent). That third path is the only one in the whole router
  that ends in «this room cannot answer this» instead of in silence or in the super-agent
  answering anyway, and it closes the loop with R14: adding an agent to a scope is exactly the
  act R14 governs.

---

## R16 · The chain has a limit, and the limit must speak

> «fullstack quando menzionato a volte parte e a volte no»
>                                                     — Davide, 17 Aug 2026

Not intermittent — **positional**. `_MAX_DELEGATION_HOPS` was 2 and fixed, and the two
call sites read

```python
if hop < _MAX_DELEGATION_HOPS:
    await _maybe_delegate(...)
```

so past the limit the delegation function was never entered. No log line, no message in
the channel, no trace anywhere. A `@fullstack-dev` written by an agent on the third leg
of a chain simply did not exist.

| leg | who mentions whom | outcome |
|---|---|---|
| 0 | Davide → @clodia | starts |
| 1 | clodia → @fullstack-dev | starts |
| 2 | fullstack-dev → @clodia | starts |
| 3 | clodia → @fullstack-dev | **nothing, and nobody is told** |

Measured on `software-house`: the chain reaches `hop 2` routinely, so the fourth mention
of any working session fell into the hole. From the channel this is unpredictable, because
nothing displays where in the chain a message sits.

**Two defects, and only one of them is the number.** A limit on the chain is right — it is
the brake on agents bouncing a task between themselves, and raising it does not remove the
need for it. What was wrong is that the brake was silent: «I called him and he does not
answer» is indistinguishable from a fault, and it was reported as one. So the check moved
*inside* `_maybe_delegate`, which is the only place that knows **who** had been tagged —
the single piece of information that makes the notice worth posting.

The notice is posted only when there was something to serve. A reply with no eligible tag
produces nothing, or the channel would fill with notes about mentions that were never
there. A `$` citation alone likewise: it does not open a turn inside the limit either, so
past the limit there is nothing denied to declare.

**The number went from 2 to 4, and became configurable** (`CLODIA_MAX_DELEGATION_HOPS`).
With a coordinator and an executor, 2 is exhausted by the first return exchange, which is
the shape of nearly every session in a working channel; 4 allows two complete exchanges.
The right value depends on how many agents cooperate in a channel, and that is not
knowable in advance — but an unreadable value falls back to the default rather than
turning the brake off, because `0` would block every delegation and the failure would look
exactly like the one this note fixes.

**Configurable, but not actually settable — until 18 Aug.** The code read
`CLODIA_MAX_DELEGATION_HOPS` from the moment the limit became a variable, and
`docker-compose.yml` never declared it. A value in an instance's `.env` therefore never
reached the container: the knob existed in the code, answered `4` whatever you wrote, and
nothing said so. Exactly the shape of the `CLODIA_DEBUG_MODE` defect the security-posture
block in that same file was written to record — which is the argument for reading a lesson
as a *class* rather than as the one variable that occasioned it. Now declared, with `4`
still the default for whoever installs.

**What raising it costs, stated where the number is set.** This limit is the *only* brake
on agent-to-agent ping-pong: R3 bounds how many mentions a single message may serve, not
how long a chain may get. So the hop count is a multiplier on LLM turns that one human
message can trigger — at 50, up to fifty consecutive turns before the chain stops and says
it. That is a legitimate setting in a channel where many agents genuinely cooperate, and it
is the reason the default does not move: whoever raises it is choosing to pay for those
turns, and should be doing so on purpose.

**Where the chain resets.** A human message starts at `hop 0`. So the recovery path is
always available and the notice says it: the chain restarts from a human message.
