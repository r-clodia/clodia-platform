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
import itertools
import json
import os
import re
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
REPORT_TIMEOUT_S = float(os.environ.get("EGRESS_REPORT_TIMEOUT", "1.0"))
MAX_CLIENTS = int(os.environ.get("EGRESS_MAX_CLIENTS", "60"))

#: The spawn label and tag, as `audit.trace` in clodia-tools defines them.
_SPAWN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,95}$")
_TAG = re.compile(r"^[0-9a-f]{32}$")
#: Hop-by-hop headers that never go upstream on a plain HTTP request.
_HOP = frozenset({"proxy-authorization", "proxy-connection", "connection",
                  "keep-alive", "te", "trailer", "upgrade", "proxy-authenticate"})

_CONN_IDS = itertools.count(1)


# ── policy ────────────────────────────────────────────────────────────────────
def load_allowlist(path: str) -> list[re.Pattern]:
    """Host patterns, one per line; `#` comments and blank lines ignored.

    Matched with `search`, like tinyproxy's `regexec`: the patterns are
    anchored in the file, and an unanchored one would match inside a name.
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


def host_allowed(host: str, patterns: list[re.Pattern]) -> bool:
    return any(p.search(host) for p in patterns)


def decide(method: str, host: str, port: int, patterns: list[re.Pattern]) -> tuple[bool, str | None]:
    if port not in ALLOWED_PORTS:
        return False, "port"
    if not host_allowed(host, patterns):
        return False, "filtered"
    return True, None


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
        return host.lower(), int(port), ""
    u = urlsplit(head.target)
    if u.scheme.lower() != "http" or not u.hostname:
        raise BadRequest("only absolute http:// URLs are proxied")
    try:
        port = u.port or 80
    except ValueError:
        raise BadRequest("bad port") from None
    path = u.path or "/"
    if u.query:
        path += "?" + u.query
    return u.hostname.lower(), port, path


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
    proxy credentials, one request per connection."""
    lines = [f"{head.method} {path} {head.version}"]
    has_host = False
    for k, v in head.headers:
        lk = k.lower()
        if lk in _HOP:
            continue
        has_host = has_host or lk == "host"
        lines.append(f"{k}: {v}")
    if not has_host:
        lines.append(f"Host: {host}" + ("" if port == 80 else f":{port}"))
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
                      reporter=report) -> tuple[dict, str, int, str]:
    """The pure part of a request: decision, report, log line. Returns
    `(line, host, port, path)`. Used as is by the server and by the tests."""
    host, port, path = split_target(head)
    allowed, reason = decide(head.method, host, port, patterns)
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
async def _pipe(src: asyncio.StreamReader, dst: asyncio.StreamWriter, count: list) -> None:
    try:
        while True:
            chunk = await asyncio.wait_for(src.read(65536), IDLE_TIMEOUT_S)
            if not chunk:
                break
            count[0] += len(chunk)
            dst.write(chunk)
            await dst.drain()
    except (asyncio.TimeoutError, ConnectionError, OSError):
        pass
    finally:
        try:
            if dst.can_write_eof():
                dst.write_eof()
        except (OSError, RuntimeError):
            pass


async def _dial(host: str, port: int):
    try:
        return await asyncio.wait_for(asyncio.open_connection(host, port), CONNECT_TIMEOUT_S)
    except (OSError, asyncio.TimeoutError):
        return None, None


async def _reply(writer: asyncio.StreamWriter, status: str) -> None:
    body = status.encode()
    writer.write(f"HTTP/1.1 {status}\r\nContent-Type: text/plain\r\n"
                 f"Content-Length: {len(body)}\r\nConnection: close\r\n\r\n".encode() + body)
    try:
        await writer.drain()
    except (ConnectionError, OSError):
        pass


class Proxy:
    def __init__(self, patterns: list[re.Pattern], log: Log, reporter=report):
        self.patterns, self.log, self.reporter = patterns, log, reporter
        self.slots = asyncio.Semaphore(MAX_CLIENTS)

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
            except BadRequest:
                await _reply(writer, "400 Bad Request")
                return
            decided = asyncio.to_thread(decide_and_record, head, client, self.patterns,
                                        conn, self.reporter)
            if decide(head.method, host, port, self.patterns)[0]:
                # Allowed: dial and report at the same time, so the report costs
                # no latency beyond the slower of the two. A refused destination
                # is never dialled.
                (line, *_), (up_reader, up_writer) = await asyncio.gather(
                    decided, _dial(host, port))
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
                await writer.drain()
            else:
                up_writer.write(upstream_head(head, host, port, path))
                await up_writer.drain()
            await asyncio.gather(_pipe(reader, up_writer, sent),
                                 _pipe(up_reader, writer, received))
        finally:
            for w in (up_writer, writer):
                if w is not None:
                    try:
                        w.close()
                    except (OSError, RuntimeError):
                        pass
            if up_writer is not None:
                self.log.write({"ts": _now(), "event": "close", "conn": conn,
                                "bytes_up": sent[0], "bytes_down": received[0],
                                "duration_ms": int((time.monotonic() - t0) * 1000)})


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
