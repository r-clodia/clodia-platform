"""Egress proxy (clodia-platform#104, #463).

Run: `python3 -m unittest discover -s docker/egress -p "test_*.py"` (stdlib only).

The last class is the acceptance test of #463 across the two components: the
proxy's own decision-and-log function, reporting to the REAL gateway route of
clodia-tools, produces a log line whose trace id is the trace id of the
`tool.call` the gateway recorded in the same turn. It needs a clodia-tools
checkout (`CLODIA_TOOLS_SRC`, default `repos/clodia-tools`) with its
dependencies, and is skipped without one.
"""
from __future__ import annotations

import asyncio
import base64
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import egress_proxy as ep  # noqa: E402

SPAWN, TAG = "clodia-320", "0123456789abcdef0123456789abcdef"
TRACE, SPAN = "4bf92f3577b34da6a3ce929d0e0e4736", "00f067aa0ba902b7"


def _auth(user: str, pwd: str) -> str:
    return "Basic " + base64.b64encode(f"{user}:{pwd}".encode()).decode()


def _head(method="CONNECT", target="api.anthropic.com:443", auth: str | None = None) -> ep.Head:
    h = [("Host", target)]
    if auth:
        h.append(("Proxy-Authorization", auth))
    return ep.Head(method, target, "HTTP/1.1", h)


class AllowlistTests(unittest.TestCase):
    def setUp(self) -> None:
        self.patterns = ep.load_allowlist(str(HERE / "allowlist"))

    def test_the_shipped_list_loads_and_stays_anchored(self) -> None:
        self.assertGreater(len(self.patterns), 10)
        self.assertTrue(ep.host_allowed("api.anthropic.com", self.patterns))
        self.assertTrue(ep.host_allowed("API.Anthropic.com", self.patterns))
        self.assertFalse(ep.host_allowed("api.anthropic.com.attacker.tld", self.patterns))
        self.assertFalse(ep.host_allowed("evil-api.anthropic.com", self.patterns))
        self.assertFalse(ep.host_allowed("api.telegram.org", self.patterns))

    def test_ports(self) -> None:
        self.assertEqual(ep.decide("CONNECT", "github.com", 443, self.patterns), (True, None))
        self.assertEqual(ep.decide("CONNECT", "github.com", 22, self.patterns), (False, "port"))
        self.assertEqual(ep.decide("CONNECT", "example.com", 443, self.patterns),
                         (False, "filtered"))

    def test_a_broken_line_refuses_to_start(self) -> None:
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as fh:
            fh.write("^ok$\n^(broken$\n")
        self.addCleanup(os.unlink, fh.name)
        with self.assertRaises(SystemExit):
            ep.load_allowlist(fh.name)


class ParsingTests(unittest.TestCase):
    def test_connect_and_absolute_http(self) -> None:
        self.assertEqual(ep.split_target(_head()), ("api.anthropic.com", 443, ""))
        self.assertEqual(ep.split_target(_head(target="[::1]:443")), ("::1", 443, ""))
        self.assertEqual(ep.split_target(_head("GET", "http://Example.com/a?b=1")),
                         ("example.com", 80, "/a?b=1"))
        for bad in (_head(target="nohost"), _head("GET", "https://x/"), _head("GET", "/rel")):
            with self.assertRaises(ep.BadRequest):
                ep.split_target(bad)

    def test_parse_head(self) -> None:
        h = ep.parse_head(b"CONNECT github.com:443 HTTP/1.1\r\nHost: github.com:443\r\n"
                          b"Proxy-Authorization: " + _auth(SPAWN, TAG).encode())
        self.assertEqual((h.method, h.target), ("CONNECT", "github.com:443"))
        self.assertEqual(ep.credentials(h), (SPAWN, TAG))
        for bad in (b"GARBAGE", b"GET / HTTP/1.1\r\nno-colon"):
            with self.assertRaises(ep.BadRequest):
                ep.parse_head(bad)

    def test_only_a_spawn_label_and_a_tag_are_credentials(self) -> None:
        self.assertEqual(ep.credentials(_head(auth=_auth(SPAWN, TAG.upper()))), (SPAWN, TAG))
        for auth in (None, "Bearer x", "Basic !!!", _auth("alice", "hunter2"),
                     _auth(SPAWN, "short"), _auth("bad label", TAG), "Basic " +
                     base64.b64encode(b"nocolon").decode()):
            self.assertEqual(ep.credentials(_head(auth=auth)), (None, None), auth)

    def test_plain_http_goes_upstream_without_the_credentials(self) -> None:
        h = _head("GET", "http://example.com/x", auth=_auth(SPAWN, TAG))
        h.headers.append(("Proxy-Connection", "keep-alive"))
        out = ep.upstream_head(h, "example.com", 80, "/x").decode()
        self.assertTrue(out.startswith("GET /x HTTP/1.1\r\n"))
        self.assertNotIn("Proxy-", out)
        self.assertNotIn(TAG, out)
        self.assertIn("Connection: close", out)


class RecordTests(unittest.TestCase):
    def setUp(self) -> None:
        self.patterns = ep.load_allowlist(str(HERE / "allowlist"))
        self.sent: list[dict] = []

    def reporter(self, answer):
        def rep(body):
            self.sent.append(body)
            return answer
        return rep

    def test_the_log_line_carries_the_gateway_trace_and_never_the_tag(self) -> None:
        answer = {"recorded": True, "event_id": "e1", "trace_id": TRACE, "span_id": SPAN,
                  "spawn": SPAWN, "attribution": "verified"}
        line, *_ = ep.decide_and_record(_head(auth=_auth(SPAWN, TAG)), "172.31.7.5",
                                        self.patterns, 1, self.reporter(answer))
        self.assertEqual(self.sent, [{"spawn": SPAWN, "tag": TAG, "host": "api.anthropic.com",
                                      "port": 443, "method": "CONNECT", "allowed": True,
                                      "reason": None}])
        self.assertEqual((line["trace_id"], line["event_id"], line["attribution"]),
                         (TRACE, "e1", "verified"))
        self.assertTrue(line["reported"])
        self.assertNotIn(TAG, json.dumps(line))

    def test_without_the_gateway_the_request_is_still_logged(self) -> None:
        line, *_ = ep.decide_and_record(_head("CONNECT", "example.com:443",
                                              auth=_auth(SPAWN, TAG)),
                                        "c", self.patterns, 2, self.reporter(None))
        self.assertEqual((line["allowed"], line["reason"], line["trace_id"],
                          line["attribution"], line["reported"]),
                         (False, "filtered", None, "claimed", False))

    def test_report_is_off_without_a_secret(self) -> None:
        self.assertIsNone(ep.report({"x": 1}, url="http://127.0.0.1:9/", secret=""))
        # and an unreachable gateway is a None, not an exception
        self.assertIsNone(ep.report({"x": 1}, url="http://127.0.0.1:9/", secret="s",
                                    timeout=0.2))


class ServerTests(unittest.IsolatedAsyncioTestCase):
    """The proxy as a server: a CONNECT tunnel to a local echo, and a refusal."""

    async def asyncSetUp(self) -> None:
        async def echo(r, w):
            data = await r.read(100)
            w.write(b"echo:" + data)
            await w.drain()
            w.close()
        self.upstream = await asyncio.start_server(echo, "127.0.0.1", 0)
        self.up_port = self.upstream.sockets[0].getsockname()[1]
        self.lines: list[dict] = []
        log = ep.Log()
        log.write = self.lines.append
        self.reports: list[dict] = []

        def rep(body):
            self.reports.append(body)
            return {"recorded": True, "event_id": "ev", "trace_id": TRACE, "span_id": SPAN,
                    "attribution": "verified"}
        import re
        self.proxy = ep.Proxy([re.compile(r"^127\.0\.0\.1$")], log, rep)
        self.server = await asyncio.start_server(self.proxy.handle, "127.0.0.1", 0,
                                                 limit=ep.MAX_HEAD)
        self.port = self.server.sockets[0].getsockname()[1]
        self.ports = patch.object(ep, "ALLOWED_PORTS", frozenset({self.up_port}))
        self.ports.start()

    async def asyncTearDown(self) -> None:
        self.ports.stop()
        self.server.close()
        self.upstream.close()

    async def _connect(self, target: str, auth: str | None):
        r, w = await asyncio.open_connection("127.0.0.1", self.port)
        req = f"CONNECT {target} HTTP/1.1\r\nHost: {target}\r\n"
        if auth:
            req += f"Proxy-Authorization: {auth}\r\n"
        w.write((req + "\r\n").encode())
        await w.drain()
        return r, w

    async def test_a_labelled_tunnel_is_served_and_logged_with_its_trace(self) -> None:
        r, w = await self._connect(f"127.0.0.1:{self.up_port}", _auth(SPAWN, TAG))
        status = await r.readuntil(b"\r\n\r\n")
        self.assertTrue(status.startswith(b"HTTP/1.1 200"))
        w.write(b"ping")
        await w.drain()
        self.assertEqual(await r.read(100), b"echo:ping")
        w.close()
        for _ in range(50):
            if any(x.get("event") == "close" for x in self.lines):
                break
            await asyncio.sleep(0.02)
        req = self.lines[0]
        self.assertEqual((req["event"], req["allowed"], req["spawn"], req["trace_id"]),
                         ("request", True, SPAWN, TRACE))
        self.assertEqual(self.reports[0]["tag"], TAG)
        self.assertNotIn(TAG, json.dumps(self.lines))
        close = next(x for x in self.lines if x["event"] == "close")
        self.assertEqual(close["conn"], req["conn"])
        self.assertEqual(close["bytes_up"], 4)

    async def test_a_filtered_host_is_refused_and_never_dialled(self) -> None:
        r, w = await self._connect(f"localhost:{self.up_port}", None)
        status = await r.readuntil(b"\r\n\r\n")
        self.assertTrue(status.startswith(b"HTTP/1.1 403"))
        w.close()
        self.assertEqual((self.lines[0]["allowed"], self.lines[0]["reason"],
                          self.lines[0]["spawn"]), (False, "filtered", None))
        self.assertFalse(any(x.get("event") == "close" for x in self.lines))

    async def test_garbage_is_a_400(self) -> None:
        r, w = await asyncio.open_connection("127.0.0.1", self.port)
        w.write(b"HELLO\r\n\r\n")
        await w.drain()
        self.assertTrue((await r.readuntil(b"\r\n\r\n")).startswith(b"HTTP/1.1 400"))
        w.close()


def _tools_src() -> Path | None:
    src = Path(os.environ.get("CLODIA_TOOLS_SRC") or HERE.parents[1] / "repos" / "clodia-tools")
    return src if (src / "server" / "egress_proxy_api.py").is_file() else None


@unittest.skipUnless(_tools_src(), "needs a clodia-tools checkout with #463 (CLODIA_TOOLS_SRC)")
class ProxyRecordJoinsTheToolCallTests(unittest.TestCase):
    """#463 acceptance: the proxy record and the `tool.call` share a trace id."""

    def setUp(self) -> None:
        src = str(_tools_src())
        if src not in sys.path:
            sys.path.insert(0, src)
        try:
            from starlette.applications import Starlette
            from starlette.testclient import TestClient
            from server import audit_api, egress_proxy_api, main  # noqa: F401
            from server.audit import trace
            from server.claims import ClaimsContext
        except ImportError as e:  # pragma: no cover - dependencies absent
            self.skipTest(f"clodia-tools dependencies missing: {e}")
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        base = Path(self.tmp.name)
        env = patch.dict(os.environ, {"CLODIA_AUDIT_DIR": str(base / "a"),
                                      "CLODIA_AUDIT_KEY_DIR": str(base / "k"),
                                      "CLODIA_DATA": str(base / "d"),
                                      "CLODIA_ORCHESTRATOR_SECRET": "orch",
                                      "CLODIA_EGRESS_PROXY_SECRET": "px"})
        env.start()
        self.addCleanup(env.stop)
        trace._by_spawn.clear()
        self.trace, self.main, self.ClaimsContext = trace, main, ClaimsContext
        self.gw = TestClient(Starlette(routes=audit_api.routes + egress_proxy_api.routes))
        self.root = base / "a"

    def events(self) -> list[dict]:
        out = []
        for seg in sorted(self.root.glob("events-*.jsonl")):
            out += [json.loads(x) for x in seg.read_text().splitlines() if x.strip()]
        return out

    def test_shared_trace(self) -> None:
        from mcp.types import TextContent
        # 1. the agent-server opens the turn
        self.gw.post("/internal/audit/event", headers={"x-orchestrator-secret": "orch"}, json={
            "type": "turn.start", "action": "start", "trace_id": TRACE, "span_id": SPAN,
            "agent": {"seed": "clodia", "spawn": SPAWN}})

        # 2. the spawn calls a verb through the gateway
        async def inner(name, arguments):
            return [TextContent(type="text", text="ok")]

        async def call():
            with self.ClaimsContext({"agent": "clodia", "execution_id": SPAWN}, "t"), \
                    patch.object(self.main, "_call_tool_unaudited", inner):
                return await self.main.call_tool("web.fetch", {})
        asyncio.run(call())

        # 3. the same spawn's runtime opens a tunnel through the proxy, with the
        #    credentials the agent-server gave it
        tag = self.trace.egress_tag(SPAWN)

        def reporter(body):
            r = self.gw.post("/internal/egress/record", headers={"x-egress-proxy-secret": "px"},
                             json=body)
            return r.json() if r.status_code == 200 else None

        line, *_ = ep.decide_and_record(_head(auth=_auth(SPAWN, tag)), "172.31.7.5",
                                        ep.load_allowlist(str(HERE / "allowlist")), 7, reporter)
        evs = self.events()
        call_ev = next(e for e in evs if e["event"]["type"] == "tool.call")
        proxy_ev = next(e for e in evs if e["event"]["type"] == "egress.connect")
        self.assertEqual(line["trace_id"], TRACE)
        self.assertEqual(call_ev["trace_id"], line["trace_id"])
        self.assertEqual(proxy_ev["trace_id"], line["trace_id"])
        self.assertEqual(proxy_ev["event_id"], line["event_id"])
        self.assertEqual(line["attribution"], "verified")
        self.assertNotIn(tag, json.dumps(line) + json.dumps(evs))


if __name__ == "__main__":
    unittest.main()
