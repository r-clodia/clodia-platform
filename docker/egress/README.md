# Agent egress confinement

Phase 1 of the trifecta defence (clodia-platform#104): remove the agent
container's unmediated route to the network. Without it the other layers are
theatre for the four agents that have a shell — `curl` does not pass through the
gateway, and a `curl` that downloads a page introduces untrusted content
**without a taint label**, which makes the flag wrong in good faith rather than
by malice.

## What is here

| file | role |
|---|---|
| `Dockerfile`, `tinyproxy.conf` | the egress proxy: CONNECT to allow-listed hosts, default-deny |
| `allowlist` | the hosts, as anchored regular expressions |
| `confine-agents.sh` | the host firewall rule that makes the proxy the *only* route |

## Two measured facts that shaped this

**`internal: true` is not usable.** A docker network with `internal: true` does
block egress — verified — but it also breaks host port publishing, and the API
must stay reachable from the host for the browser to talk to it. The network
therefore stays a normal bridge and the block lives in the host firewall.

**The proxy alone is not confinement.** `HTTPS_PROXY` is honoured by cooperative
clients only: the Claude Code CLI honours it (documented), `curl` and
`requests`/`httpx` honour it, a binary that opens its own socket does not. The
proxy gives host granularity and — just as valuable right now — a **log of where
the agents actually go**, which is the data the per-seed allow-lists of §7 need
and that no telemetry provides yet (#110). The firewall is what turns preference
into obligation.

## Rollout, in three reversible steps

**Phase A — proxy available, nothing enforced.** Deploy the compose and build
`egress-proxy`. Nothing changes for the agents: `CLODIA_AGENT_EGRESS_PROXY` is
empty, so no proxy variable reaches them. Verify the proxy answers and that the
stack is healthy. *Rollback: none needed.*

**Phase B — proxy preferred.** Set `CLODIA_AGENT_EGRESS_PROXY=http://egress-proxy:8888`
and recreate the agent container. Cooperative clients now leave through the
proxy, and its log starts recording destinations. **This is the step that can
break turns**: if a host an agent needs is missing from `allowlist`, its requests
fail. *Rollback: unset the variable, recreate.*

**Phase C — the only route.** Run `sudo docker/egress/confine-agents.sh`. From
here a process in the agent container cannot leave except through the proxy,
whether it cooperates or not. *Rollback: `sudo docker/egress/confine-agents.sh --off`.*

Do not skip B: its log is how you find the hosts the allow-list is still missing,
before a firewall turns a missing entry into a hard failure.

## The allow-list, and what is deliberately absent

Inference providers actually connected on the instance, GitHub (shell `git push`
and pack installs), the npm/PyPI registries, and the Claude Code housekeeping
hosts documented under
[network configuration](https://code.claude.com/docs/en/network-config).

Absent on purpose:

- **the two Datadog telemetry hosts** — disabled at the source with
  `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` instead of allow-listed;
- **`googleapis.com`, `api.telegram.org`, SMTP/IMAP** — these belong to the
  **gateway**, which keeps direct egress. An agent must reach them through a
  mediated verb, never on its own. This is the line that makes the whole design
  worth the effort.

## Limits worth stating

**Host granularity, not resource granularity.** With CONNECT the proxy sees
`host:port`, never the path: allow-listing `github.com` allows *any* repository.
Restricting to a repository is the fine-grained PAT of §7, not this layer — the
two compose, they do not substitute.

**Four channels remain.** Inference providers, gateway, GitHub, package
registries. Each is in principle a carrier — a gist, an issue comment, a
published package. This reduces the surface by orders of magnitude; it does not
make it zero.

**Inference is itself egress.** Every turn sends private data to the provider.
This layer governs destinations *chosen by the agent*, not the engine.
