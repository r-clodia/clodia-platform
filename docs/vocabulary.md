# Vocabulary: topic, channel, session, scope

Four words for one arrangement, decided 6 Aug 2026. They had been used
interchangeably, and the confusion was not only lexical — it produced a real
permission defect (see notebook entry 8).

| term | what it is | address | how many |
|---|---|---|---|
| **topic** | the purpose and the objective. The load-bearing concept: `meta`, files, participants, tier, remote, **and** its message stream | `(tier, name)` | — |
| **channel** | the group chat of the topic: the medium. A *view* of the topic, not a separate object | needs none | 1 per topic |
| **session** | the private context of **one** responding agent onto that channel | `chan:<tier>:<topic>:<agent>#<ordinal>` | N per topic |
| **scope** | where a spawn is born, operates and dies | a session, **or** a job run | — |

**Topic is load-bearing.** A DM is a topic too: `POST /clodia/dms` also calls
`create_topic`. What the UI *shows* may be renamed per edition —
«pratica», «fascicolo», «progetto» — through `instance_profile.vocabulary`;
precisely because the displayed word varies, the internal one must be single and
stable.

**The channel needs no identifier**, because it is the topic's conversational
face. There is already exactly one per topic and the code proves it:
`channel_messages` aggregates nothing, it reads
`topics_client.list_messages(tier, name)` — a single stream, not one list per
agent.

**`chan:` prefixes a SESSION id, not a channel.** This is the naming bug at the
root of the confusion, and the code already knows the right word — from the
`reset-context` docstring: «chiude le **runtime session dei responder**». A
rename of the string is deliberately *not* done: `chat_id` is a filename
component (`sessions/chat-chan:SEAL-1:pof:clodia.jsonl`) and also lives in
`scheduler/db`, `scoped_overrides`, PKI tokens and telemetry across ~20 modules.
Renaming would migrate the conversational history, which is the thing least worth
risking, and no user ever sees the string. **`chan:` is therefore frozen as an
opaque legacy token meaning "session".**

**One public log, N private contexts.** The N responders of a topic share a
single public message stream, but each holds its own conversational history
(`chat-<chat_id>.jsonl`). Neither contains the other: an agent has its own turns
and not a colleague's, and also holds material that never reached the log. So
*«what the channel knows»* ≠ *«what an agent knows»* — the asymmetry that any
question about resource visibility has to start from.

**Legacy on the API surface.** The same `(tier, name)` is addressed under four
prefixes: `/clodia/channels/…`, `/clodia/chats/…/hooks`, `/topics/…`,
`/api/topics/…`. New endpoints should use `/topics/…`; `/clodia/channels/…` is
the one to retire, since that is what the UI calls today.
