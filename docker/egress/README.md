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
| `Dockerfile`, `egress_proxy.py` | the egress proxy: CONNECT to allow-listed hosts, default-deny, every request joined to its turn (#463) |
| `allowlist` | the hosts, as anchored regular expressions |
| `test_egress_proxy.py` | policy, credentials, the server, and the join with the gateway (`python3 -m unittest discover -s docker/egress`) |
| `../ingress/` | the nginx that fronts the agent API, because phase C removes its published port |

## Two measured facts that shaped this

**A host firewall rule cannot work here — the daemon is rootless.** The first
draft of this put an iptables rule in `DOCKER-USER`. On this deployment docker
runs **rootless**: container traffic leaves through `rootlesskit` inside a user
namespace and never traverses the host's `FORWARD`/`DOCKER-USER` chains, so the
rule would match nothing. The same rootless setup also means `sudo docker` speaks
to a socket that does not exist (`/var/run/docker.sock`), which is how the
mistake surfaced — the script could not even find the proxy container.

**`internal: true` is the confinement, and it is better.** Docker gives the
network no route out, and a process inside the container cannot undo it — unlike
an iptables rule, which on a rootless daemon it would never reach anyway. The
cost is real and measured: an internal network **also disables host port
publishing**, so the agent API needs a front. That is `docker/ingress`.

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

**Phase C — the only route.** Set `internal: true` on `clodia-int`, drop the
agent-server's published port, and bring up `ingress`. From here a process in the
agent container cannot leave except through the proxy, whether it cooperates or
not — and no root is needed at any point. *Rollback: remove `internal: true` and
recreate; the published port can stay on the ingress either way.*

Verify with the test that distinguishes preference from obligation:

```bash
# must FAIL once phase C is active — this bypasses the proxy variables
docker exec <agent-container> curl -s --noproxy '*' -m 10 https://example.com/
```

Do not skip B: its log is how you find the hosts the allow-list is still missing,
before a firewall turns a missing entry into a hard failure.

## Which turn made this request (#463)

The proxy was tinyproxy until #463. Same policy — default-deny, anchored host
patterns, CONNECT only to 443 and 80, no TLS interception, no `Via` — but
tinyproxy cannot say which turn a request belongs to, and the audit trail
needs exactly that: a gateway `tool.call` and the proxy record of the same
turn must share a trace id.

**Why it travels in the credentials.** HTTPS is a CONNECT tunnel: the proxy
sees `host:port` and not one header inside it, so the `traceparent` the
gateway reads can never reach this hop. What it does see is the CONNECT's own
`Proxy-Authorization`. The agent-server (clodia-logic ≥ 6.268.0) gives every
spawn the proxy URL

    http://<spawn>:<tag>@egress-proxy:8888      tag = HMAC(orchestrator secret, spawn)

and every cooperative client sends it pre-emptively: Claude Code, curl,
requests/httpx, Bun (opencode), reqwest (codex).

**How the join is made.** For each request the proxy reports
`{spawn, tag, host, port, method, allowed}` to the gateway
(`POST /internal/egress/record`, clodia-tools ≥ 2.74.0). The gateway checks the
tag, records `egress.connect` under the trace of the spawn's current turn and
answers with the trace id and the event id, which the proxy writes into its own
log line. An allowed destination is dialled while the report is in flight, so
the join adds no latency beyond the slower of the two (report timeout 1 s).

**The log** is one JSON object per line on stdout (`docker logs egress-proxy`):

```json
{"ts":"…","event":"request","conn":12,"client":"172.31.7.4","method":"CONNECT",
 "host":"api.anthropic.com","port":443,"allowed":true,"reason":null,
 "spawn":"clodia-320","attribution":"verified",
 "trace_id":"4bf92f35…","span_id":"00f067aa…","event_id":"…","reported":true}
{"ts":"…","event":"close","conn":12,"bytes_up":5120,"bytes_down":88213,"duration_ms":4210}
```

`attribution` is `verified` (the gateway checked the tag), `unverified` (a tag
that does not match: recorded without a spawn), `claimed` (a spawn label the
gateway was not asked about) or `none`. The tag itself is never logged,
never recorded, never forwarded upstream; anything in `Proxy-Authorization`
that is not a spawn label and a 32-hex tag is dropped before it can be.

**It is a label, not a gate.** A request without credentials is served exactly
as before — the allow-list is the gate — and recorded as unattributed. Making
attribution mandatory (a `407` without a verified tag) is a possible next step,
not this one. A spawn that could read another spawn's environment could borrow
its label: the per-spawn uid of the sandbox is what prevents it.

**Configuration.** `CLODIA_EGRESS_PROXY_SECRET` (generated by `setup.sh`) goes to
the gateway and the proxy only — deliberately not the orchestrator secret,
which mints identities. Empty = the proxy filters and logs without the join.

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
