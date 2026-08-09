# Security posture — Clodia Platform

**Last updated:** 2026-08-09
**Assessment anchored to:** `clodia-logic@28100ed` · `clodia-tools@ddefd40` · `clodia-web@9886ff4`

This document describes the **current state of the technical security controls**
implemented by Clodia Platform, mapped onto the technological controls (Theme 8)
of **ISO/IEC 27001:2022 Annex A**. It is an honest snapshot of *what the software
does today* — not a certification and not a guarantee.

> **Two controls are built and switched off**, deliberately: the origin chain
> observes and blocks nothing (`CLODIA_ORIGIN_ENFORCE` unset), and the list of
> vetted sources is empty, so everything is treated as tainted. They are the only
> steps that *remove* capability, and they are meant to be turned on knowingly.
> Until they are, read every row below as describing a system where those two
> lines do not hold.

---

## ⚠️ Run it at your own risk (as is, no warranty)

Clodia Platform is **self-hosted** software distributed **AS IS**, **without
warranty** of any kind, express or implied, including — without limitation —
warranties of merchantability, fitness for a particular purpose, security,
absence of defects or non-infringement. Consistently with the project's licence
(**GNU AGPL v3**, sections 15–17; see [`LICENSE`](LICENSE) and
[`LICENSING.md`](LICENSING.md)):

- **You assume the entire risk** as to the quality, performance and security of
  the software when you run it on *your* infrastructure.
- **The authors are not liable** for any direct, indirect, incidental or
  consequential damage — data loss, breach, interruption, lost profit — arising
  from use of, or inability to use, the software.
- Controls marked `OK` below are implemented **but have not been independently
  audited or penetration-tested**. `OK` means the control is present in the
  code, not a certified level of assurance.
- **Known defects are tracked publicly.** Before installing or upgrading it is
  your responsibility to read the
  [open `security` issues](https://github.com/r-clodia/clodia-platform/issues?q=is%3Aissue+is%3Aopen+label%3Asecurity)
  and the [open issues](https://github.com/r-clodia/clodia-platform/issues?q=is%3Aissue+is%3Aopen)
  in general, and to weigh them against your own risk model. This document
  photographs the controls; the tracker lists what is broken.
- **No ISO 27001 certification**: ISO 27001 certifies an organisation's ISMS,
  not a software product. This table exists to *enable* the technical controls
  for whoever deploys, by providing evidence — not to attest conformity.

If that risk model is not acceptable in your context, **do not run this software
in production** without an independent security assessment.

---

## Shared responsibility

Clodia Platform is a **software artefact**: it implements *technical* controls —
architecture, cryptography, access control, backup. The **organisational,
people and physical** controls of Annex A — leadership, supplier management, HR,
physical security of the host, organisational incident management — remain the
**responsibility of the deploying organisation** and its ISMS.

This document covers **only the technological controls (Annex A, Theme 8)**.

---

## A design limit: single-user instances

As things stand, the platform should be deployed as a **single-user instance**.
The internal access control — clearance plus membership of a topic — holds on
*its own* axis, but **does not extend to external data** reached through the
connectors: an integration's credentials (Google, Drive, Gmail, and anything
else in the vault) are **platform-level** identities, not a person's. A second
human user — properly authenticated, with no grant on anyone else's topics — can
therefore reach, through an agent that holds the connector grant, the external
data shared with that account.

Tracked as **[#68](https://github.com/r-clodia/clodia-platform/issues/68)** (a
design gap, not a regression). Until it is remedied:

- do not add human users to an instance with live external connectors;
- do not share, with a platform account, content that is not meant for **every**
  user of the instance;
- treat onboarding a second human user as a security-relevant change, not a
  routine operation.

---

## Technical controls (ISO/IEC 27001:2022, Annex A — Theme 8)

**Status legend:** `OK` implemented · `PART` partial · `PLAN` planned ·
`N/A` not applicable, with a justification.
**(Deployer)** = the responsibility of the deploying organisation, not of the software.

| # | Control | Status | Notes |
|---|---------|:------:|-------|
| 8.1 | Endpoint devices | OK | Isolated containers; hardening the host is the deployer's |
| 8.2 | Privileged access | PART | Vault denies by default; a super-agent bypasses the per-agent view with no justification trail and no time limit; the rank model is not enforced. The **state that grants privilege** — the authority matrix, gate consents, delegations — lives on a volume only the gateway mounts, out of reach of the agent plane ([#80](https://github.com/r-clodia/clodia-platform/issues/80)) |
| 8.3 | Restriction of information access | PART | SEAL-0..4 tiering, membership of the topic, and a clearance signed into the session token; authority is the intersection of the agent's type, its role in the scope, and the instance profile. **Connector credentials are platform identities, so external data escapes these axes** ([#68](https://github.com/r-clodia/clodia-platform/issues/68)); no per-object scoping on the remote service |
| 8.4 | Access to source code | PART | The `github.*` verbs run in the gateway with the owner's credential, which never enters the agent's process — asserted against the disk after every clone, not merely intended. A repository is a whitelist entry of the scope, matched by repository rather than by host. Branch protection on `main` is the deployer's |
| 8.5 | Secure authentication | PART | Ed25519-signed session tokens carrying which spawn, which room and which clearance; no human MFA, no login rate limit; the gateway's UI is open if `CLODIA_TOOLS_UI_TOKEN` is unset |
| 8.6 | Capacity management | PLAN | No per-container resource limits, no disk or memory monitoring |
| 8.7 | Protection against malware | PART | Slim images and a shell that denies by default; no AV, no image scanning |
| 8.8 | Technical vulnerability management | PART | Gitleaks in CI (secrets); no CVE scanning (pip-audit, Dependabot), loose dependency pinning |
| 8.9 | Configuration management | PART | Compose and configuration are versioned; configuration can still drift at deploy time and changes are not audited. The gateway's **authorisation** configuration cannot be modified from the agent plane ([#80](https://github.com/r-clodia/clodia-platform/issues/80)) |
| 8.10 | Information deletion | PART | Soft deletes — a topic's trash, Drive's trash; no retention or TTL policy |
| 8.11 | Data masking | PART | The vault **never** returns a secret's value to a model; the provenance of a credential is shown and the value is not; error messages carry names, not values; no redaction of tool output |
| 8.12 | Data leakage prevention | PART | `.dockerignore` excludes secrets, data and topics; a SEAL cap per channel; membership ACLs; secrets never reach a model. Direct network egress from the agent container is closed — measured 9 Aug 2026, `curl` to the open internet fails — so a fetch cannot bypass the gateway and arrive without a taint label. Still missing: a hard block on reading sensitive files towards a lower-sovereignty provider |
| 8.13 | Backup | OK | Client-side encrypted restic to object storage; a consistent SQLite snapshot; retention; an automated restore test |
| 8.14 | Redundancy | N/A | Single-node by design; the availability requirement is the deployer's choice, and disaster recovery goes through the backup |
| 8.15 | Logging | PART | Operation audit (`colony.events`), an activity log, optional Langfuse; no dedicated security-event log and no central sink; **actions towards the outside are not attributable to the human who asked for them** ([#68](https://github.com/r-clodia/clodia-platform/issues/68)) |
| 8.16 | Monitoring | PART | An agent activity page, runtime introspection, heartbeats; no alerting and no automatic thresholds |
| 8.17 | Clock synchronisation | PART | Internal timestamps in UTC; the scheduler runs in local time; no explicit `TZ` in the containers and no clock-skew healthcheck |
| 8.18 | Use of privileged utility programs | OK | The PKI CLI is not exposed over the API; the vault acts as a broker; the built-in agents are immutable |
| 8.19 | Installation of software | PART | Partial pinning (versions through build args); no image signing and no hash lock |
| 8.20 | Network security | PART | Bound to loopback plus the Docker bridge; the network perimeter is the deployer's (a VPN, for instance) |
| 8.21 | Security of network services | PART | Authentication to the gateway by PKI (public key); the bearer token travels in clear HTTP between containers; the UI is open by default |
| 8.22 | Segregation of networks | PART | A single default bridge and no segregation between gateway and agent-server, **but the agent container's direct route to the internet is closed** by the egress proxy (`docker/egress/`) — measured 9 Aug 2026: `curl https://example.com` from inside the agent-server returns nothing. That was the second point of [#80](https://github.com/r-clodia/clodia-platform/issues/80). Verify with `docker/test-plane-isolation.sh` |
| 8.23 | Web filtering | N/A | The web is reached only through whitelisted verbs; no general-purpose browser is exposed |
| 8.24 | Use of cryptography | PART | TLS to external providers; **the secret vault is not encrypted at rest** (only OS permissions `0600`); inter-container traffic is clear HTTP |
| 8.25 | Secure development lifecycle | PART | Gitleaks and a pull-request process; no formal SSDLC, tests not run in CI |
| 8.26 | Application security requirements | PART | The normative model is [`docs/specification.md`](docs/specification.md), with [`docs/gap-analysis.md`](docs/gap-analysis.md) measuring what is actually enforced; guards against path traversal, denial by default, a gate on every crossing. Downgraded from `OK` on 9 Aug 2026: the per-component `POLICY.md` documents this row used to cite had drifted into describing a system that no longer existed, and were removed rather than refreshed |
| 8.27 | Secure architecture and engineering principles | OK | The gateway is a reference monitor in a separate process and container; a colony PKI; secrets held by the vault; an agent's private key never enters its workspace; one spawn cannot reach another's scratch |
| 8.28 | Secure coding | PART | Subprocesses invoked with argument lists, path whitelists, no shell injection; no SAST, review not mandatory |
| 8.29 | Security testing in development and acceptance | PLAN | A unit-test suite exists but does not run in CI; no penetration test, SAST or DAST |
| 8.30 | Outsourced development | N/A | Development is in-house; no development supplier |
| 8.31 | Separation of environments | PART | Multiple stacks by project prefix and distinct datadirs; no network isolation between environments |
| 8.32 | Change management | PART | Git, a pull-request process, gitleaks; no branch protection, and the compose file can drift at deploy time |
| 8.33 | Test information | N/A | The product ships no production data or PII for testing |
| 8.34 | Protection of systems during audit | N/A | Auditing live operating systems is the deployer's responsibility |

**Theme 8 summary (34 controls):** 4 `OK` · 23 `PART` · 2 `PLAN` · 5 `N/A`
(29 applicable). The hot areas today: **8.3 / 8.15** — connectors as platform
identities, so access control does not cover external data and external actions
are not attributable, which is what blocks multi-user
([#68](https://github.com/r-clodia/clodia-platform/issues/68)); **8.24**, vault
encryption at rest and TLS between containers; **8.9 / 8.32**, configuration
drift; **8.29 / 8.8**, tests and vulnerability scanning outside CI. And, above
the table: two controls that are built and not switched on.

---

## Reporting a vulnerability

This project practises **public disclosure** of its own defects: known limits,
including security-relevant ones, sit in the
[public tracker](https://github.com/r-clodia/clodia-platform/issues?q=is%3Aissue+is%3Aopen+label%3Asecurity)
in plain sight, because whoever deploys must be able to weigh them **before**
installing. An honest list of what is broken is worth more than an absence of
news.

- **Design defects and architectural limits** → open a **public issue** with the
  `security` label.
- **An exploitable vulnerability with a working exploit** — especially one
  affecting third-party instances already deployed → write privately to
  **Davide Carboni, dcarboni@gmail.com**, so that remediation can precede the
  operational detail. The defect will still be made public after the fix.

In both cases, consistently with the as-is clause above, **no response or
remediation SLA is guaranteed**.
