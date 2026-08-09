<!-- markdownlint-disable MD033 MD041 -->
<h1>Clodia Agency</h1>

**A self-hosted agentic platform, with governance and security by design.**

Clodia Agency is an agency of AI agents that runs on *your* infrastructure:
Slack-like chats and channels with the agents, shared working topics, tools over
MCP, credentials held in a vault, agent identities backed by a PKI, and an
authority model that decides, per call, what a given agent may do. For anyone
who wants agentic automation **without** handing their data to somebody else's
SaaS.

> **Licence:** [AGPL v3 — dual licensing, see LICENSING.md](LICENSE). Fully
> self-hosted: your data stays on your machine.

---

## ⚠️ Before you install — read this

Clodia Platform is distributed **AS IS, without warranty of any kind**, and
**you install and run it at your own risk**. The project is under active
development and contains known defects, some of them security-relevant.

**A required step before deploying — read the known defects:**

1. **[Open issues labelled `security`](https://github.com/r-clodia/clodia-platform/issues?q=is%3Aissue+is%3Aopen+label%3Asecurity)** — known, unresolved security defects.
2. **[All open issues](https://github.com/r-clodia/clodia-platform/issues?q=is%3Aissue+is%3Aopen)** — functional limits and known bugs.
3. **[`SECURITY.md`](SECURITY.md)** — the state of the technical controls, one by
   one, and the full as-is clause.
4. **[`docs/threat-model.md`](docs/threat-model.md)** — which attack this design
   answers (the *lethal trifecta*) and how. Read it before `SECURITY.md`: it says
   *why* the controls are the ones they are.
5. **[`docs/gap-analysis.md`](docs/gap-analysis.md)** — what the specification
   requires against what the platform actually does, measured. It names the gaps
   rather than summarising them away.

**To understand its shape:** [`docs/specification.md`](docs/specification.md) is
the model — actors, scopes, authority, gates, perimeter, tiers.
[`docs/decision-record.md`](docs/decision-record.md) is how that model was
arrived at, with the measurements that settled each question.

Known defects are tracked **publicly and in the open**. Their absence from this
README does not mean they do not exist — it means you have to look in the
tracker. Weigh every open issue against *your* risk model before putting the
system into production or trusting it with third-party data.

### Two limits to know about immediately

**It is effectively single-user.** Credentials for external connectors — Google,
email, anything else in the vault — are **platform-level** identities. A second
human user, even with no grant on anyone else's topics, can reach the external
data those credentials unlock through an agent that is allowed to use them. See
**[#68](https://github.com/r-clodia/clodia-platform/issues/68)**. Do not add
human users to an instance with live connectors until that is resolved.

**Two controls are built and switched off.** The origin chain observes and
blocks nothing (`CLODIA_ORIGIN_ENFORCE` unset), and the list of vetted sources
is empty, so everything is treated as tainted. Both are deliberate — they are
the only steps that *remove* capability, and they are meant to be turned on
knowingly, after reading what the observing mode has collected. Until then,
treat them as absent rather than as protection.

If that risk model is not acceptable in your context, **do not run this software
in production** without an independent security assessment.

---

## Quickstart (Docker, build from source)

Requirements: Docker with Compose, `git`, and an `ANTHROPIC_API_KEY` — or a
Claude account to connect over OAuth from the UI.

```bash
git clone https://github.com/r-clodia/clodia-platform.git
cd clodia-platform
./setup.sh                       # clone the source repos, prepare the datadir and .env
nano .env                        # ANTHROPIC_API_KEY, CLODIA_DATA, CLODIA_BASE_EMAIL
docker compose --profile build-only build base bundle
docker compose up -d --build
```

Then open **http://localhost:7843**, run the **admin bootstrap** — you claim the
first administrator account — and connect providers and credentials from the
**Tools** section (OAuth, or a pasted key per tool). From an empty datadir the
platform initialises its schema, its PKI (the CA and the identities of the
built-in agents) and its data layout by itself.

On macOS, see [`docs/install-macos.md`](docs/install-macos.md).

## Architecture

| component | role | repository |
|---|---|---|
| **agent-server** | the agent runtime, the API, the colony PKI | `clodia-logic` (cloned at runtime) |
| **clodia-tools** | the MCP gateway — the reference monitor: it decides every call, and holds the vault | `clodia-tools` |
| **webui** | the web interface — chats, topics, agents, administration | `clodia-web` |
| **pwa** | the mobile app — topics and direct messages | `clodia-pwa` |

All of an instance's state lives in a separate **datadir** (`CLODIA_DATA`):
secrets, topics, databases, the PKI, agent definitions. The Docker images carry
no data — they are clonable and disposable.

## Security and data

- **Self-hosted**: no data leaves your infrastructure.
- **Credentials in the vault**, never in code and never in an image; they are
  connected from the UI, and the datadir is never published.
- **The gateway is a reference monitor**, in a process and container separate
  from the runtime the agents live in. An agent holds no credential and no CLI:
  the only way it acts on the world is to ask.
- **Authority is an intersection** — what the agent's type declares, what its
  role in that scope allows, and what the instance profile enables. A refusal
  says which of the three blocked it, because the three have different remedies.
- **PKI identities**: every agent carries a certificate signed by the local CA,
  and every call carries which *spawn* made it, not merely which type.
- **Gates**: an action that crosses a boundary waits for a human, and the card
  says what it crosses and who has standing to unblock it.

> These are the controls that are **implemented** — not a certified level of
> assurance. There has been no independent audit and no penetration test. The
> real state, control by control, is in [`SECURITY.md`](SECURITY.md); the open
> defects are in the
> [tracker](https://github.com/r-clodia/clodia-platform/issues?q=is%3Aissue+is%3Aopen+label%3Asecurity).

## Want this platform in your organisation?

Clodia is built for those who want agentic automation with governance and
security by design (ISO 27001 / ISO 42001, NIS2). If you want to adopt it,
integrate it or adapt it to your context — or you need support on AI governance
and compliance — **[let's talk](https://r-clodia.github.io)**.

---

<sub>Open-source project. Contributions welcome — see
[`CONTRIBUTING.md`](CONTRIBUTING.md).</sub>

## Licence and copyright

Copyright (C) 2026 Davide Carboni.

GNU AGPL v3, with a commercial option: see [LICENSING.md](LICENSING.md).
Releases up to the `apache2-final` tag remain Apache 2.0.
