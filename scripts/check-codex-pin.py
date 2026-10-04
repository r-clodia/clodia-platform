#!/usr/bin/env python3
"""The two copies of `base.Dockerfile` must pin the same runtime versions.

There are two of them and they are not a copy/paste accident: `docker/` builds
THIS instance, `builder/templates/docker/` is what the builder stamps into a new
one. A bump applied to one and not the other does not fail any build — it
quietly hands a newly created instance a different CLI from the one every agent
was tested on, and the symptom arrives much later as "that agent does not start"
(clodia-platform#493: `gpt-6-astra` answers HTTP 400 below codex 0.153.0).

The two files have already drifted in their comments, which is the cheap warning
that they can drift in a value. This checks the values only — the ARG pins — and
says nothing about the prose.

Usage:
    scripts/check-codex-pin.py            exit 1 on any mismatch
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
#: The two copies. Relative to the repo root, so the error message is citable.
COPIES = ("docker/base.Dockerfile", "builder/templates/docker/base.Dockerfile")
#: Pins that must agree. Only the agentic CLIs: the Python/Node base images are
#: already a single `FROM` line each and drift there is visible at build time.
PINS = ("OPENAI_CODEX_NPM_VERSION", "OPENCODE_NPM_VERSION")

_ARG = re.compile(r"^\s*ARG\s+(\w+)\s*=\s*(\S+)\s*$", re.MULTILINE)


def pins(path: Path) -> dict[str, str]:
    """`ARG NAME=value` declared in a Dockerfile, as a dict."""
    return dict(_ARG.findall(path.read_text(encoding="utf-8")))


def main() -> int:
    found = {}
    for rel in COPIES:
        f = ROOT / rel
        if not f.is_file():
            print(f"MANCANTE: {rel}")
            return 1
        found[rel] = pins(f)

    errori = []
    for name in PINS:
        valori = {rel: v.get(name) for rel, v in found.items()}
        if None in valori.values():
            errori.append(f"{name}: non dichiarato in " +
                          ", ".join(r for r, v in valori.items() if v is None))
        elif len(set(valori.values())) > 1:
            errori.append(f"{name}: " + " ≠ ".join(
                f"{v} ({r})" for r, v in valori.items()))

    for name in PINS:
        v = found[COPIES[0]].get(name)
        print(f"  {name} = {v}")
    if errori:
        print("\nI due base.Dockerfile non dichiarano lo stesso pin:")
        for e in errori:
            print(f"  {e}")
        print("\nUn bump va applicato a ENTRAMBE le copie: `docker/` costruisce")
        print("questa istanza, `builder/templates/docker/` quelle nuove.")
        return 1
    print(f"ok: {len(PINS)} pin identici nelle {len(COPIES)} copie")
    return 0


if __name__ == "__main__":
    sys.exit(main())
