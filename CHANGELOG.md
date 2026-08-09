# Changelog — Clodia Platform

Changelog centrale della **piattaforma Clodia**, prodotto modulare unico composto da quattro moduli versionati con **tag globali coordinati**:

- **`clodia-logic`** — backend / agent-server (agenti, job, topic & canali, routing, auth/PKI, API)
- **`clodia-tools`** — gateway (MCP tools, vault/credenziali, connettori, provider di inferenza)
- **`clodia-web`** — web UI (SvelteKit)
- **`clodia-pwa`** — app installabile (PWA)

Formato ispirato a [Keep a Changelog](https://keepachangelog.com/); versionamento SemVer a livello di piattaforma. ⚠️ = breaking / migrazione richiesta.

---

## [9.0-rc3] — 2026-08-09

> Milestone 2: **the identity arrives where the decision is taken**, and the two
> invariants that nothing asserted now hold somewhere that can fail.

### Identity in the signed claim

- **A spawn writes in its own scratch, and in nobody else's.** The token had
  carried an `execution_id` field from the beginning and **nobody filled it** —
  so the gateway knew the seed and not the instance, and any spawn could write
  into any other's directory, including another spawn of the same seed. Entry 2
  of the record promised this; the code did not deliver it.
- **A job's tier travels**, and with it the last line of the model that was
  *written and not enforced*: for a job `current_channel()` is None, so "a
  carried topic travels only where the room can hold it" simply did not apply
  there. It allowed and logged — because the gateway did not know the tier, not
  because the case was harmless.

### Portability changes sides

Declared by the **topic**, not by the seed. `carries` on a seed meant "the topics
this agent takes with it", and an agent that adds a topic to its own list **gives
itself a channel** between rooms. Two conditions now, not one: the topic declares
itself portable **and** the caller participates in it. Declaring it is an act on
the walls, so it belongs to the owner.

Measured before moving: **nobody used `carries`** on either instance, so this
migrates nothing.

### The two invariants

- **A scope owner is always human.** Since rc2 the owner unlocks their scope's
  gates, so an agent-owned scope would unlock its own. What is known to be an
  agent is refused; what is not recognised is not — refusing the unknown would
  turn a gap in the registry into a topic with no owner.
- **A spawn cannot reach the vault, the topic store or the seeds** — and
  measuring it showed the invariant was **formulated wrong**. It said "the
  agent-server cannot see the topic store", true on the personal stack where a
  compose mask hides it and **false on venere**, where the process runs as root.
  A test on that wording would have gone red over a configuration difference
  rather than a security property. What holds on both is the spawn-level
  boundary, and the **kernel** holds it. Now asserted from inside, at boot, with
  three outcomes: reachable, denied, and *not verifiable*.

### Also in this cycle

- The **archseed** became a real seed of the base-pack rather than a tuple in the
  gateway — a seed is a file, read, diffed and reviewed in a pull request.
- The **fourth sync**: seeds now arrive from the pack on an instance already
  running. Skills, rules and constitutions did; seeds did not, and it showed the
  hour the archseed was deployed and did not appear.
- `parents` stopped being genealogy. `sysadmin` declared `parents: [clodia]`,
  written when nothing resolved the field; the moment inheritance became real
  that line granted it **33 verbs**. A dangling ancestor is now refused: one
  missing today is a permission arriving tomorrow.
- The **trifecta scored declarations rather than effective verbs**, so tidying the
  seeds dropped `segretario`'s risk from 2 to 0 — a safety signal falling because
  a file got cleaner.
- **Nobody bypasses the whitelist by name any more.** `ophelia` left the last two
  super sets; while even one name stays in, the matrix is never really the
  document that decides.

### ⚠️ Migration

`ophelia` drops from the wildcard to the archseed's base verbs. `[]` means "no
trade declared yet", not "no verbs": reading, speaking and its own memory arrive
by inheritance. The seed-by-seed review is separate work.

### Not in rc3

`CLODIA_ORIGIN_ENFORCE` is still `report` and `source_allow` is still empty. Five
gaps remain, the largest being mounts with the owner's own credential.

---

## [9.0-rc2] — 2026-08-08

> Milestone 1 of the gap analysis: **what a seed declares, and where that
> declaration is read**.

### The archseed

Every seed now descends from an **abstract seed that cannot be spawned** and
holds the base verbs — its own memory, the reading floor of the scope it stands
in, and speaking there. Writing, moving the walls and leaving stay trade, and
trade belongs to the seed. The parent is a **default, not a ceiling**;
containment comes from the gates, the scope's lists and the chain's
intersection.

Measured on venere before and after: everyone gains **reading and speaking
only**. Nobody gained a write or a crossing verb — `segretario` went from 4 to
10, all reads plus `post_message`. That the floor is reading rather than
`topic.*` is exactly why.

`abstract: true` is enforced in the single creation choke point, so it covers
chats and jobs together, and it fires before anything is allocated.

**Every verb says where it comes from** — `own`, the ancestor that contributes
it, or `archseed` — and a denied verb stays visible and marked rather than
disappearing. Without provenance, inheritance would have traded a duplication for
an opacity, and the opacity is worse: a duplication you can see.

### The finding that mattered more than the feature

The verb matrix was read in **three** places and they did not agree —
`main._declared_tools`, `origin._agent_may` and `whitelist.tool_allowed`, and the
third did not consult `denied_tools` at all. It answered "allowed" on a verb the
other two refused. Grafting inheritance onto one would have produced a verb
allowed by one path and refused by another, invisibly, because nobody compared
the three. They now share one function, and a test compares the three outcomes
verb by verb.

The universal namespace is gone with its reason: `memory.*` comes from the
archseed, which makes it **visible** and **subtractable** — neither of which was
possible while it was implicit.

### ⚠️ Migration

**Agents narrow on purpose become wider by the archseed's floor.** Reading and
speaking only, but it is a change: if a seed must stay narrower, `denied_tools`
subtracts and beats inheritance. Measured per agent on venere; no verb of
consequence was gained.

### Fixed

- **The baked `config.yaml` is read-only.** Running the config loader locally had
  rewritten it through `yaml.safe_dump`, dropping 109 lines of comments that
  documented `gdrive_roots`, the super wildcard and the deliberate cost on
  `gcalendar`; `git add -A` then carried the stripped file — and an abandoned
  migration with it — into an unrelated PR (1.56.0). Comments restored, the
  default now refuses to be written and says so, and the residue the migration
  had written into venere's runtime config was cleaned with the outcome verified
  unchanged for all eight agents.

### Not in rc2

`ophelia` losing `super` is built and **not deployed**, pending an explicit
go-ahead: it is the one step that could stop the instance from starting. It moves
to rc3. Measured meanwhile: the risk was smaller than flagged — the *service*
identity that mints tokens for humans is `clodia`, not `ophelia`.

---

## [9.0-rc1] — 2026-08-07

> **Release candidate.** The model is in place and running on venere; the enforcement switch is
> deliberately still off. Read *Not in rc1* before treating this as 9.0.

Where 8.0 enforced the lethal trifecta, 9.0 answers a different question: **what is a scope, and
what standing do you need to cross its boundary?** It comes out of a full specification dictated
one definition at a time (`docs/decision-record.md`, entries 20–33; the consolidated form is `docs/specification.md`), each recorded with the
measurement that confirmed or refuted it — and several were refuted.

### The model

- **A gate is not a property of a verb.** It is what happens when an action crosses a boundary, or
  when the caller lacks standing. The 28 gated verbs now carry a class — `system` (the rules of the
  machine), `walls` (the boundary of a scope), `outward` (leaving) — with a completeness test so a
  new verb cannot be gated by convention again.
- **The scope's owner unlocks its own gates.** `walls` and `outward` are decided by the owner of the
  scope being crossed, not by any platform admin. An admin does not substitute the owner: if they
  did, the owner's authority would be decorative.
- **Membership is graded** — owner, contributor, reader — and the role is a third term in the
  authority intersection, alongside the profile matrix and the agent's verbs. A reader reads and
  speaks; speaking is not mutating.
- **Access belongs to the spawn, not to the seed.** One seed participating in 135 topics used to
  mean any of its spawns could read all of them from any room. Now the room you stand in decides,
  and it arrives in a signed claim.
- **Humans are spawns of two seeds**, `admin` and `member`, so the verb matrix lives per class
  instead of per person.
- **The perimeter is per scope.** Egress and ingress lists gained a second axis, and membership of
  the perimeter counts as vetted by construction — a participant's mail does not taint, without
  being listed twice.
- **Resources are list entries, not attachments.** A repository and a Drive folder are approved
  entries in the scope's list; neither is a remote bolted onto a topic.
- **One file view.** `local/` and `remote/` are two mounts in a single tree, and the control plane
  (`meta.json`, `summary.md`, `AGENTS.md`) has no path inside it.
- **A job declares a tier**, and a run whose agent sits on a provider that cannot carry it fails
  with an error instead of degrading silently.

### ⚠️ Migration

1. **`AGENTS.md` moves from a topic's files to its control plane.** On local topics any participant
   could previously overwrite the instruction file injected into every turn; on Drive topics the UI
   showed one file while the system injected another. Migration is automatic on first access.
2. **A human with no matrix of their own now falls back to their seed** rather than to "everything
   not gated". Measured on venere: nobody loses a verb today. It bites when origin enforcement is
   turned on.
3. **Ten channel endpoints became role-guarded.** An invitee could reset a channel's conversational
   memory and upload the `AGENTS.md`. Legacy participant lists read as `contributor`, so nobody is
   silenced by the migration.
4. **The scopeless default chat is retired.** It was a live session with `topic: null`, exempt from
   the reaper, and the one place where the per-scope machinery degraded silently to the global list.
   DMs cover the use case and are real scopes.
5. **Spawn ordinals are persisted and never reused.** On an instance already running, numbering
   continues above the highest live spawn rather than restarting.

### Shipped and repealed inside this cycle

Stated rather than quietly dropped, because both were deployed and are gone:

- **The per-scope git credential** (tools 1.42.0) — repealed on 7 Aug: the git credential belongs to
  the platform, and confinement comes from the scope's list of approved repositories instead.
- **The git remote as a mount** (tools 1.42.1 corrected it to "not a filesystem") — the concept of a
  git remote on a topic is repealed altogether.

### Not in rc1

- **`CLODIA_ORIGIN_ENFORCE` is still `report`.** The chain observes and blocks nothing. Turning it
  on is the one change that removes capability rather than adding it, and it does not happen without
  saying so first.
- **`source_allow` is empty**, so the taint flag stays on for everything.
- **The archseed** (notebook entry 10b) is specified and not implemented.
- **Trello and workflows** are still half-removed; the completeness test added for the gate classes
  found three `workflows.*` verbs left behind.
- **The configuration topic** is repealed for now; what shipped of it is inert.

---

## [8.0] — 2026-08-03

> ⚠️ **Major release: this one changes what agents are allowed to do.** Three
> behaviours break an instance already in service — read *Migration* before
> upgrading. Nothing changes in an API contract or a data format; what changes is
> the policy the platform enforces, and it changes enough to warrant the major.

Where 7.1 **measured** the lethal trifecta, 8.0 **enforces** it. The model of
`clodia-platform#104` ships whole: outbound traffic is confined to declared
destinations, untrusted content is tracked instead of assumed away, the third leg
of the triangle costs a human approval, and an unattended job cannot touch topic
data at all. The measurement was also corrected twice along the way — twice in a
direction that made the numbers *worse and truer*.

### ⚠️ Migration

1. **Scheduled jobs lose access to topic data.** A job whose prompt reads a topic
   now fails. The only remaining path into a topic from an unattended session is
   `topic.invoke_hook`. Rewrite such jobs to push information rather than read it.
2. **Outbound destinations must be declared.** The egress whitelist starts
   **empty** and the default mode is `gate`: in a chat, the first send to a new
   destination asks for approval and remembers it; **in a job it is refused**, and
   the refusal happens at the next fire rather than at deploy. Either let the
   destinations accumulate through use in chat, or declare them up front in the
   gateway config (`egress_allow`). `CLODIA_EGRESS_ENFORCE=report` restores the
   old behaviour while logging what would have been refused.
3. **`mcp.add`, `packs.install_*` and `settings.backup_run` are no longer
   chat-turn operations** for `clodia`/`ophelia`. Install packs from the Packs
   page; run a backup from a job.

Also behaviour-changing, without breaking anything: uploaded files default to
`untrusted` and taint the channel, several seeds lost verbs (§8 below), and the
danger score of most agents **went up** because the catalogue stopped assuming
unknown verbs are harmless.

### 🔒 Egress: from a binary capability to a circumscribed one

"Can send email" used to mean "to anyone", so exfiltration was one line of
prompt away.

- **Network confinement.** The agent container sits on an `internal` network: no
  route out except the gateway, and a process inside cannot undo it. Measured
  along the way: **DNS is closed too** — only internal names resolve, so the
  covert channel inside DNS queries is shut by construction rather than by a
  separate rule. `internal: true` also disables host port publishing, which is
  why the API is now fronted by an nginx ingress.
- **Destination whitelist** per agent and per channel type (email, telegram,
  http, drive, gsheets, github by repo), living in the **gateway's own config** —
  not in `agent.yaml`, which sits on the datadir where agent code runs: whoever
  can rewrite the whitelist grants themselves destinations.
- Three deny-by-default rules, each one the reason the whitelist is not
  decorative: an **unmodelled channel type** is refused rather than free, a
  **declared-empty** type is muted (kept distinct, because "never configured" and
  "deliberately muted" call for opposite fixes), and an **unreadable
  destination** is refused. The last one exists because `email.reply` takes its
  recipient from the message being replied to — that is, from untrusted content.
  "Attacker mails in, agent replies with the data" is the injection path itself.
- **A new destination asks, and approving remembers it.** The dialog says so:
  approving is more privileged than the single send, because it makes that
  destination silent from then on. A pre-signed delegation cannot cover this
  gate — it would make a new destination silent without anybody ever seeing it.

### 🧪 Taint: untrusted content is tracked, not assumed away

- **Contamination flag per channel**, defined as in #77: *untrusted content
  entered after the last unlock*. The unit is the channel, not the spawn — with
  multi-spawn, four instances of a seed share a room. The **sources** are
  recorded and not just the boolean: "the channel is tainted" is not actionable,
  "an untrusted PDF came in" is.
- **Taint is born in the gateway**, after a verb returns and only on success.
  Both dispatch paths are marked, including the proxied one — GitHub and external
  MCPs go through it, and marking only the native return would have left exactly
  the Invariant Labs vector uncovered.
- **File provenance at upload.** The UI asks where the file comes from: it is the
  only moment the information exists and the only party who can answer is the
  user. It is a *classification*, not an authorisation — reading stays free and
  taints the channel. A block would teach the user to answer "trusted" to get on
  with it, which is how the label becomes useless. Both options carry the same
  weight, there is no preselected default, the question is asked once per batch,
  and cancelling uploads nothing. A file with no label reads `unknown`, never
  `trusted`.
- **No cross-channel propagation** — decided, and it holds because there is no
  cross-topic data path other than hooks. If one is ever reopened, the decision
  must be made again from scratch.

### 🚪 The context gate

An agent lives at two legs. The verbs that light the third stay declared and
**inert**, and their invocation *in a contaminated channel* passes a human. Not
on capability alone: that would fire on 150 channels out of 156.

The deduplication is evaluated on the gate that **will actually stop in front of
a human this turn** — not on the verb's membership of the gated list. A new
destination already shows the call to someone, so the context gate stays quiet; a
destination already whitelisted shows it to nobody, so it fires. That case is the
residual risk the whitelist cannot cover: egress toward a *legitimate*
destination of data collected under injection.

"A composition change invalidates active unlocks" is implemented by putting the
composition **inside the key**, so adding a participant makes the previous unlock
stop matching. No revocation sweep to forget, which is the only way it cannot be
forgotten.

### 🤖 Unattended sessions

A job is not defended by gates, because **nobody can answer**: a gate in an
unattended session is a stall until timeout. Keyed on a signed `unattended` claim
the agent cannot remove, a scheduled session loses every `topic.*` verb except
`topic.invoke_hook`, and the egress mode `gate` becomes a refusal. A destination
already approved by a human still works, which is how jobs remain useful.

### 🎚 Least authority per seed (§8)

Applied to the running instance **and** to the pack seeds, so a fresh install is
born reduced. The three documentaries (`avvocato`, `commercialista`,
`esperto-bandi`) went from 29 verbs to 14 and **from 3/3 to 2/3**;
`fullstack-dev` lost `fs.list_dir` (it has a shell, so the verb adds nothing and
counts a leg); `impiegato-tomato` lost `runtime.*` and its writes are now gated;
`segretario` lost the topic file readers, since it minutes the conversation, which
arrives in the prompt.

`security-engineer` **gained** the topic file readers: passing it code in chat was
unsustainable, and it remains the best profile in the colony — it reads hostile
code with no egress and no shell.

Two new PDP mechanisms were needed to express this. **`denied_tools`** subtracts
verbs from a wildcard: `clodia` keeps its `*` (enumerating it would make the score
stale at the first new pack) and loses the verbs that are not chat-turn
operations. **`gated_tools`** gates a verb *for one agent* — the same verbs stay
free for others, so the granularity cannot be global. Deny wins over allow,
super-agents included.

**Attach by reference** made the messenger reduction possible: `email.send` takes
`topic_files`, the gateway reads them and attaches them, and the content never
enters the agent's context. Telegram already worked this way.

### 📏 The measurement, corrected twice

- **The catalogue is fail-closed.** An unknown verb namespace used to light
  nothing: an agent whose only grants were `slack.post_message` and
  `dropbox.upload` scored **0/3** while it could exfiltrate. Unknown namespaces
  are now assumed able to read private data and to send it out. On the first run
  it immediately found two real gaps (`jobs.*`, `app_runtime.*`, flagged on 148
  and 145 channels). This is also why enumerating `clodia`'s `*` was withdrawn:
  enumeration makes the score stale, the wildcard keeps it truthful.
- **The score distinguishes circumscribed egress from arbitrary egress.** `score`
  stays the capability; `residual` is what is left once the *applied* confinement
  is accounted for. A confinement that is not enforced is not counted — it would
  lower the score of an agent that can still send freely.
- **The score understands grant negations**, found by measuring right after §8
  went in: the reductions were enforced by the PDP and invisible to the score.
  A number describing a different system from the one that runs is the worst
  divergence available.

### 📖 Verb telemetry

Append-only register in the gateway, on by default — an opt-in register does not
exist on the day it is needed. **Metadata only: verb, agent, channel, outcome,
context flags. Never arguments**, and refusal reasons as a *class* rather than a
message: an address is an argument, and the reason this file exists does not
justify turning it into an address book. It answers "what does this agent
actually use" and "how often did we refuse" — which every measurement in this
epic so far could not, because all of them were declared capability rather than
observed action.

### 🔧 Also in this release

- **Google Sheets** (`gsheets.*`): incremental verbs — `add_tab` adds a tab to an
  existing spreadsheet without touching the others, which the file-level
  connector could not express (its only path was download + re-upload, which
  destroys every tab the agent did not author). `read(formulas=true)` returns
  formula text: found in the live check, where writing `=SUM(B1:C1)` and reading
  it back returned `0` — a read that is lossy exactly where a formula lives, and
  silently.
- **Drive-backed topics**: subfolders are navigable in the topic file view again.
  A Drive folder's mime matched the "native Google document" prefix, so every
  subfolder was emitted as a remote *file* with a link, and navigation stopped at
  the first level. Opening Drive stays available as an explicit `↗`.
- **An unreachable topic remote says so** (424 with the reason) instead of
  showing an empty folder, and a revoked Drive token no longer takes down the
  whole topic list.
- **Pack reconciliation reports at boot instead of acting.** The boot turn needed
  verbs that are gated by definition, from a session with no channel, so every
  attempt surfaced as a consent popup with no conversation to answer it in. It
  now records what is pending and the operator starts it from the Packs page.
- **Bedrock**: the provider catalogue accepts the inference profiles it requires
  (`eu.anthropic.*`), and the compatibility check reads the declared model rather
  than the translated one.

---

## [7.1] — 2026-08-02

> From this release on, changelog entries are written in **English**: the
> platform repos are open source and the audience is not Italian. Earlier
> entries are left as they were written.

Minor release driven by **security posture**: the lethal trifecta gets measured
instead of guessed, the gateway's decision state leaves the volume it shared
with the agents, and seeds lose the one verb that let any of them pull any agent
into a channel. Ships also **multi-spawn participation** (a seed can now work as
N concurrent instances), **inference stacks** (a seed can hold more than one
(model, provider) pair) and **actionable notifications** in recent topics.

### 🔺 Lethal trifecta: measure, then reduce

The three capabilities that make an agent structurally exposed to indirect
prompt injection — private data, untrusted content, external write — are now
**computed from the effective grants**, not declared.

- **Danger score per agent and per context**, as the OR over the channel's
  transitive closure (participants + agents reachable by whoever can widen the
  composition). Shell is a **separate flag, not a fourth side**: it does not make
  a channel riskier, it makes the control *bypassable* (`curl` never reaches the
  gateway). Exposed on the topic and shown in the UI with a per-side, per-agent
  breakdown — the number alone is not actionable.
- **Verb classification is versioned configuration** (`catalogs/trifecta.yaml`),
  refined by review instead of hard-coded. The v2 pass realigned it to the
  gateway's **actual** verb list: `fs.list_dir` was a false positive (it lists a
  directory inside the agent's own workspace, never file contents), the
  third-party connectors were **not classified at all** (Calendar, Docs, Trello,
  image generation, pack installs — all writes that leave the instance), five
  exceptions pointed at verbs that do not exist, and `email.reply` — which sends
  in-thread **with attachments** — did not light up egress at all.
- **Instance overrides merge, they no longer replace**: a partial override
  declaring only `egress` used to zero the other two sides, reporting a genuinely
  3/3 agent as 0/3. False reassurance is the one direction this measure cannot
  afford.
- **`topic.add_participant` removed from every seed except the two supers**, by
  expanding the `topic.*` wildcard into its 26 remaining verbs. Composing a team
  stays gated even for the supers, and human principals are unaffected — they add
  participants through an endpoint that never touches the agents' PDP. Side
  effect worth having: a *future* `topic.*` verb is no longer granted implicitly.

Measurement is deliberately separate from enforcement: **nothing is blocked by
this release**. Context gates, taint tracking and per-seed egress allow-lists are
specified but not shipped.

### 🛡️ Control plane isolated from the agents ⚠️

Per-agent whitelists, gate consents and delegations **are** the reference
monitor's authorization decisions, and they used to live on the datadir the
compose mounts **into the container where agents run**: rewriting your own entry
granted you a tool, and later calls passed "legitimately" because the *state* had
been tampered with, not the control bypassed.

They now live in a directory owned by the gateway alone
(`CLODIA_TOOLS_STATE_DIR`, mounted only by the `clodia-tools` service). Legacy
copies migrate once, and the state directory is inside the restic backup
perimeter — isolating it would otherwise have quietly dropped it from backups.

⚠️ **Deployment action required**: the volume and the environment variable must
be added to existing compose files; without them the code keeps the previous
behaviour (no breakage, no protection either). Known gap: migration is currently
lazy, so it should be forced at gateway startup — see platform issue #112.

### 👯 Multi-spawn participation

A seed can declare `multi_spawn` and materialize **N concurrent instances** in
one context, addressed by ordinal (`@agent#2`):

- a generic mention goes to the **lowest free ordinal**; if all are busy a new
  instance is **forked**, up to `max_spawns`, then work queues on the lowest;
- **only ordinal #1 writes the seed memory** — the others receive a read-only
  snapshot, so concurrent instances cannot race on `MEMORY.md`;
- mentions with ordinals are parsed into the message's structured `mentions`
  field, and delegation compares by *seed*, so `agent#2` mentioning `@agent`
  does not delegate to itself;
- the Participants panel shows a **tree of live instances** with a status light,
  served by an endpoint scoped to channel members and closed to four fields
  (`agent`, `instance`, `label`, `state`) — presence, never work: an instance may
  be running in a topic classified above the viewer's clearance.

Verified in production with four concurrent instances of one seed.

### 🧠 Inference stacks: one seed, N (model, provider) pairs

The old model was "one seed, one LLM; one LLM, N providers". A provider could
already serve a different model, so the assumption was already broken in
practice. It is now explicit:

```yaml
stacks:
  - { model: gpt-5.6-sol, provider: codex }
  - { model: claude-opus-5, provider: claude-team }
```

Legacy fields keep working and are normalized in both directions — the old model
is a special case of the new one, so no migration is needed. The UI picks a
**stack**, and cards, tables and profile show the **effective** model instead of
the top-level one, which used to lie whenever a fallback was active. Topic turns
also pick the cheapest provider eligible for the topic's tier.

### 🔔 Actionable notifications in recent topics

The badge counted every new message, which turns a notification into noise. It
now lights up **only for items that wait for you** — unread mentions addressed to
you, plus workflow gates assigned to you — and counts *items, not messages*.
Ordinary traffic gets a small neutral dot with no number.

- computed **per principal**, never shared: a topic you do not participate in is
  absent from the response, not reported as zero;
- authorization is re-evaluated on every call, so revoking a grant removes the
  badge immediately;
- visiting a topic clears the dot but **not** the gates: a gate is not an unread
  message, and it goes away only when resolved or reassigned;
- mentions are matched against a **structured** field written at post time, not a
  regex over raw text — escapes, code blocks and quoted lines no longer produce
  false mentions.

### 💬 Topic UX

- **One box per agent** for reasoning and tool calls, in sequence. Two data bugs
  made the feature impossible before: the expand state was a single page-wide
  variable (opening one agent's reasoning opened all of them) and tool steps
  overwrote each other, so the sequence never existed. Net effect on the page is
  **−52/+21 lines**.
- Markdown files preview in the topic, readable by default.
- Channel aliases: managed in settings, tokenized in the composer (desktop and
  mobile), and **isolated from ingest** — an alias is a composer macro and must
  never be expanded on inbound content.

### ⚙️ Platform operations

- **Pack provisioning**: dedicated gateway verbs, and MCP servers now enter
  reconciliation. Previously a plugin declaring only MCP servers marked the pack
  `setup_pending` — "Finish setup" lit in the UI — without triggering any
  reconciliation, so nobody could close that setup. With `features.rag` off the
  prompt no longer asks for verbs that do not exist.
- `GET /clodia/packs/{name}` resolves a **plugin** name to its containing pack:
  setup declarations are per-plugin, so whoever reconciles always starts from a
  plugin name.
- Encrypted spawn-to-spawn file transfers over a dedicated volume.
- Archived topics enforce access; job run status persists across restarts; job
  run history refreshes; Codex usage accounting hardened; GET requests cached
  within a web session.
- Routing: **one responder per message** by default (fan-out is opt-in), routing
  feedback actually applied, and the state-writer seed no longer picked as a
  generic conversational responder.

### 📦 Modules

| module | version |
|---|---|
| `clodia-logic` | 6.105.0 |
| `clodia-tools` | 1.0.0 |
| `clodia-web` | 0.117.0 |
| `clodia-pwa` | — (fixes only) |

`clodia-tools` crosses 1.0.0 with this release: isolating the reference
monitor's state is a change of posture, not an increment of features.

---

## [7.0] — 2026-07-29

Primo **major** dopo la linea 6.x. Il salto è trainato dalla **ristrutturazione
dei topic (meta v2)** e dal **modello Drive come storage live** — entrambi
**breaking** sul formato/contratto dei topic, con migrazione dati inclusa.
Consolida inoltre il ciclo di **governance** (M-gate + deleghe + Chat Hooks),
il **routing multi-agente**, la **gestione dei pack** (update da GitHub, diete e
capability per ruolo) e la nuova identità **Clodia Colony**. Include il
contenimento keyless/M3++ già in rc0, ora in produzione (personal).

### 🗂️ Topic meta v2 ⚠️ (trigger major)
- Schema `meta.json` **v2**: `schema_version`, `status` e `deadline` espliciti e
  normalizzati; vocabolario status coerente su backend/UI. Migrazione con
  **backup** pre-flight; `minutes/` non più negli snapshot (spostate in
  `.migrated-from-v1/`, recuperabili). Migrati 153 topic in produzione, 0 errori.
- **Read-path tollerante**: un `meta` legacy non conforme viene **coerciato**
  (status→`active`, deadline→`null`), mai un errore — un topic non diventa più
  invisibile/non-apribile. La validazione stretta resta ai soli endpoint di
  scrittura `set_status`/`set_deadline`.
- `files/AGENTS.md` come **boot-instructions** del topic, iniettato però come
  materiale **non autorevole** (framing anti prompt-injection) e con **cap** di
  dimensione. Controlli status/deadline (owner-only) nella sidebar del topic.

### 📁 Drive = source of truth del topic ⚠️
- Collegare un topic a una cartella Drive rende **Drive la fonte**: nessun
  upload dei file locali, navigazione diretta del remoto; l'editing di un agente
  passa da uno **scratch** (download→modifica→re-upload), mai dal topic-fs.
  Rimosso l'apparato di migrazione/clear (era la causa di un loop di upload che
  saturava il gateway). Guardia anti-nascondimento + cap SEAL. `remote_disable`
  materializza Drive→locale.
- `topic.read_file`/`write_file` rifiutano binari >128KB → `topic.fetch`/`put`.
- ZIP **download-all** dei file di un topic (streaming, cap 500MB).

### 🔐 Governance: M-gate + deleghe + Chat Hooks
- **M-gate**: consenso umano per-uso sui soli verbi **mutanti** (letture libere),
  RBAC-scoped (`gate:<verb>`), block-and-wait sulla tool-call; card di
  approvazione **inline** nella chat. Eliminato il sottosistema **sudo** legacy
  (cross-topic unificato nel gate).
- **Deleghe firmate** (verifica CA + `covers`), store permanente, endpoint
  register/list/revoke, finestra d'attesa async (~2h) con notifica sui canali di
  contatto del principal.
- **Chat Hooks** F1–F3: un hook per topic (create-or-regenerate), ingress
  webhook con **firma CA**, **audit-log** e **rate-limit** per-minuto; pannello
  owner-only in webui.

### 🧭 Routing dei canali
- **Alias** di canale instance-wide (`$alias` → prompt completo).
- **Routing multi-intent**: decomposizione in sotto-task e fan-out ai
  specialisti pertinenti, con **cap** anti-amplificazione (embed bloccante) e
  filtro d'idoneità (clearance/SEAL, partecipanti) prima dello scoring.
- **Feedback di routing** in UI (conferma/correzione dell'agente scelto) e
  tuning delle soglie del router semantico (threshold/margin/soft-ratio).

### 📦 Pack & agenti
- **Check update / Update da GitHub** (upstream) dei pack first-party: replace +
  restart agenti; flag `setup_pending` + "Finish setup".
- **base-pack a dieta**: primitivi di piattaforma separati da editoriale
  (`editorial-pack`) e comms/supporto (`comms-pack`); capability dei seed
  **per ruolo** (basta wildcard grab-bag) con **migrazione datadir** idempotente
  per i deployment esistenti. Consolidati janitor+sysadmin in un unico steward
  `sysadmin`; nuovo seed `segretario`; `messaggero` con `check-email`/reconcile.
- Skill **`adversarial-code-review`** (security-engineer). **Auto-mount MCP** dei
  plugin solo da fonti **trusted** (update first-party); gli import esterni
  restano opt-in (pending) — barriera Prima Legge. `rag_collections` dichiarate
  dal pack.
- Forward degli **embedded text resource** MCP dal gateway; pin `mcp<2`.

### 🔑 Clearance & contenimento
- **SEAL effettiva** di un agente = SEAL del **provider** che usa (non quella
  dichiarata nel seed), regola **uniforme per tutti** (super inclusi).
- Consolidato il runtime **keyless** + gateway trust-anchor e il volume-split
  M3++ (già in 6.4-rc0), ora in produzione sul personal.

### 🎨 Branding
- Identità **Clodia Colony** su web e PWA (asset dalla sorgente canonica
  approvata); rimosso il widget helpdesk flottante.

---

## [6.4-rc0] — 2026-07-21

**Release candidate.** Runtime **keyless** + gateway **trust-anchor** + document
store per-seed. Il contenimento M3++ (volume-split) è **validato end-to-end su
testbed** (`clodia-test`); la migrazione in produzione (personal) è il passo
successivo. Tag RC come punto di ripristino prima della migrazione.

### 🔑 Runtime keyless + gateway trust-anchor
- **Minting** dei token di sessione (`ckt1`) e delle capability (`ccap1`) spostato nel **gateway** (`/internal/mint`), autenticato dal **secret di bootstrap** `CLODIA_ORCHESTRATOR_SECRET` (non ckt1: sarebbe circolare). L'orchestrator **delega** con cache per-identità e fallback locale (rollout reversibile via flag).
- **Issuance** certificati (enrollment umani/agenti) e **PKI bootstrap** (`init-ca` + `issue-all`) spostati nel gateway, unico detentore di CA key e identity key. `entrypoint`: in modalità keyless agent-server **salta** la PKI bootstrap (evita CA divergente nel volume runtime).
- `child_env` degli spawn: **strip** di `CLODIA_ORCHESTRATOR_SECRET` e `GIT_TOKEN` (un agent via bash non li legge).

### 📦 Contenimento M3++ — volume-split ⚠️
- Topologia **two-dir**: `runtime` (condiviso agent-server↔gateway) vs `sensitive` (solo-gateway: `topics`/`secrets`/`clodia-vault`). agent-server **non monta più** i dati sensibili → bash dell'agente contenuta a livello filesystem. `pki/` (certi pubblici) resta in runtime. Validato su testbed; **personal pending**.

### 🗂️ Document store per-seed + trasferimento file
- `memory.put_document`/`read_document`/`get_document`/`list_documents`/`delete_document`: libreria **persistente per-seed** (`agents/<seed>/files/`, cap 25MB), caricata **on-demand**.
- `topic.read_file`/`write_file` **rifiutano** payload binari >128KB e indirizzano a `topic.fetch`/`topic.put` (byte via scratch, fuori dal modello). Nuovo **principio 6** in costituzione.

---

## [6.3] — 2026-07-20

Release di **sicurezza & governance**: l'RBAC passa da *convenzione* a *confine
reale*, dal gateway come unico punto di autorizzazione (umani e agenti, UI e
agentico) fino al contenimento del runtime degli agenti. ~74 commit sui quattro
moduli. La sicurezza-pack (security-auditor + install-pack) è rinviata a v6.4.

### 🔐 M-sudo — least-privilege + escalation
- Rimosso il bypass "super" sull'accesso ai topic; **compartimentazione** `topic.*` (fix confused-deputy).
- `add/remove_participant` = azione **sudo** (chiude auto-invito cross-topic).
- Propagazione del **principal umano** del turno al gateway (Claude SDK).
- Gruppo **sudoer** + grant admin; flusso **request → popup owner → approva**.
- Grant sudo = **capability-token firmata dalla CA** (`ccap1`), revocabile; verifica firma+scadenza+jti a ogni op; rimosso il fallback non-firmato.

### 🛂 M-authz — RBAC unica per agenti e umani ⚠️
- Il **gateway diventa il PDP unico**: claim firmati `on_behalf`/`human_role`, facade `/internal/tool`+`/internal/authorize`; RBAC identica per agente/umano e UI/agentico.
- Enforcement su **tutti** gli endpoint privilegiati REST (packs/providers/agents/workflows/plugins) — chiusa la Broken Access Control (un non-admin/anonimo poteva terraformare).
- `/tools/*` (integrations/credenziali/backup) → **admin-only** (chiuso il buco della rimozione MCP).
- **topic status/archive → owner-only**; **jobs con owner** e azioni owner-only.

### 🧱 M3 — contenimento del runtime (perms-based)
- Il subprocess dell'agente gira **non-root** (wrapper `setpriv`): il suo bash NON legge i segreti root-only (ca.key/identity.key/vault).
- **uid unico per-spawn** (isola l'istanza) + **gid per-seed** (famiglia); scratch `700`.
- `secrets/` e `clodia-vault/` → **700** (root-only). Sandbox **ON di default** sui cloni.

### 📦 Struttura pack + seed (M0–M2)
- **base-pack** come pack vero, **non rimuovibile**; seed nativi + costituzioni come preamboli.
- Placeholder pack di terzi + **licenze/DPA** (API + badge FE).
- **janitor** → navigator WebUI (`goto`); **sysadmin** → remit ristretto; tool **`logs.tail`**.

### 🖥️ UI
- Gating dei widget privilegiati **per ruolo** (defense-in-depth): sezioni sidebar, rimuovi-MCP, import/delete pack, provider, nuovo agente, azioni job/topic per-owner.
- Fix sidebar (collasso/troncamento), colonna destra topic full-height+ridimensionabile, "sta scrivendo" nel widget, etichetta versione, toggle archiviati.

### 🩹 Fix
- Provider `aws-region-eu`: default **Sonnet** corretto (`eu.anthropic.claude-sonnet-4-6`).
- **Clearance** clodia/ophelia (erano assenti → bloccate): tetto SEAL-3 + **effettiva = min(tetto agente, SEAL provider)** — dinamica sul provider.
- **clodia non si intrufola più nei DM** (i DM non prendono i partecipanti di default).
- **Igiene output** (costituzione, principio 5): nessun ragionamento/istruzioni nel corpo del messaggio.

### 📄 Docs
CHANGELOG centrale, ROADMAP, `architecture.md` (invariante gateway PDP/PEP + perimetri + audit tool), `m3-sandbox.md`.

---

## [6.2] — 2026-07-18

Release ricostruita dai ~212 commit `v6.1..v6.2` sui quattro moduli e sintetizzata come singolo prodotto.

### 📨 Messaggistica & Telegram — nuovo modello *telegram-proxy* ⚠️
- **`messaggero` unico corriere** verso Telegram: unica superficie che spedisce; non risponde né esegue l'inbound. Abbandonato il vecchio modello "mirror" (rimossi channel adapter e agente "Eco").
- **Relay meccanico (no-LLM) a contesto-finestra**: bufferizza la chat verbatim, riversa nel topic **solo** quando il bot è interpellato (menzione o reply a un suo messaggio) → niente intrusioni/spam/leak di policy nei gruppi.
- **Whitelist mittenti in `MEMORY.md`** con fallback **fail-closed** (assente/rotta → tutti negati); handle autenticati via **uid numerico** dall'API (anti-spoofing).
- **ACK/deny immediati** al mittente; **long-poll** su `getUpdates` → latenza da ~45s a ~0.
- **Allegati bidirezionali** (download inbound in `files/` con nome sanitizzato; invio con `chat_id`+`path`).
- Binding `chat_id ↔ istanza messaggero` in `telegram-bindings.json` (`telegram.listen/unlisten`), sganciato dal `meta` del topic; `send` senza più lease per-chat, accetta chat_id o nome gruppo.

### 🧵 Topic, Canali & Canvas
- **Canvas live inline**: appare da solo quando un agente produce `artifact.html` (nuovo verbo `artifact.render`), iframe sandbox + fit-to-window, **toggle show/hide** e modalità wide.
- **Sync file per-file stile git** (synced/modified/staged/unsynced, `unstage`), filtro `remoteinclude`/`remoteignore` con **hard-deny non bypassabile** su segreti/chiavi, **pull Drive incrementale** (confronto md5).
- **Composizione squadra** alla creazione del topic: `suggest_team` (rilevanza + costo), welcome "di cosa tratta?" (skill `team-composition`), **widget "Invita la squadra"** (owner-only).
- Gestione partecipanti da agente; toolbar uniformata; "Archiviati" come toggle; fix chip delle card di preview.

### ⚙️ Workflow (ex *Kanban*) — motore dichiarativo ⚠️
- **Workflow dichiarativi dai pack** (`stages: [{lane, skill, human_gate}]`), store file-per-run, assegnazione lane per capability (specialisti prima, super in fallback), protocollo `ESITO: OK|BLOCCATO|FALLITO`. La feature `kanban` è rinominata `workflows` (alias legacy retrocompatibile).
- **Run conversazionali → interazione inline sulla board** (pills/campo testo sotto la card; il topic resta infrastruttura di audit).
- **Gate** con notifica Telegram + email e **link monouso firmato** (HMAC, TTL, nonce) alla pagina `/gate/{token}` senza login; possibilità di **"Torna a &lt;stadio&gt;"** (rework indietro).
- **Job: `propose` → approve owner** (Prima Legge) con popup di conferma in chat o link firmato — un agente non crea più job direttamente.
- **Workspace repo per-run**: clona repo privati via PAT dal vault, passa il path agli stadi, cancella a fine run.
- Catalogo `/workflows`, pagina di dettaglio, board per lane, step navigabile (input/output per stadio), Stop/Delete, nomi auto-incrementali, recupero run orfani post-restart.

### 🧭 Routing del risponditore (per rilevanza) — *nuovo*
- Instradamento allo **specialista idoneo** via embedding MiniLM locale (nessun turno LLM di dispatch); profilo di dominio **auto-derivato** (expertise + skill + titoli RAG), scoring **max-sim multi-vettore**.
- Calibrazione **route-the-confident** (soglia 0.50); il caso ambiguo va a Clodia in fallback. Idoneità SEAL/clearance invariata.
- **Trasparenza**: evento `routing_decision` sul bus SSE + blocco **🧭 Routing** in chat (agente scelto, motivo, candidati con punteggio, soglia/margine).

### 🤖 Agenti & Seed di sistema
- **Rename seed** ⚠️: `mercuria → messaggero`, `saimon → sysadmin`, `wainston → janitor` (stesso ruolo/capability; richiede migrazione istanze).
- **`sysadmin` → platform-ops**: osservazione/controllo runtime, jobs, packs, workflows, providers, mcp, settings — con confini hard (mai topic/SEAL-2/segreti) e lettura **read-only** dei sorgenti della platform.
- **`memory.*` universale**: ogni agente scrive la propria memoria senza grant per-agente; **tab Memories** in webui + endpoint `GET /{name}/memories`.
- **/agents come tabella** con colonna **costo /1M token** (in/out) o "abbonamento"; rimosse colonne Stato/Skill.

### 🧠 Provider di inferenza
- **Nuovo provider Claude Team** (SEAL-1, DPA commerciale Anthropic) preferito nei seed `clodia`/`sysadmin`/`janitor`.
- **Default Sonnet EU (Bedrock) → Claude Sonnet 5** (upgrade per sysadmin/avvocato/commercialista; `claude-sonnet-4-6` ora legacy).

### 🔐 Credenziali, Vault & Connettori
- **Google unificato** (Gmail + Drive + Docs + Calendar) ⚠️: un solo consenso OAuth → **una sola credenziale `google_<account>`** con un unico refresh token. Elimina il cross-invalidation dei consensi separati `gmail_`/`gworkspace_`. Fallback ai grant legacy.
- `email.save_attachment` e `topic.read_document` (PDF/DOCX/XLSX → testo) **server-side**: niente più base64 troncato nel contesto del modello.
- Nuovi verbi `gdrive.rename` / `gdrive.move` (Shared Drive supportati).
- **Test connection reale** delle integrazioni (github/trello/telegram/openai/topic-storage): distingue "connesso" da "credenziale valida" (es. PAT scaduto).
- Vault: endpoint interno PAT scopato per il runner dei workflow; fix lettura chiave `api_key`.

### 🛡️ Sicurezza & Governance (Prima Legge)
- Job solo via **propose → approve** owner; **platform-ops gated + log** (non più shell); hard-deny segreti nel sync remoto; whitelist Telegram fail-closed con uid anti-spoofing; il corpo delle skill non finisce più nell'output/streaming (`_BlockFilter`).

### 🖥️ Web UI
- **Topics**: canvas live, blocco Routing, invita squadra, popup conferma job, paste immagini nel composer, sync git-style, toolbar uniformata, fix card.
- **Workflows**: catalogo/dettaglio/board, interazione inline, step navigabile, pagina `/gate`.
- **Providers/Tools**: card **Google unificata**, bottone **Test connection**.
- **Packs**: nodo auto-descrittivo (workflow con lane/gate + datastore).
- **Sidebar collassabile** (solo iconcina in modalità collapsed).

### 🔑 Auth & Backup
- **Sessione PWA valida 30 giorni** (niente ri-pairing; la masterkey non viene mai trasmessa al telefono).
- Backup: `status` distingue **ultimo backup eseguito** (anche fallito, con errore) da **ultimo snapshot valido** (restic); Settings più informativo.

### 🚑 Stabilità & performance
- Risolto **deadlock sync-in-async** gateway↔agent-server (dispatch offloadato su threadpool).
- **Incidente 17 lug**: il polling della webui saturava il gateway (~60 chiamate HTTP sincrone per poll) fino al blocco → cache TTL sui provider + handler caldi fuori dall'event loop; `/internal/topics` con cache 6s (basta read-timeout MCP a 15s).
- Recupero sessioni OpenCode morte (404 → nuova sessione); download filename non-ASCII (RFC 5987); no-cache sull'HTML in preview (UI stale); fix proxy `/gate`.

### ⚖️ Legale
- Aggiunto il copyright **"© 2026 Davide Carboni"** nei README di tutti i moduli.

---

## [6.1] — 2026-07-07

Primo tag globale coordinato sui quattro moduli (baseline del versionamento di piattaforma). Nessun changelog centrale antecedente.
