"""Egress proxy for the agent container (clodia-platform#104 phase 1, #463).

Replaces tinyproxy with the same policy — default-deny, an allow-list of
anchored host patterns, CONNECT only to 443 and 80, no TLS interception, no Via
header — plus the one thing tinyproxy could not do: say WHICH turn a request
belongs to.

## Why the credentials carry the join

HTTPS goes through here as a CONNECT tunnel: the proxy sees `host:port` and not
a single header inside it, so the `traceparent` or `X-Clodia-Trace-Id` the
gateway reads can never reach this hop. What the proxy DOES see is the
CONNECT's own `Proxy-Authorization`. The agent-server gives every spawn the
proxy URL `http://<spawn>:<tag>@egress-proxy:8888`, where `tag` is an HMAC of
the spawn under a secret the spawn never holds; every cooperative client
(Claude Code, curl, requests/httpx, Bun, reqwest) sends it pre-emptively.

For each request the proxy reports `{spawn, tag, host, port, method, allowed}`
to the gateway (`POST /internal/egress/record`, clodia-tools). The gateway
checks the tag, records `egress.connect` under the trace of the spawn's current
turn — the trace of every `tool.call` of that turn — and answers with the trace
id and the event id, which go into this proxy's own log line. Two records, one
trace id, each naming the other.

The credentials are a LABEL, not a gate: a request without them is served
exactly as before (the allow-list is the gate) and recorded as unattributed.
The tag is never logged, never forwarded upstream.

## Log

One JSON object per line on stdout (`docker logs`), and in `EGRESS_LOG_FILE`
if set: `request` when a request is decided, `close` when its connection ends.
It is still the record of where the agents go (#104 §7), now with the turn.
"""
from __future__ import annotations

import asyncio
import base64
import binascii
import ipaddress
import itertools
import json
import os
import re
import socket
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timezone
from urllib.parse import urlsplit

ALLOWED_PORTS = frozenset({443, 80})
MAX_HEAD = 32 * 1024
HEAD_TIMEOUT_S = 30.0
IDLE_TIMEOUT_S = float(os.environ.get("EGRESS_IDLE_TIMEOUT", "600"))
CONNECT_TIMEOUT_S = 30.0
#: How long a write may wait for the peer to read. A client (or an upstream)
#: that stops reading would otherwise pin its slot until the idle timeout —
#: or forever, since the idle timer only runs on reads.
WRITE_TIMEOUT_S = float(os.environ.get("EGRESS_WRITE_TIMEOUT", "60"))
REPORT_TIMEOUT_S = float(os.environ.get("EGRESS_REPORT_TIMEOUT", "1.0"))
MAX_CLIENTS = int(os.environ.get("EGRESS_MAX_CLIENTS", "60"))

#: The spawn label and tag, as `audit.trace` in clodia-tools defines them.
_SPAWN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,95}$")
_TAG = re.compile(r"^[0-9a-f]{32}$")
#: What a destination host may be made of: a DNS name or an IP literal (IPv6
#: without its brackets). No whitespace, no control characters — a trailing
#: "\n" must not reach the allow-list, nor the resolver.
_HOST_CHARS = re.compile(r"[A-Za-z0-9._:-]{1,253}")
#: Hop-by-hop headers that never go upstream on a plain HTTP request.
_HOP = frozenset({"proxy-authorization", "proxy-connection", "connection",
                  "keep-alive", "te", "trailer", "upgrade", "proxy-authenticate"})

_CONN_IDS = itertools.count(1)


# ── policy ────────────────────────────────────────────────────────────────────
def load_allowlist(path: str) -> list[re.Pattern]:
    """Host patterns, one per line; `#` comments and blank lines ignored.

    A pattern must match the WHOLE host (`fullmatch`): the patterns are
    anchored in the file anyway, and `fullmatch` also closes the gap `$` leaves
    open under `search` — `$` matches before a trailing newline, so
    `^api\.anthropic\.com$` would accept `"api.anthropic.com\n"`.
    A line that does not compile is a deployment error: refuse to start."""
    out = []
    with open(path, encoding="utf-8") as fh:
        for n, raw in enumerate(fh, 1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            try:
                out.append(re.compile(line, re.IGNORECASE))
            except re.error as e:
                raise SystemExit(f"allowlist line {n}: {e}") from None
    return out


def valid_host(host: str) -> bool:
    return bool(_HOST_CHARS.fullmatch(host))


def host_allowed(host: str, patterns: list[re.Pattern]) -> bool:
    return valid_host(host) and any(p.fullmatch(host) for p in patterns)


def decide(method: str, host: str, port: int, patterns: list[re.Pattern]) -> tuple[bool, str | None]:
    if port not in ALLOWED_PORTS:
        return False, "port"
    if not host_allowed(host, patterns):
        return False, "filtered"
    return True, None


# ── resolved addresses ──────────────────────────────────────────────────────
#: Private ranges an allow-listed IP LITERAL may point into (the RAG service on
#: the LAN, `^192\.168\.1\.45$`). A NAME never may: a public name that
#: resolves into the LAN is a rebinding, not a destination.
_PRIVATE = tuple(ipaddress.ip_network(n) for n in (
    "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10", "fc00::/7"))


def internal_networks(env=os.environ) -> tuple:
    """The stack's own subnets: never a destination, not even as a literal."""
    out = []
    for var, default in (("CLODIA_INT_SUBNET", "172.31.7.0/24"),
                         ("CLODIA_EXT_SUBNET", "172.31.8.0/24")):
        raw = (env.get(var) or default).strip()
        try:
            out.append(ipaddress.ip_network(raw, strict=False))
        except ValueError:
            raise SystemExit(f"{var}={raw!r} is not a network") from None
    return tuple(out)


def address_refusal(host: str, addr: str, internal: tuple) -> str | None:
    """Why the proxy must not connect to `addr` (resolved from `host`), or None.

    Always refused: loopback, link-local, unspecified, multicast, reserved and
    the stack's internal subnets. Private ranges (RFC 1918, CGNAT, ULA): only
    when the request named that IP literally, i.e. the allow-list entry that
    let it through is itself the IP literal."""
    try:
        ip = ipaddress.ip_address(addr.split("%", 1)[0])
    except ValueError:
        return "address"
    if isinstance(ip, ipaddress.IPv6Address) and ip.ipv4_mapped:
        ip = ip.ipv4_mapped
    if (ip.is_loopback or ip.is_link_local or ip.is_unspecified or ip.is_multicast
            or ip.is_reserved or any(ip in n for n in internal)):
        return "address"
    if any(ip in n for n in _PRIVATE):
        try:
            literal = ipaddress.ip_address(host)
        except ValueError:
            return "address"
        if isinstance(literal, ipaddress.IPv6Address) and literal.ipv4_mapped:
            literal = literal.ipv4_mapped
        return None if literal == ip else "address"
    if not ip.is_global:
        return "address"
    return None


async def resolve(host: str, port: int) -> list[str]:
    """The addresses of `host`, in resolver order, without duplicates."""
    loop = asyncio.get_running_loop()
    infos = await loop.getaddrinfo(host, port, type=socket.SOCK_STREAM)
    out: list[str] = []
    for *_, sockaddr in infos:
        if sockaddr[0] not in out:
            out.append(sockaddr[0])
    return out


# ── parsing ───────────────────────────────────────────────────────────────────
class BadRequest(ValueError):
    pass


@dataclass
class Head:
    method: str
    target: str
    version: str
    headers: list[tuple[str, str]] = field(default_factory=list)

    def get(self, name: str) -> str | None:
        name = name.lower()
        for k, v in self.headers:
            if k.lower() == name:
                return v
        return None


def parse_head(data: bytes) -> Head:
    try:
        text = data.decode("latin-1")
    except UnicodeDecodeError:  # pragma: no cover - latin-1 decodes anything
        raise BadRequest("undecodable") from None
    lines = text.split("\r\n")
    parts = lines[0].split(" ")
    if len(parts) != 3 or not parts[2].startswith("HTTP/"):
        raise BadRequest("bad request line")
    headers = []
    for line in lines[1:]:
        if not line:
            continue
        k, sep, v = line.partition(":")
        if not sep or not k or k != k.strip():
            raise BadRequest("bad header")
        headers.append((k, v.strip()))
    return Head(parts[0].upper(), parts[1], parts[2], headers)


def split_target(head: Head) -> tuple[str, int, str]:
    """`(host, port, origin-form path)` of the request."""
    if head.method == "CONNECT":
        host, sep, port = head.target.rpartition(":")
        if not sep or not host or not port.isdigit():
            raise BadRequest("CONNECT needs host:port")
        host = host[1:-1] if host.startswith("[") and host.endswith("]") else host
        host = host.lower()
        if not valid_host(host):
            raise BadRequest("bad host")
        return host, int(port), ""
    u = urlsplit(head.target)
    if u.scheme.lower() != "http" or not u.hostname:
        raise BadRequest("only absolute http:// URLs are proxied")
    try:
        port = u.port or 80
    except ValueError:
        raise BadRequest("bad port") from None
    host = u.hostname.lower()
    if not valid_host(host):
        raise BadRequest("bad host")
    path = u.path or "/"
    if u.query:
        path += "?" + u.query
    return host, port, path


def _authority(host: str, port: int) -> str:
    h = f"[{host}]" if ":" in host else host
    return h if port == 80 else f"{h}:{port}"


def check_host_header(head: Head, host: str, port: int) -> None:
    """A plain HTTP request's `Host` must name the destination of its absolute
    URI — the one the allow-list judged. The origin reads `Host`, so a request
    that says `GET http://github.com/` with `Host: evil.example` would reach a
    virtual host nobody allowed. Missing is fine (it is written from the URI);
    different, or more than one, is a 400."""
    if head.method == "CONNECT":
        return
    values = [v for k, v in head.headers if k.lower() == "host"]
    if not values:
        return
    if len(values) > 1:
        raise BadRequest("more than one Host header")
    got = values[0].strip().lower()
    expected = {_authority(host, port)}
    if port == 80:
        expected.add(_authority(host, port) + ":80")
    if got not in expected:
        raise BadRequest("Host header does not match the request URI")


def credentials(head: Head) -> tuple[str | None, str | None]:
    """`(spawn, tag)` from `Proxy-Authorization: Basic`, or `(None, None)`.

    Anything that is not exactly a spawn label and a 32-hex tag is dropped
    here, so a real secret someone put in their own proxy URL can never end up
    in a log or in a report."""
    value = head.get("proxy-authorization") or ""
    scheme, _, blob = value.partition(" ")
    if scheme.lower() != "basic" or not blob:
        return None, None
    try:
        user, sep, pwd = base64.b64decode(blob.strip(), validate=True).decode("utf-8").partition(":")
    except (binascii.Error, UnicodeDecodeError, ValueError):
        return None, None
    if not (sep and _SPAWN.match(user) and _TAG.match(pwd.lower())):
        return None, None
    return user, pwd.lower()


def upstream_head(head: Head, host: str, port: int, path: str) -> bytes:
    """The plain HTTP request as the origin receives it: origin-form, no
    proxy credentials, one request per connection, and `Host` written from
    the absolute URI (like tinyproxy) — never the client's."""
    lines = [f"{head.method} {path} {head.version}", f"Host: {_authority(host, port)}"]
    for k, v in head.headers:
        lk = k.lower()
        if lk in _HOP or lk == "host":
            continue
        lines.append(f"{k}: {v}")
    lines.append("Connection: close")
    return ("\r\n".join(lines) + "\r\n\r\n").encode("latin-1")


# ── the join ──────────────────────────────────────────────────────────────────
def report(body: dict, url: str | None = None, secret: str | None = None,
           timeout: float = REPORT_TIMEOUT_S) -> dict | None:
    """Tell the gateway; return its answer (trace id, event id) or None."""
    url = url if url is not None else os.environ.get(
        "CLODIA_EGRESS_REPORT_URL", "http://clodia-tools:7849/internal/egress/record")
    secret = (secret if secret is not None
              else os.environ.get("CLODIA_EGRESS_PROXY_SECRET") or "").strip()
    if not url or not secret:
        return None
    req = urllib.request.Request(
        url, data=json.dumps(body).encode("utf-8"), method="POST",
        headers={"Content-Type": "application/json", "X-Egress-Proxy-Secret": secret})
    # The gateway is on the internal network: never through a proxy.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(req, timeout=timeout) as r:
            return json.loads(r.read(65536) or b"{}")
    except (urllib.error.URLError, OSError, ValueError):
        return None


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def record(conn: int, client: str, method: str, host: str, port: int,
           allowed: bool, reason: str | None, spawn: str | None,
           answer: dict | None) -> dict:
    """The log line of a decided request. The tag is not a parameter: it
    cannot end up here."""
    a = answer or {}
    return {
        "ts": _now(), "event": "request", "conn": conn, "client": client, "method": method,
        "host": host, "port": port, "allowed": allowed, "reason": reason,
        # The spawn as CLAIMED by the credentials, and whether the gateway
        # verified it. The trace id comes only from the gateway's answer.
        "spawn": spawn, "attribution": a.get("attribution") or ("claimed" if spawn else "none"),
        "trace_id": a.get("trace_id"), "span_id": a.get("span_id"),
        "event_id": a.get("event_id"), "reported": bool(a.get("recorded")),
    }


def decide_and_record(head: Head, client: str, patterns: list[re.Pattern], conn: int,
                      reporter=report, verdict: tuple[bool, str | None] | None = None,
                      ) -> tuple[dict, str, int, str]:
    """The pure part of a request: decision, report, log line. Returns
    `(line, host, port, path)`. Used as is by the server and by the tests.
    `verdict` is the server's final decision when it knows more than the
    allow-list (a resolved address it refuses)."""
    host, port, path = split_target(head)
    allowed, reason = verdict or decide(head.method, host, port, patterns)
    spawn, tag = credentials(head)
    body = {"spawn": spawn, "tag": tag, "host": host, "port": port,
            "method": head.method, "allowed": allowed, "reason": reason}
    answer = reporter(body)
    return record(conn, client, head.method, host, port, allowed, reason, spawn, answer), host, port, path


class Log:
    def __init__(self, path: str | None = None):
        self.fh = open(path, "a", encoding="utf-8", buffering=1) if path else None

    def write(self, obj: dict) -> None:
        line = json.dumps(obj, separators=(",", ":"), ensure_ascii=False)
        print(line, file=sys.stdout, flush=True)
        if self.fh:
            self.fh.write(line + "\n")


# ── server ────────────────────────────────────────────────────────────────────
class Stalled(Exception):
    """The peer of a write stopped reading for longer than WRITE_TIMEOUT_S."""


async def _drain(w: asyncio.StreamWriter) -> None:
    try:
        await asyncio.wait_for(w.drain(), WRITE_TIMEOUT_S)
    except asyncio.TimeoutError:
        raise Stalled() from None


async def _pipe(src: asyncio.StreamReader, dst: asyncio.StreamWriter, count: list) -> None:
    """Copy `src` into `dst` until EOF or idle. Raises `Stalled` when `dst`
    stops reading: the caller then tears down BOTH directions."""
    try:
        while True:
            chunk = await asyncio.wait_for(src.read(65536), IDLE_TIMEOUT_S)
            if not chunk:
                break
            count[0] += len(chunk)
            dst.write(chunk)
            await _drain(dst)
    except (asyncio.TimeoutError, ConnectionError, OSError):
        pass
    finally:
        try:
            if dst.can_write_eof():
                dst.write_eof()
        except (OSError, RuntimeError):
            pass


async def _dial(addrs: list[str], port: int):
    """Connect to the first reachable of the vetted addresses — by address, so
    what is connected is what was checked (no second resolution)."""
    for addr in addrs:
        try:
            return await asyncio.wait_for(asyncio.open_connection(addr, port),
                                          CONNECT_TIMEOUT_S)
        except (OSError, asyncio.TimeoutError):
            continue
    return None, None


async def _reply(writer: asyncio.StreamWriter, status: str) -> None:
    body = status.encode()
    writer.write(f"HTTP/1.1 {status}\r\nContent-Type: text/plain\r\n"
                 f"Content-Length: {len(body)}\r\nConnection: close\r\n\r\n".encode() + body)
    try:
        await _drain(writer)
    except (ConnectionError, OSError, Stalled):
        pass


class Proxy:
    def __init__(self, patterns: list[re.Pattern], log: Log, reporter=report,
                 resolver=resolve, address_check=None):
        self.patterns, self.log, self.reporter = patterns, log, reporter
        self.resolver = resolver
        internal = internal_networks()
        self.address_check = address_check or (
            lambda host, addr: address_refusal(host, addr, internal))
        self.slots = asyncio.Semaphore(MAX_CLIENTS)

    async def vet(self, host: str, port: int) -> tuple[list[str], str | None]:
        """`(addresses the proxy may connect to, refusal reason)`. An empty
        list without a reason is a resolution failure (a 502, as before)."""
        try:
            addrs = await asyncio.wait_for(self.resolver(host, port), CONNECT_TIMEOUT_S)
        except (OSError, asyncio.TimeoutError, UnicodeError):
            return [], None
        ok = [a for a in addrs if self.address_check(host, a) is None]
        if addrs and not ok:
            return [], "address"
        return ok, None

    async def handle(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        conn = next(_CONN_IDS)
        peer = writer.get_extra_info("peername") or ("?",)
        client = str(peer[0])
        if self.slots.locked():
            await _reply(writer, "503 Service Unavailable")
            writer.close()
            return
        async with self.slots:
            await self._serve(conn, client, reader, writer)

    async def _serve(self, conn, client, reader, writer) -> None:
        t0 = time.monotonic()
        up_reader = up_writer = None
        sent, received = [0], [0]
        stalled = abort = False
        try:
            try:
                raw = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), HEAD_TIMEOUT_S)
                head = parse_head(raw[:-4])
            except (asyncio.IncompleteReadError, asyncio.LimitOverrunError,
                    asyncio.TimeoutError, BadRequest, ConnectionError):
                await _reply(writer, "400 Bad Request")
                return
            try:
                host, port, path = split_target(head)
                check_host_header(head, host, port)
            except BadRequest:
                await _reply(writer, "400 Bad Request")
                return
            allowed, reason = decide(head.method, host, port, self.patterns)
            addrs: list[str] = []
            if allowed:
                # The allow-list judged the NAME; what is connected is an
                # address. Resolve once, refuse the internal ones, dial those.
                addrs, refusal = await self.vet(host, port)
                if refusal:
                    allowed, reason = False, refusal
            decided = asyncio.to_thread(decide_and_record, head, client, self.patterns,
                                        conn, self.reporter, (allowed, reason))
            if allowed:
                # Allowed: dial and report at the same time, so the report costs
                # no latency beyond the slower of the two. A refused destination
                # is never dialled.
                (line, *_), (up_reader, up_writer) = await asyncio.gather(
                    decided, _dial(addrs, port))
            else:
                line, *_ = await decided
            self.log.write(line)
            if not line["allowed"]:
                await _reply(writer, "403 Filtered")
                return
            if up_writer is None:
                await _reply(writer, "502 Bad Gateway")
                self.log.write({"ts": _now(), "event": "close", "conn": conn,
                                "error": "upstream_unreachable"})
                return
            if head.method == "CONNECT":
                writer.write(b"HTTP/1.1 200 Connection established\r\n\r\n")
                await _drain(writer)
            else:
                up_writer.write(upstream_head(head, host, port, path))
                await _drain(up_writer)
            pipes = [asyncio.ensure_future(_pipe(reader, up_writer, sent)),
                     asyncio.ensure_future(_pipe(up_reader, writer, received))]
            try:
                done, pending = await asyncio.wait(pipes,
                                                   return_when=asyncio.FIRST_EXCEPTION)
            finally:
                for p in pipes:
                    if not p.done():
                        p.cancel()
            stalled = any(p.done() and not p.cancelled() and isinstance(p.exception(), Stalled)
                          for p in pipes)
            if stalled:
                abort = True
                return
            await asyncio.gather(*pending, return_exceptions=True)
        except Stalled:
            stalled = abort = True
        except (ConnectionError, OSError):
            abort = True
        finally:
            for w in (up_writer, writer):
                if w is not None:
                    try:
                        # A stalled peer will never take the buffered bytes:
                        # abort, so the socket goes now and not at its leisure.
                        (w.transport.abort if abort else w.close)()
                    except (OSError, RuntimeError):
                        pass
            if up_writer is not None:
                line = {"ts": _now(), "event": "close", "conn": conn,
                        "bytes_up": sent[0], "bytes_down": received[0],
                        "duration_ms": int((time.monotonic() - t0) * 1000)}
                if stalled:
                    line["error"] = "peer_stalled"
                self.log.write(line)


async def main() -> None:
    patterns = load_allowlist(os.environ.get("EGRESS_ALLOWLIST", "/etc/egress/allowlist"))
    log = Log(os.environ.get("EGRESS_LOG_FILE") or None)
    proxy = Proxy(patterns, log)
    listen = os.environ.get("EGRESS_LISTEN", "0.0.0.0:8888")
    host, _, port = listen.rpartition(":")
    server = await asyncio.start_server(proxy.handle, host or "0.0.0.0", int(port),
                                        limit=MAX_HEAD)
    log.write({"ts": _now(), "event": "start", "listen": listen, "patterns": len(patterns),
               "reporting": bool((os.environ.get("CLODIA_EGRESS_PROXY_SECRET") or "").strip())})
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
