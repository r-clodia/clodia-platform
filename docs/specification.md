# Clodia Platform — Specification

The consolidated model of the platform: what an actor is, what a scope is, who may do
what, and where the boundaries are.

**How to read this.** Each statement is the settled form. Where a measurement *constrains*
the design, it is kept inline, because removing it invites the design to drift back. What
is not kept is the road here — the drafts, the objections raised and answered, the dates.
That belongs to `git log`, which holds it in full: this file is a specification, not a
diary.

Everything here was dictated by Davide between 6 and 7 August 2026 and verified against
the running platform. What is specified but **not yet built** is not marked here — it is in
`gap-analysis.md`, which is the implementation objective.

---

## 1. Actors

### 1.1 Seeds and spawns

A **seed** is a type. A **spawn** is a live instance with its own operating-system process.
The uid is per spawn, the gid per seed: two live instances of one seed are distinct users
to the kernel.

**Authority is attached to the seed, not to the spawn.** In the signed session token the
`agent` claim is the seed name; the spawn appears as `execution_id` and inside the `chat`
claim. Two spawns of one seed therefore hold the same *matrix* — which is workable only
because the **resource** is narrowed by the execution context, which arrives signed. See
§3.2.

A spawn owns its scratch directory and cannot reach another's.

### 1.2 Spawn numbering

Ordinals are one series per seed, blind to scope, and **never reused**: `clodia-4` and
`ophelia-4` may coexist, but a `clodia-124` that has been reaped does not free its number.
The ordinal identifies a workload in the audit trail, which is the whole reason it may not
repeat.

Uniqueness holds **within an instance**. Across instances it is not pursued: clones are
independent by design, so identity in an audit line is (instance, seed, ordinal).

A human is a **named** spawn, not a numbered one: humans are distinguished by identity, and
an ordinal would mean nothing.

### 1.3 The archseed

One **abstract seed**, which cannot be spawned, holds the base verbs and attributes. Every
seed descends from it and acquires them by inheritance.

A verb belongs in the archseed when **its target is the agent itself or the room the spawn
is already standing in**. Everything else is trade, and trade belongs to the seed.

- `memory.*` — its own memory, confined to its own folder.
- the reading floor of the current scope: `topic.open`, `topic.files`, `topic.read_file`,
  `topic.read_document`, `topic.search`, `topic.list`, `topic.fetch`.
- `topic.post_message` — a spawn that cannot speak in its own room cannot do anything.
  Speaking is not mutating (§3.1).

Outside it: writing, everything that moves the walls, and every namespace that leaves the
scope.

**The measurement that constrains this.** The intersection of every non-wildcard agent is
two verbs on one instance and **empty** on the other, and two agents are deliberately
narrow — `segretario` holds three verbs, `security-engineer` seven read-only ones. An
archseed carrying `topic.*` would widen them without anyone having decided so. Hence a
floor of reading plus speaking, and hence subtractability below.

### 1.4 Inheritance

A derived seed inherits system prompt, skills and verbs from its parent and **may override
everything it inherits**. The parent is a **default, not a ceiling**: containment comes
from the gates, the scope's lists and the intersection of the origin chain — never from the
ancestor.

Inheritance must be **subtractable**: a seed narrower than its parent declares the
subtraction. Without it the archseed widens the deliberately narrow agents.

`abstract: true` is enforced at spawn time, not merely declared: an archseed spawned by
accident is an agent with base verbs and no trade, and it works well enough that nobody
notices.

The **resolved** set is visible with provenance — each verb marked inherited or own.
Otherwise a duplication has been traded for an opacity, and the opacity is worse, because a
duplication is at least visible.

### 1.5 What a seed declares

1. **Verbs** its spawns may use. Static, from the originating pack, never dynamic. Verbs
   may be gated or free.
2. **Skills** its spawns will know, exercised through the verbs they hold.
3. **System prompt** (immutable) and **`MEMORY.md`** — a memory the spawns may write when
   they learn something.
4. **An inference vector** of `(provider, model)`. A spawn inherits the default and may
   have it overridden for itself.

**The model is the seed's; the provider varies.** A provider appears in at most one stack,
so two models on one provider cannot be declared — a cost ladder *within* a provider is not
expressible, by design. The vector carries a **security** property, where the data goes, and
not a price preference. Different spawns of one seed may run on different providers, and
their effective clearance differs accordingly (§6.2).

The **default** is not "first in the vector": it is the first whose provider is connected
and not paused, subject to a manual override. It is a resolution against the state of the
instance, so the same seed on two instances can resolve differently.

### 1.6 What a seed does not have

- **No rules.** A rule would be a second channel for what the prompt already says.
- **No sandbox.** The kernel already separates: the seed's memory is root-owned and the
  spawn runs as an unprivileged uid, so a spawn cannot write another's state.

### 1.7 Humans

Humans are agents with **no provider**. They do not fork spawns — they *are* spawns, of two
fundamental seeds: **`admin`** and **`member`**. Their seed defines their verbs.

- The **role** is per person and lives in their own file; the **matrix** is per class and
  lives in the seed. One fact per place.
- An individual declaration may only **narrow**. Intersection, never substitution: if it
  could widen, the seed would stop defining the verbs.
- `superadmin` is not a stronger admin: it is the **instance owner**, a singleton, and an
  attribute of the admin spawn rather than a third seed.
- Because a human has no provider to lower it, their declared clearance is **authoritative**
  rather than a floor.
- The human system prompt is decorative, and is therefore **absent** rather than inert.

A human is **link zero** of the origin chain (§3.3).

---

## 2. Scopes

### 2.1 Scope is the type

`scope` is the type; **topic isA scope**, **job isA scope**. Spawns live in a scope, and
resources are elements of a scope. A spawn exists in exactly **two** kinds of scope —
channel and job — and in no third: a session belonging to neither is an environment where
every per-scope control silently degrades to the global one.

### 2.2 The topic

The topic is the load-bearing concept; the **channel** is its group chat. A DM is a topic
(`kind: dm`), and therefore a real scope with a tier, an owner, lists and a perimeter.

### 2.3 The job

A job **is** a scope: it carries its own tier and its own lists rather than falling back to
the global ones. This is not "every job hangs off a topic" — a job that belongs to no topic
is legitimate.

A job scope has an **owner and no participants**: the owner decides who may see a run's
output, and a job is not a room people are invited into.

A job declares a **tier**. If the agent's provider cannot carry it, the run **fails** with
an error and a logged message — it does not degrade. Running a job declared for SEAL-3 data
on a weaker provider would send that data where it must not go, and would report success.

### 2.4 Portability

A topic may declare itself **portable**: its participating seeds and their spawns can reach
its contents **from any other scope**. Portability is declared by the **topic**, not by the
agent — an agent that adds a topic to its own list would be giving itself a channel, while a
topic that declares itself portable is a decision of whoever owns the contents.

Portability is the **named exception** to §3.2: it opens that topic and no other.

**A carried topic travels only where the room can hold it.** If the portable topic is
SEAL-3, its participants are necessarily SEAL-3 or above; but summoned into a SEAL-1 room
they simply do not have its data there. The constraint is on the **room**, where the data
would be read by that room's participants — not on the membership.

This **refuses**, it does not gate: a gate would leave someone the power to approve exactly
the transfer the rule prevents, and an owner's consent does not raise a room's tier. And the
refusal is **spoken** — the agent says in chat that the topic is out of reach here, naming
both levels and stating that this is not a missing permission. Silence would let an agent
conclude the archive is empty rather than out of reach.

### 2.5 The anatomy of a scope

A scope has `tier`\*, `metadata`\*, and `data`. Starred is mandatory; a job has no
filesystem.

- A **mailbox** is a **global resource**, like the Google account or the git credential.
  The **senders and recipients** are the ingress and egress declared by the scope that uses
  it. A credential cannot belong to every room that reads mail through it; what a scope
  answers is who may write in, and who it may write to.
- A **remote** inserted by a human enters the scope's perimeter and is approved as both
  ingress and egress.
- The **user's terminal** is an approved ingress **as a channel** — unspoofable, and what
  the owner says needs no per-item approval. But authenticity is not trustworthiness: the
  `tainted` bit belongs to the **provenance of the content**, not to the channel it arrives
  on. Otherwise pasting a web page into the terminal makes it trusted by definition.

### 2.6 One file view, two mounts

A topic has **one** file view: `local/` and `remote/` are two folders, one mounting the
local filesystem and the other the remote.

```
/                     ← the topic's DATA root
├── local/            ← the topic's files, without moving a byte
└── remote/
    └── drive/        ← the remote's root (or drive-2/ …)
```

The mount framing fixes what a path means: `/local/x` and `/remote/drive/x` are different
files that may share a name, so the collision question dissolves rather than needing a rule.

The mount's name is an **identifier** chosen at link time, validated, unique within the
topic — not the remote's display name, which can be absent, can contain a slash, and moves
when the folder is renamed.

### 2.7 The control plane

`AGENTS.md`, the `summary` and the `TLDR` are **metadata**, not files. They have no path
inside the data tree:

```
control plane (outside the tree):  meta.json · summary.md · AGENTS.md
data tree:                         /local/…  ·  /remote/<name>/…
```

Writing them is an act of authority, and authority-bearing writes live behind the version
lock. In the data plane, any participant's upload could overwrite the instruction file
injected into every turn.

A scope's `AGENTS.md` is injected as **context, not system instructions**.

### 2.8 Membership is graded

Three roles, a closed set: **owner**, **contributor**, **reader**.

- **Reading** is every member's, and **speaking** too — that is the point of a reader.
- Only what **mutates shared state** is graded.
- Ownership of a scope is the `owner` field, not a role assigned by inviting: otherwise a
  topic could end with two owners or none.
- A legacy participant list reads as **contributor**. Reader would be stricter but would
  silence every existing participant at once — a silent breakage dressed as a tightening.
- A reader's request is not ignored: it travels through an agent and, if it implies a
  mutation, becomes a gate addressed to the owner. What is stopped is the **direct** act.

**A scope owner is always human.** The rule gives owners gate authority, so an agent-owned
scope would unlock its own gates — the confused deputy legitimised by the design.

---

## 3. Authority

### 3.0 One kind of principal

A human and an agent are both entries in the registry, both carry a clearance, and both are
authorised by the **same** decision point — the gateway. Nothing distinguishes "a user did
it" from "an agent did it" except the contents of their matrices. Principals are written
`human:<name>` and `agent:<name>`.

This is not symmetry for elegance. **Every place where humans were authorised by a different
rule has produced a defect**: the on-behalf exemption, the binary «gated ⇒ admin, else
allow», and the assumption that "authenticated" means "trusted" — true while the only user
was the owner, false the day a second person logged in.

The authorisation question has the shape:

```
(resource, verb, channel) → permission
```

where **channel** is a predicate and not an identifier — `isParticipant(principal, scope)
AND clearance(principal) ≥ tier(scope)` — and **permission** has three values, not two:
`allow`, `deny` (which beats every allow, including a wildcard), and `gate`, which **defers
to a human**.

`gate` is where the model lives. Least authority by *removal* breaks the agent's trade;
least authority by *supervision* keeps the trade and inserts a human at the moment the
authority is used.

### 3.1 What decides

Effective authority is the **intersection** of:

- the **seed's matrix** — the verbs its spawns may use;
- the **role in the scope** where the action happens;
- for a human, the **profile matrix** of their class.

Intersection, never substitution. A role does not grant what a profile denies, and a
profile does not grant what a role denies. Every declaration that exists must allow.

A refusal must say **which** term blocked it, because the remedies are different people:
"your profile lacks this verb" is resolved by an admin, "here you are a reader" by the
scope's owner. A message that does not distinguish sends you to the wrong person.

### 3.2 Access belongs to the spawn

Membership of a scope's list says who is **eligible**; the room the spawn stands in decides
what it may **reach**. The room arrives in the **signed** `chat` claim — never from an
argument, which would be the agent's own word about where it is.

Without this, one seed participating in many topics means any of its spawns can read all of
them from any room and pour one into another. The model declares two axes — clearance
**and** compartment — but the second only compartments if evaluated **per spawn**. Per seed
it is a global permission dressed as a compartment.

Two spawns of one seed in the *same* room both have access: access follows the room. For
lending something to **one** spawn there is §3.5.

### 3.3 The origin chain

A command carries the chain of who is asking: `origin: ["human:giovanni", "agent:clodia",
…]`, inside the **signed** session token. An action is permitted only if **every link**
permits it.

Intersection, never substitution: an agent acting on your behalf can never exceed you, and
you can never exceed it. Every link narrows — intersecting only the ends would leave a
bridge through the middle.

A human is link zero. A `denied` beats a wildcard anywhere in the chain.

### 3.4 Scoped grants

A spawn can be given verbs **for its scope only, temporarily**: a signed claim, an approval,
a TTL. This is the mechanism for lending something to one spawn rather than to a seed.

Revoking a scoped override **need not** reach a live spawn: today the spawn must die first,
so a withdrawn model or provider stays in use until then. Accepted cost, written down so it
is known rather than discovered.

### 3.5 Where authority may live

**Authority must be unreachable by its subject.** Two placements are valid, and both are
load-bearing:

- **The gateway's own volume.** The agent-server does not mount it. This is why matrices,
  gates and allowlists live there and not in an agent's file or a topic's metadata: whoever
  can rewrite a boundary self-grants what it bounds.
- **Root-owned files on the datadir.** A seed's directory is `drwx------ root` while spawns
  run unprivileged — measured: a spawn can neither read nor write a human's seed. Here the
  boundary is the **kernel**, not application logic, which is why reading a human's role and
  matrix from there is sound.

**A control implemented in application code is only as strong as the absence of an
alternative path.** The Drive confinement is defensible because the credential never leaves
the gateway — no shell, no `curl`, no second client. A filter applied *after* the data has
been produced is not, because its fail-open branch is the only live path.

---

## 4. Gates

### 4.1 What a gate is

A gate is **not a property of a verb**. It is what happens when an action **crosses a
boundary**, or when the caller **lacks standing**.

There is **no gate on ordinary work inside one's own scope**. That row of the table is
empty, and it is what makes the model liveable: a gate that fires on every normal turn stops
being read.

### 4.2 The three classes

| class | what it crosses | who decides |
|---|---|---|
| `system` | the rules of the machine | an admin |
| `walls` | the boundary of a scope | the **owner of that scope** |
| `outward` | leaving | the **owner of the originating scope** |

The class travels **with the request** from the authority that holds it. Re-deriving it
where the decision is taken would be a duplicated rule, and a duplicated rule drifts.

### 4.3 Who decides, and who does not

An admin **does not substitute** the owner on a `walls` or `outward` gate. If they did, the
owner's authority would be decorative. An admin can still change the topic through the front
door — the difference is that there the act has its own name and its own log, instead of
passing as consent given on someone else's behalf.

**Denying is a decision too**, and needs the same standing as approving.

Three outcomes, not two: **allowed**, **refused**, and **we do not know**. A failure dressed
as a refusal sends the user to ask the wrong person. Reading the topic fails closed: an
unreadable topic makes nobody an owner.

The principle covering every crossing: **the owner of the scope whose data is at risk
decides** — the source for egress, the target for a read.

---

## 5. Perimeter

### 5.1 Two allowlists, and two axes

Destinations and sources are declared in **two** lists: a **global** one and one **per
scope**. They compose as a union.

The global list may hold **arbitrary entries the admin decides** — it is a deliberate
instrument, not a residue to be shrunk. The per-scope list exists so that reaching one room
does not require opening every room: with one axis only, approving an address opens it
everywhere and forever.

Both directions have both axes: **egress** (where it may go) and **ingress** (whose input
counts).

### 5.2 A resource is a list entry

A **repository** is a whitelist entry, not a remote. A topic has **no git remote**. The
platform holds **one** git credential; actions that cross the boundary — clone, pull, push,
pull request — are performed by the **gateway**; git stays in the agent's container only for
scratch-local work: `add`, `diff`, `commit`.

That is §4.1 applied to git: `add` and `commit` are inside the scope, `clone` and `push` are
crossings. And the credential never enters the agent's process, so an agent with a shell
cannot exfiltrate it.

Matching is **by repository, not by host**: a host cap would say only "github yes", which
with a platform credential means every repository that token reaches — a nominal perimeter.

A **Drive folder** is a whitelist entry, not a subtree. A shared account has **no root**:
folders arrive from "Shared with me", each owned by someone else, with no common ancestor.
There is no ceiling to set, and forcing one would either protect nothing or block
everything.

An owner may point a scope only at **already approved** resources; approving a new one is an
administrative act. **Nothing declared means no confinement** — an empty list that closed
everything would be switched off the same day, and would then protect nothing.

### 5.3 Taint

The trifecta signals — `tainted`, `private_data`, `arbitrary_egress` — stay as they are.
What changes is that they do not fire **inside the scope's perimeter**.

**Membership of the perimeter is vetted by construction.** A participant's mail does not
taint, without their address also being listed: writing it twice is the same rule in two
places, and two copies diverge — a participant removed from the topic would stay vetted
until someone remembers the second list, and nobody would notice, because a taint that fails
to fire is invisible.

This is deliberately narrow: it holds for mail, where "whose message is this" has a sharp
answer. A URL or a folder does not belong to anyone in the same way, and switching off taint
for a reason one cannot explain is worse than not switching it off.

An unfetched or unvetted source taints. An empty source list means everything taints, which
is the right direction: a source not declared is not a trusted source, and being wrong here
is **silent**.

---

## 6. Tiers

### 6.1 The weakest link

A scope's effective level is `min(data, provider, storage, channel)`, and a job's declared
tier joins that formula.

SEAL-0 Public · SEAL-1 Internal · SEAL-2 Confidential · SEAL-3 Restricted · SEAL-4
Sovereign.

Access to a scope requires clearance **≥** its tier **and** participation. Two axes, and the
second only compartments if evaluated per spawn (§3.2).

### 6.2 The provider decides the effective clearance

An agent's SEAL is **not** static and not defined by its seed: it is the **provider's**,
because that is where the data goes. The same agent is SEAL-3 on one provider and SEAL-1 on
another. The seed's `clearance` is a declared **minimum**, never a ceiling.

This holds for everyone, including super agents: nobody handles SEAL-3+ data on a SEAL-2-
provider.

Because different spawns of one seed may run on different providers, the clearance minted
into a token follows **that spawn's** provider, not the seed's. Computing it from the seed
lets a spawn moved onto a weaker provider keep the stronger clearance — the doctrine
bypassed by the mechanism meant to honour it.

A human has no provider, so their declared clearance is authoritative.

### 6.3 Caps

- **Storage**: Drive is capped at SEAL-2. Confidential data must not live on a third party
  as a live filesystem.
- **Channel**: Telegram is capped at SEAL-1.
- **Provider**: the resolved SEAL, per §6.2.
- **Job**: the declared tier, refused rather than degraded.

---

## 7. Invariants

Statements that must hold, and that a test should assert rather than a reader assume. Each
one failed once, or would fail silently if it broke.

1. **A scope owner is always human.** An agent owner unlocks its own gates.
2. **The archseed cannot be spawned.**
3. **Every gated verb has a class**, and every classified verb is actually gated. The first
   stops a verb being gated by convention; the second catches a rule that can never apply
   while looking as though it does.
4. **No gated verb is ordinary work inside a scope** (§4.1).
5. **The room comes from the signed claim**, never from an argument — in the compartment,
   in the scope role, and in the gate.
6. **A spawn ordinal is never reused.**
7. **No spawn lives outside a scope.**
8. **The agent-server cannot see the topic store.** This rests on a mount line in a compose
   file that is known to drift between the repository and the host; it must be asserted
   **from inside** — "from here the vault must be empty" — rather than inferred by reading
   mounts.
9. **The clearance in a token is the provider's**, for the provider that spawn runs on.
10. **Every authority-bearing write goes through the function that merges**, never through
    raw bytes: two writers with no arbiter is how a configuration silently doubles.

---

## 8. Failure directions

Choices about which way to be wrong, made once and applied throughout.

- **Backward compatibility goes toward "as before", not "everything closed".** A control
  that breaks working behaviour gets switched off, and then protects nothing. New
  enforcement lands in observation first.
- **Nothing declared means no confinement**, for every list. An empty list that closed
  everything would be switched off the same day.
- **Reading fails closed.** An unreadable topic makes nobody an owner and vouches for
  nobody: degrading to "authorised" on a read error turns a fault into a permission. The
  controls that failed did so by failing **open** in a branch nobody tested — an incomplete
  Drive ancestry walk must mean *outside*; an unreadable member list must mean *no rows*,
  not all rows; a row that cannot **prove** it is not a shortcut is verified, not believed.
- **A failure is not a decision.** Allowed, refused, and *we do not know* are three
  outcomes; a 5xx reported as a refusal sends the user to the wrong person.
- **A refusal names the road.** Which term blocked, who can change it, and what to do
  instead. A refusal that only says no teaches that the system says no.
- **`None` and `[]` are different.** Absent means "no opinion" and falls back; empty means
  "nothing" and is a decision. Conflating them either disconnects every existing user or
  makes a read-only user impossible to declare — and once did: a client sending `[]`
  unconditionally removed a super-agent's gates during a pack update meant only to change a
  prompt.
- **New enforcement arrives in observation first.** It decides, records what it *would* have
  refused, and blocks nothing. The destination allowlist and the gates both shipped this
  way, and both times the **recorded traffic** — not the design — produced the correct list.
  Enforcement follows measurement.
- **A silent degradation is worse than a refusal.** An agent that knows it cannot see asks;
  one that believes it has seen everything answers badly.
