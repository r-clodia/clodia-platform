# System notebook

Verified facts about the running platform, one entry per definition, each with the
measurement that established it.

**Why this file exists.** On 6 Aug 2026 we found four fields that existed in the live
config and in no declaration, a wildcard that meant "everything" or "nothing"
depending on an agent's *name*, and a test that passed because it named a verb the
platform does not have. Every one of those was a belief held without a measurement,
and every one survived because nothing wrote down what had actually been checked.

So the rule for this file: **a statement lands here only with the command that
verified it and the date it was verified.** A claim without a measurement goes under
*Open* instead, and stays there until someone measures it. An entry whose measurement
stops being true is a defect, not a documentation gap.

Facts decay. Each entry says what it depends on, so that when the dependency changes
the entry can be re-checked instead of quietly becoming false.

---

## 1 · Seeds are types, spawns are live instances

**Definition (Davide, 6 Aug 2026).** A *seed* is a type or template. A *spawn* is a
live instance, and each spawn has its own process in the operating system.

**Verdict: holds.**

Measured on venere, inside the agent-server container:

```
/datadir/spawns/clodia-1/   drwx------  uid 60000  gid 62554
/datadir/spawns/clodia-2/   drwx------  uid 60001  gid 62554
```

So the uid is **per spawn** and the gid is **per seed** — two live instances of the
same seed are distinct users to the kernel.

**Precisation that constrains everything downstream: the authority is attached to the
seed, not to the spawn.** In the signed session token the `agent` claim is `clodia`,
not `clodia-1`; the spawn appears only as `execution_id` and inside the `chat` claim
(`chan:<tier>:<topic>:<agent>`):

```
parametri di mint_session_token: ['agent', 'execution_id', 'ttl_seconds',
                                  'principal', 'clearance', 'on_behalf']
payload: "agent": agent, "execution_id": execution_id,
```

Consequence for the model: two spawns of the same seed working on two different topics
have the **same** matrix. That is workable only if the *resource* is narrowed by the
execution context — the topic, which arrives signed — and not by the subject. It is the
shape the Drive perimeter already took on 6 Aug: the folder is an attribute of the
channel, not of the agent.

*Depends on:* `pki.mint_session_token` keeping `agent` = seed name; the spawn
allocator assigning one uid per spawn.

---

## 2 · A spawn owns its scratch and cannot reach another's

**Definition (Davide, 6 Aug 2026).** Each spawn has its own scratch space, of which it
is master. A spawn cannot invade the scratch of another spawn.

**Verdict: holds, and for the strongest available reason — the kernel, not our code.**

The claim rests on a fact that had never been measured before today: that the agent
process actually *runs as* the spawn's uid rather than as root. Read from `/proc`
inside the agent-server on venere:

```
   PID     UID  comando
     1       0  sh -c cd /clodia && python3 -m server.main
    69       0  python3 -m server.main
    79   60000  …/claude_agent_sdk/…        ← clodia-1
   164   60001  …/claude_agent_sdk/…        ← clodia-2
```

The server is root; the agents are not. Combined with `drwx------` on each scratch,
cross-reading is refused by the operating system. A defect in our application code
cannot open that door — the only control in the whole model with that property.

**Objection, and it is not against the definition.** On **marte**, inside
`/datadir/spawns`:

```
1 directory (gli spawn) e 226 FILE al livello superiore
226 file  -rw-r--r--  uid=0   → LEGGIBILE DA TUTTI
```

The parent is `drwx--x--x`, so traversable by every uid. Those 226 files are
world-readable and owned by root, so **any spawn can read all of them** given the
name — and they are real working material: invoices, contracts, NDAs, bank
statements, balance sheets.

This does not contradict the definition literally: the files are not *inside* any
spawn's scratch, they are in the shared yard one level up. But it defeats its purpose,
because the content the scratches were meant to separate ended up above them, in the
clear, for everyone. venere does not have the problem — only the two spawn
directories.

Written by root, so by the gateway or the agent-server, not by an agent. **Who writes
them, and why there, is not yet established** — see *Open*.

*Depends on:* spawn processes continuing to run under their allocated uid (a change to
the runner that dropped `setpriv` would silently remove the only kernel-level boundary
we have); the scratch staying `700`.

---

## 3 · The seed declares the verbs, statically, from its pack

**Definition (Davide, 6 Aug 2026) — this is a REQUIREMENT. The code adapts to it, not
the reverse.**

> Seeds declare which verbs — that is, actions — the spawns derived from them may
> execute. Those verbs may be gated or free depending on the case. That definition of
> verbs comes from the origin pack and **is not dynamic**.

The exception the model allows, stated earlier the same day: a spawn asked to perform a
verb it does not possess may receive a **specific grant, assigned through a gate**. An
exception borrows a verb for a task; it never rewrites the declaration.

Note on reading it precisely: *«tale definizione di verbi viene dal pack»* concerns the
**set of verbs**, not the danger flag. So the gateway holding a global list of 27 verbs
plus the `settings.` / `pki.` / `ca.` prefixes does not contradict the requirement — and
should not, because "dangerous for anyone" is not a property a third-party pack author
can decide for someone else's instance.

**Two places where the code deviates. These are defects, not caveats.**

**(a) `memory.*` is granted to every agent without being declared.**

```
_UNIVERSAL_NS = {'memory'}
un agente che non dichiara memory.* lo ha comunque: True
```

So the effective set is not the declared set. It is also why `messaggero`, listing its
verbs, included `memory.*`: it does hold them, without having asked. **Fix:** declare
the memory verbs in the seeds that need them and remove the universal namespace.

**(b) The pack is not the effective source; `config.yaml` is.**

The dispatch reads `allowed_tools` from the gateway's config. The pack *seeds* it, and
nothing verifies the two still agree — four divergences measured on 6 Aug, one of which
took clodia from 53 verbs back to 130 four hours after the reduction, because
`save_config` wrote a stale in-memory copy. **Fix:** the coincidence pack ↔ config must
be verified, not hoped for — a boot reconciliation that fails loudly rather than a sync
run by hand.

**Already implemented, and to be governed rather than rebuilt:** the exception exists as
`scoped_tools` — verbs added to a turn through a **signed** token claim, granted with
`agents.grant_scoped`, which is gated. Verified: gated true for both grant and revoke.
It expires with the token, so it cannot silently become permanent. When the exception is
turned on deliberately, this is the mechanism to use; building a new one would add the
22nd where 21 already exist.

*Depends on:* `_UNIVERSAL_NS` staying empty once (a) is fixed; the reconciliation in (b)
existing at all.

---

## 4 · The seed declares the skills its spawns will know

**Definition (Davide, 6 Aug 2026) — requirement.** A seed also declares which skills its
spawns will know how to use, possibly making use of the verbs granted to them.

**Holds as a requirement. Nothing enforces the "possibly making use of the verbs" part,
and the gap is already active.**

Skills are declared as `capabilities` in the seed — `messaggero` has
`['comms-pack/check-email', 'comms-pack/telegram-1to1']`. Verified.

**Defect (a): no skill declares the verbs it needs.** Measured: **0 of 11** `SKILL.md`
files carry a `tools:` / `verbs:` / `requires_tools:` field. So nothing can check that a
seed declaring a skill holds the verbs to execute it. Coherence rests on whoever writes
the seed remembering.

**Defect (b): clodia declares five skills it cannot execute.** With
`capabilities: [base-pack/*, editorial-pack/*, comms-pack/*, anthropic-pack/*]` and 53
verbs, cross-checking the verbs each skill names against clodia's set:

```
topic-drive-sync    missing gdrive.download, list, mkdir, upload
topic-management    missing topic.archive, topic.new
check-email         missing email.list, read, save_attachment, search, jobs.propose
telegram-1to1       missing telegram.inbox, lease_acquire, poll, send…
helpdesk            missing agents.memory, agents.profile
```

The first four follow from the deliberate reduction to 53 verbs, and clodia *should* not
have mail. The defect is not the missing verbs — it is that the seed keeps **declaring
the skills**. An agent that announces a capability it cannot exercise discovers it by
trying, and reports "I lack the permission": the loop that cost an afternoon with
messaggero.

`helpdesk` names `agents.memory` and `agents.profile`, which **do not exist** as verbs.
Fifth dead name found on 6 Aug.

**Consequences of the requirement:** skills must be declared without wildcards
(`base-pack/*` grants every skill added tomorrow, unevaluated against that agent's
verbs — the same argument Davide made in August about verb wildcards), and a skill must
declare the verbs it requires, so `skill ⊆ seed's verbs` is checkable at install rather
than in production.

*Depends on:* `capabilities` staying the declaration point; skills gaining a verb
manifest for the check to become possible.

---

## 5 · The spawn loads the seed's prompt and the seed's mutable memory

**Definition (Davide, 6 Aug 2026) — requirement.** When a spawn is materialised it always
loads into its LLM context the system prompt defined by the seed, which is **immutable**,
and `MEMORY.md`, also defined by the seed but a memory that spawns may modify when they
learn new information.

**Holds.**

The prompt is immutable *to the spawn* for a kernel reason, not a policy one:
`/datadir/agents/<name>/` is `drwx------ root` and a spawn runs as uid 60000 — it cannot
even read it. Only an admin changes it.

The memory survives a pack update, verified in `pack_import`:

```python
shutil.copytree(sdir, dest, dirs_exist_ok=True,
                ignore=shutil.ignore_patterns(".git", "memory"))
(dest / "memory").mkdir(exist_ok=True)
```

So the pack ships an initial `memory/MEMORY.md` for four seeds — clodia, ophelia,
segretario, sysadmin — and from then on it belongs to the agent. Updating the pack
replaces the definition and preserves the learning. `messaggero` has no `memory/` in the
pack: its memory is created at runtime, and per its prompt it holds the **Telegram
authorisation whitelist**.

**Defect: `memory.write` overwrites blindly.** Atomic (`.tmp` then `replace`) but with no
re-read and no version:

```python
tmp.write_text(content or "", encoding="utf-8")
tmp.replace(p)
```

Two spawns of one seed share the memory by construction (symlink), and on venere
`clodia-1` and `clodia-2` are both alive. Concurrent writes: **last one wins, the other's
learning disappears silently.** It is the same defect fixed in `save_config` on the same
day — "a process pours its own copy over what another wrote in the meantime" — moved onto
the agent's learning, where it is harder to notice because nobody re-reads it for
comparison.

Two things make it worse than it sounds. `append` exists and is the right path, but
nothing compels it: `write` is available, and a model that "rewrites the updated file"
reaches for that. And an **access-control datum** — messaggero's Telegram whitelist —
lives in a file subject to this race.

**Fix:** `memory.write` re-reads and writes only its delta, or takes a version and
refuses on conflict, as `topic.save_summary` already does.

*Depends on:* the memory staying a symlink shared across spawns of a seed; `pack_import`
keeping `memory` in its ignore list.

---

## 6 · Spawns exist in exactly two scopes: channel and job

**Definition (Davide, 6 Aug 2026) — requirement.** Spawns are born, operate and die in a
scope of only two kinds: a topic/channel chat, or a job execution.

**The requirement stands. The code has four, and the two extra ones are defects.**

Seven sites create sessions. Two match the requirement — `chan:<tier>:<topic>:<agent>`
(with `#<ordinal>` for multi-spawn) and `run_id="job:<id>"` from the scheduler. Two do
not:

- **`feedback:<agent>`** — a thumbs up/down creates its own session with
  `principal = "feedback"` and hands the agent a prompt asking it to write a lesson into
  memory. Davide's ruling: *feedback is not a spawn scope, it is an action inside the
  channel where it happened.* It also writes to the seed's persistent memory — the only
  state that outlives spawns — through the blind `memory.write` of entry 5.
- **`pack-ops:<agent>`** — invents its own `chat_id`. Davide's ruling: *it happens in the
  DM between `sysadmin` and the human*, which is already a channel.

Plus `DEFAULT_CHAT_ID` at server start, to be looked at: if it is neither, it is a third
leftover.

**A DM is a channel** — a topic with `kind: "dm"`, tier SEAL-0, name `dm-<a>--<b>`, so its
turns get `chat_id = chan:SEAL-0:dm-…`. Measured:

```
scope                  in_channel  email.send gated  telegram.send gated
  canale di topic      True        True              True
  DM con l'umano       True        True              True
  job                  False       False             False
```

**This corrects a statement I made to Davide the same evening** — that a DM is "outside a
channel" and therefore ungated. It is not: the gate fires in a DM too, so asking
messaggero to send in your own DM prompts you, as admin, for your own request.

And it exposes what `gated_in_channel` really is: with two scopes and a DM being a
channel, it means "always except in jobs" — so the mechanism's name misdescribes its
criterion. The criterion intended was *when whoever asks might not be the owner*, which
is the origin chain. `gated_in_channel` is a coarser stand-in than even its own PR
admitted, and the origin chain removes it entirely.

*Depends on:* `in_channel()` keying on the `chan:` prefix; DMs continuing to be topics.

---

## 7 · Spawn numbering: one series per seed, unique across scopes, never reused

**Definition (Davide, 6 Aug 2026) — requirement.** Spawns carry a progressive number
(`clodia-23`). Numbers already used are **not reusable** in other scopes. This identifies
a workload uniquely as `spawn-N` and ends up in the audit trail. The counter is global
per seed — so `clodia-4` and `ophelia-4` may coexist, but `clodia` has a single series
across all topics and jobs.

**Half implemented.**

**Holds:** the series is per seed and blind to scope. `_next_spawn_index(name)` scans for
`<name>-<int>` without looking at whether the spawn is born in a channel or a job, so one
`clodia` series covers both. `clodia-124` and `wainston-7` coexisted on marte.

**Defect: the numbers ARE reusable**, so `spawn-N` does not identify a workload:

```python
def _next_spawn_index(name: str) -> int:
    """…Scansiona SPAWNS_ROOT per le cartelle <name>-<int>."""
    mx = 0
    for d in SPAWNS_ROOT.iterdir():
        if d.is_dir() and suffix.isdigit():
            mx = max(mx, int(suffix))
    return mx + 1
```

The index is a `max()` over **existing directories**, and the reaper deletes old spawns —
so once `clodia-124` is gone the next `clodia` takes a number already used. marte held
243 directories before a cleanup; after it, numbering restarted into occupied ground.

Two workloads with the same name in different moments make an audit line saying
`clodia-124` identify nothing. And `_spawn_identity` already publishes `spawn_id` /
`spawn_instance` derived from that directory name.

Worse, the counter lives **on the spawns' disk** — the most ephemeral state in the
system. A `docker volume rm` resets it.

**Fix:** a persistent monotonic counter per seed, held where spawn cleanup cannot reach
it, incremented atomically at allocation, never decremented or reused.

**Open decisions when we get there,** both of which change the audit trail: whether the
series should be unique only per instance or across instances (`clodia-16` on marte and
`clodia-16` on venere are two different workloads with one name today, and the collision
returns the day the audit trails converge).

*Depends on:* the reaper continuing to delete spawn dirs — which is what makes a
disk-derived counter unsafe.

---

## Open

Questions raised while verifying the above, not yet measured. Each one is a belief we
do **not** hold.

- **Who writes the 226 files at the top of `/datadir/spawns` on marte, and why there?**
  They are root-owned, so a platform component. Until this is answered they are data
  with no declared owner, in a location the model does not describe.
- **Does any agent declare `/datadir/spawns` among its `allowed_paths`?** If so, it can
  enumerate as well as read, and the yard becomes a directory listing of everyone's
  work.
- **Does any seed rely on `memory.*` being implicit?** Before removing the universal
  namespace, every seed that uses memory verbs has to declare them, or removing it
  breaks agents silently instead of loudly.
- **What is `DEFAULT_CHAT_ID` at server start, and is it a spawn scope?** If it is
  neither channel nor job it is a third leftover to remove (entry 6).
- **Should the spawn series be unique across instances, not only within one?** (entry 7)
- **`ophelia` is still a super-agent.** `clodia` was removed from both super sets on
  6 Aug; the concept survives in seven places with three independent definitions, two
  of which are not agent authority at all but the agent-server's *service* identity
  (human profiles have no server-side key to mint a token in their own name).
