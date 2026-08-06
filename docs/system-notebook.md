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
- **`ophelia` is still a super-agent.** `clodia` was removed from both super sets on
  6 Aug; the concept survives in seven places with three independent definitions, two
  of which are not agent authority at all but the agent-server's *service* identity
  (human profiles have no server-side key to mint a token in their own name).
