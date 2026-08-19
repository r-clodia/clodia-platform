# Threat model — the lethal trifecta

What this platform defends **against**, and how each leg of the triangle is contained.
Written after the model shipped, so it describes what runs.

Companion to [`specification.md`](specification.md), which says what the platform *is* — this
one says what it is defending from, and it is the detail behind that document's §5.3. What is
specified and **not yet built** is in [`gap-analysis.md`](gap-analysis.md), which is where the
"known limits" section of this file went: two lists of unfinished work drift, and one of them
stops being read.

Reference: `#104` (the integrated spec), `#77` (the risk analysis), `#102` (the
measurement on the seeds).

---

## 1 · The threat model: the lethal trifecta

An agent is **structurally** exposed to indirect prompt injection when three
capabilities meet in the same flow:

| | |
|---|---|
| **private data** | it can read things that must not leave |
| **untrusted content** | it ingests text nobody on our side wrote |
| **external write** | it can send something out |

With all three, a hidden instruction inside the untrusted content can ask the
agent to read the private data and push it out — and the agent, doing exactly what
it was built to do, complies. There is no prompt that fixes this: the model cannot
distinguish an instruction from the data it was told to read.

**What we do NOT claim to solve.** Prompt injection itself is unsolved, and this
model does not solve it. It makes the *flow* fail to close, which is a different
and achievable goal. Two consequences worth stating out loud:

- **Inference is an egress too.** Every turn sends private data to the provider.
  This model constrains egress toward destinations *the agent chooses*, not
  toward the engine. An injection can make the data appear in the reply, which
  lands in the channel where participants read it. That case is covered by the
  two-axis access model (clearance **and** compartment), not here.
- **A confined network reduces by orders of magnitude, it does not zero.** The
  minimum allow-list has four channels — inference providers, the gateway,
  GitHub, package registries — and each one is in principle a vehicle: a gist, an
  issue comment, a published package.

---

## 2 · Five principles

Everything else in this document is a consequence of these. If a future change
contradicts one of them, that is the thing to discuss — not the mechanism.

**1. The flow matters, not the actor.** Risk exists when the three capabilities
meet in one flow. The defence prevents the flow from closing; it does not try to
strip agents of capability. An agent that can do nothing is safe and useless.

**2. Structural over procedural.** A control must hold when nobody is watching.
Closed network and DNS rather than environment variables that only cooperative
clients honour; signed claims rather than parameters; decision state on a volume
the agents do not mount; deny that beats allow. An agent must not be able to
rewrite its own limits.

**3. Ask a human only where a human adds information, and only when one can
answer.** A gate approved by reflex is worse than no gate: it manufactures the
appearance of control. So gates are conditioned on contamination, deduplicated
against each other, and replaced by a refusal where nobody is present.

**4. Errors have a preferred direction: noisy, never reassuring.** An unknown verb
namespace is assumed dangerous. An unreadable destination is refused. A file with
no provenance label reads `unknown`, never `trusted`. A confinement that is not
enforced is not counted as confinement.

**5. Measure what runs, not what is declared.** The danger score is computed from
effective grants. The verb register records what was actually invoked. Three times
during implementation the measurement was corrected — every time in the direction
that made the numbers worse and truer.

---

## 3 · The context vector

The unit of evaluation is **the context** (a channel, a DM), not the agent. A
channel's profile is the OR over its transitive closure: participants plus agents
reachable by whoever can widen the composition.

Three bits:

```
1 0 0   untrusted content HAS ENTERED this channel
0 1 0   someone here can read private data
0 0 1   someone here can write to an external system
```

**The first bit is an event; the other two are properties.** That asymmetry is
what makes the model livable: `111` is exited by clearing the only bit that is an
event — a human declassifying — because the other two cannot be switched off
without dismantling the channel. It is also why approval *must* clear the taint:
otherwise `111` would be absorbing and the channel would die there.

**The second bit is almost always set.** Private data is not just files: a topic
channel *is* private data — its conversation, its summary, its messages. Any agent
that can participate already has it. So the operative rule is two bits:

> **contaminated AND egress-capable → ask a human.**

The per-agent score is an intermediate step, not a metric. Only the context's
counts.

### Two numbers, not one

`score` is the **capability**: the agent does hold those verbs, and saying
otherwise would be the one lie this measure cannot afford. `residual` is what is
left once the *applied* confinement is accounted for — egress counts only when it
is arbitrary. A confinement that is not enforced is not counted: reporting `report`
mode as confinement would lower the score of an agent that can still send freely.

`egress_scope` says which: `none`, `presided` (a human stands between the agent
and any new destination), `listed` (declared destinations only), `arbitrary`.

### The shell is a separate flag, not a fourth bit

An agent with bash does not make a channel riskier — it makes the control
**bypassable**, because `curl` never reaches the gateway. Different property,
shown differently. It is why network confinement came before everything else, and
why gating verbs is only meaningful *because* the network is closed.

---

## 4 · How each bit is contained

### Bit 1 — untrusted content: tracked, not removed

It has no chokepoint: it arrives through the prompt too. So it is not removed, it
is **labelled**.

- **Untrusted = what enters without a human in the loop**: pages an agent read,
  incoming mail, third-party messages, GitHub issues and comments, external MCP
  output, files an agent downloaded. **The authenticated UI user is trusted** — if
  the owner's own prompt is suspect there is nothing left to defend.
- **Taint is born in the gateway**, after a verb returns and only on success: the
  content has actually entered the context, not merely been requested. Both
  dispatch paths are marked, including the proxied one — GitHub and external MCPs
  go through it.
- **The flag lives on the channel**, defined as *untrusted content entered after
  the last unlock*. It does not cross channels, and the **sources are recorded**:
  "the channel is tainted" is not actionable, "an untrusted PDF came in" is.
- **Files declare their provenance at upload.** The UI asks where the file comes
  from — the only moment that information exists, and the only party who can
  answer is the user. It is a *classification, not an authorisation*: reading
  stays free and taints the channel. A block would teach the user to answer
  "trusted" to get on with it, which is how the label becomes useless.

**No cross-channel propagation** — decided, and it holds *because* there is no
cross-topic data path other than hooks. ⚠️ If one is ever reopened, that decision
must be made again from scratch: the taint does not spill by design, not by a
property of the mechanism.

**Not implemented: a trusted-source list.** Today a read taints regardless of
where it read from. A source list would make bit 1 much rarer, but getting it
wrong is *silent* — a taint that never sets makes the flag lie, and no gate
downstream fires. If added: at resource level and never at host level (trusting
`github.com` is wrong by construction — anyone writes the issues), never for
user-generated content, and as instance configuration rather than something
approvable in a dialog. An injection asking "add this domain to the trusted
sources" must have nowhere to land.

### Bit 3 — external write: confined, then presided

- **Network confinement.** The agent container sits on an `internal` network: no
  route out except the gateway, and a process inside cannot undo it. **DNS is
  closed too** — only internal names resolve, so the covert channel inside DNS
  queries is shut by construction. Measured, not assumed.
- **Destination whitelist** per agent and per channel type (email, telegram, http,
  drive, gsheets, github by repo), living in the **gateway's own config** — not in
  `agent.yaml`, which sits on the datadir where agent code runs.
- Three deny-by-default rules: an **unmodelled channel type** is refused rather
  than free; a **declared-empty** type is muted (kept distinct, because "never
  configured" and "deliberately muted" call for opposite fixes); an **unreadable
  destination** is refused — `email.reply` takes its recipient from the message
  being replied to, i.e. from untrusted content, and "attacker mails in, agent
  replies with the data" is the injection path itself.
- **A new destination asks, and approving remembers it** — and the dialog says so,
  because approving is more privileged than the single send. No pre-signed
  delegation may cover that gate.
- ⚠️ **Not implemented: fine-grained credentials per seed.** A per-seed PAT limited
  to the allowed repos would put the whitelist *in the credential*, so it would
  apply to `git push` from a shell too — and could not be forgotten. Until then,
  repo confinement is policy-level only.

### The context gate

The verbs that light the third bit are not taken away: they stay declared and
**inert**, and their invocation *in a contaminated channel* passes a human. Not on
capability alone — that would fire on almost every channel.

The deduplication is evaluated on the gate that **will actually stop in front of a
human this turn**, not on the verb's membership of a list. A new destination
already shows the call to someone, so the context gate stays quiet; a destination
already whitelisted shows it to nobody, so it fires — and that is exactly the
residual the whitelist cannot cover: egress toward a *legitimate* destination of
data collected under injection.

**A composition change invalidates active unlocks**, implemented by putting the
composition inside the gate key. No revocation sweep to forget, which is the only
way it cannot be forgotten.

### Unattended sessions

A job is not defended by gates, because **nobody can answer**: a gate in an
unattended session is a stall until timeout. Keyed on a signed claim the agent
cannot remove, a scheduled session loses every `topic.*` verb except
`topic.invoke_hook`, and the egress mode `gate` becomes a refusal. A destination
already approved by a human still works, which is how jobs stay useful.

---

## 5 · Two verb groups per agent

Least authority is achieved by **supervision, not removal**: a verb taken away
from an agent is a verb the owner must perform; a gated verb is one the agent
performs with approval. Same human involvement, nothing broken.

- **ungated** — reads, and writes that stay inside the perimeter.
- **gated** — egress, and privileged mutations.

The split is **per agent**: `email.send` is gated for clodia and free for the
messenger, because for a postman sending *is* the job while for clodia it is an
exception. Reads are never gated: a dialog with only one sensible answer trains
the reader to click.

`denied_tools` is a third, smaller case, and its reason is not the score: some
verbs are **not chat-turn operations** at all — `mcp.add`, `packs.install_*`,
`settings.backup_run`. Those are not gated, they are moved elsewhere (the Packs
page, a job). Deny beats allow, super-agents included.

---

## 6 · Observation before enforcement

New enforcement lands in observation first — see `specification.md` §8, where this is stated
once as a general failure direction rather than repeated per control.

## 7 · Findings carried over from the rc5 reset

The rc5 reset closed 52 issues. Five of them were **security findings recorded
nowhere else** — [#175](https://github.com/r-clodia/clodia-platform/issues/175)
kept them alive on the condition that each be re-measured against rc5 and then
written down here, reopened, or dismissed *with the measurement that dismisses
it*. Never dropped silently: a backlog reset that reads as progress is the
failure mode #175 exists to prevent.

This is that measurement, taken on **19 August 2026** against `main` of
`clodia-platform`, `clodia-logic` and `clodia-web`. Two of the five cannot be
decided from here at all, and saying so is part of the result: the credential
store, the per-connector ACL and the on-behalf gate check live in
`clodia-tools`, and that repository was **not reachable** from the room where
this was measured. A row that reads "not measurable" is not a row that is fine.

| was | finding | state on rc5 | measurement |
|---|---|---|---|
| [#68](https://github.com/r-clodia/clodia-platform/issues/68) | connector credentials are *platform* identities: topic and user ACLs have no grip on the external data | **open — not measurable here** | the credential store and every per-connector ACL live in the gateway. What is verifiable from this side is only that the agent plane holds no copy: provider credentials arrive over HTTP (`clodia-logic/server/api/provider_store.py`) and `/datadir/clodia-vault` is blanked by a `mode=0` tmpfs on the agent container (`docker-compose.yml`, agent-server `tmpfs:`). That says the secret is not *here*; it says nothing about whose identity it is when used |
| [#80](https://github.com/r-clodia/clodia-platform/issues/80) | the agent-server can rewrite the gateway's decision state on the shared `/datadir` → self-escalation from the inside | **closed by construction** | the decision state moved off the shared datadir: `CLODIA_TOOLS_STATE_DIR: /gateway-state` and the bind `${CLODIA_GATEWAY_STATE:-./gateway-state}:/gateway-state` appear **only** on the `clodia-tools` service in `docker-compose.yml`; the agent-server's volume list has no `/gateway-state` entry, and its comment names this issue. Already carried in `SECURITY.md` §8.2 / §8.9. **Dismissed with this measurement**, not by assumption |
| [#148](https://github.com/r-clodia/clodia-platform/issues/148) | on-behalf requests skipped gates and the destination whitelist, on the rationale that any authenticated UI user is trusted | **open — half measured, and the half that shows is not reassuring** | the rationale is gone on this side: a human action from the UI no longer authorises itself, it asks the gateway with the same RBAC as an agent (`clodia-logic/server/api/gateway_pdp.py`, `gw_authorize` / `gw_tool`, token minted with `on_behalf=True` and a **signed** `human_role` claim). Whether the *gateway* then applies gate and destination whitelist to an on-behalf token is decided in `clodia-tools`. What is measurable here is adjacent and points the wrong way: on-behalf still confers human standing at ingress — a proxy token is on-behalf, and its message persists as `kind: human`, which `clodia-logic/server/api/channels.py` (`_from_human`) now refuses to believe as a declared bridge (#221, #248) |
| [#149](https://github.com/r-clodia/clodia-platform/issues/149) | a Drive grant is silently also a mail grant: the unified Google credential re-grants `email.*` through `_connector_allows` | **open — not measurable here** | `_connector_allows` appears **nowhere** in `clodia-platform` or `clodia-logic` (grep, 19 Aug 2026): the unified credential and the re-grant it implies live entirely in the gateway. One consent, two authorities — until read there, this stands |
| [#108](https://github.com/r-clodia/clodia-platform/issues/108) | artifact CSP `img-src https:` allows exfiltration by GET from the owner's browser | **was still true — fix open** | measured live at `clodia-web/src/lib/artifact-frame.ts`: `img-src data: blob: https:`, and the same `https:` on `style-src`, `font-src` and `media-src` — closing only `img-src` moves the channel instead of closing it, since `<video src>` and a remote `@font-face` make the same GET. r-clodia/clodia-web#175 drops all four and adds `scripts/check-artifact-csp-no-remote.mjs`, which is red on the current state. This row closes when that merges |

**What is left to finish #175**, stated so it does not dissolve into "we looked
at it": #68, #148 and #149 need the gateway repository inside the perimeter of
whoever measures them, and each then ends as its own issue or as a row in this
table. #108 closes with a merge. #80 is done.

## 8 · Known limits

Moved to [`gap-analysis.md`](gap-analysis.md).
