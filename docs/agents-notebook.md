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
