#!/usr/bin/env python3
"""Which notebook entries are fixed by an automated test, and which are not.

Decision record 34: «solo i test automatici documentano il successo
dell'implementazione, anzi sono necessari ma non sufficienti». A requirement
confirmed by hand leaves nothing that can be run again — the next person cannot
re-take the measurement, and nothing tells them when it stopped being true.

This script answers the question mechanically, in both directions:

    is this requirement verified?          → entry → tests
    if I delete this test, what breaks?    → the test names its entry

The link is a **citation in the test**: a docstring (or comment) naming the entry
as `A12` or `R3`. Nothing is inferred from vocabulary — searching for an entry's
words across the test files finds 158 matches for one entry and none for another
that is perfectly covered, which measures the query rather than the code.

An entry with no citation is reported as UNCITED, not as untested: it may well be
covered by a test that never says so. That distinction is the point — the goal is
not to accuse the tests, it is to stop guessing.

Usage:
    scripts/notebook-coverage.py [--repos DIR] [--strict]

    --repos DIR   where the component repos are cloned (default: ./repos, the
                  layout clodia-platform itself uses)
    --strict      exit 1 if any entry is uncited (for CI)
"""
from __future__ import annotations

import argparse
import os
import pathlib
import re
import sys

NOTEBOOKS = {
    "agents-notebook.md": "A",
    "router-notebook.md": "R",
}
#: `## A12 · Titolo` — the id, then the title after the separator.
VOCE = re.compile(r"^##\s+((?:A|R)\d{1,2})\s+·\s+(.+?)\s*$", re.M)


def entries(docs: pathlib.Path) -> list[tuple[str, str, str]]:
    """(id, title, notebook) for every entry, in the order they were written."""
    out = []
    for nome, _prefisso in NOTEBOOKS.items():
        f = docs / nome
        if not f.is_file():
            print(f"! notebook assente: {f}", file=sys.stderr)
            continue
        for m in VOCE.finditer(f.read_text(encoding="utf-8")):
            out.append((m.group(1), m.group(2), nome))
    return out


def citations(repos: pathlib.Path) -> dict[str, set[str]]:
    """entry id → test files citing it.

    Only `test_*.py`: a citation in production code says where a rule lives, not
    that it is verified, and conflating the two would let a comment stand in for
    a test — the exact substitution entry 34 refuses.
    """
    # `A12` as a word, so `A12` matches and `A123`, `DATA12` do not.
    rif = re.compile(r"\b((?:A|R)\d{1,2})\b")
    trovate: dict[str, set[str]] = {}
    if not repos.is_dir():
        print(f"! repo dir assente: {repos} (passa --repos)", file=sys.stderr)
        return trovate
    # `os.walk(followlinks=True)` e non `rglob`: quest'ultimo non attraversa i
    # symlink di directory, e `repos/` è spesso una collezione di link ai cloni
    # di lavoro. Uno strumento che tace su una directory che non ha saputo
    # leggere è il difetto che questo script esiste per correggere.
    visti = 0
    for radice, _dirs, files_ in os.walk(repos, followlinks=True):
        if "/.git" in radice or "node_modules" in radice:
            continue
        for nome in files_:
            if not (nome.startswith("test_") and nome.endswith(".py")):
                continue
            f = pathlib.Path(radice) / nome
            visti += 1
            try:
                testo = f.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            # Solo docstring e commenti: un identificatore che capita di
            # chiamarsi `R2` in una formula non è una citazione.
            contesto = "\n".join(
                r for r in testo.splitlines()
                if '"""' in r or r.lstrip().startswith("#") or "notebook" in r.lower()
            )
            for m in rif.finditer(contesto):
                trovate.setdefault(m.group(1), set()).add(
                    str(f.relative_to(repos)))
    if not visti:
        print(f"! nessun file test_*.py sotto {repos}: percorso sbagliato?",
              file=sys.stderr)
    else:
        print(f"({visti} file di test letti sotto {repos})", file=sys.stderr)
    return trovate


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repos", default="repos",
                    help="dove sono clonati i repo componenti (default: ./repos)")
    ap.add_argument("--docs", default="docs")
    ap.add_argument("--strict", action="store_true",
                    help="exit 1 se una voce non è citata da nessun test")
    a = ap.parse_args()

    voci = entries(pathlib.Path(a.docs))
    cit = citations(pathlib.Path(a.repos))
    if not voci:
        print("nessuna voce trovata: sei nella root di clodia-platform?")
        return 2

    scoperte = []
    print(f"{'voce':<6} {'test':>5}  titolo")
    print("-" * 78)
    for vid, titolo, _nb in voci:
        files = sorted(cit.get(vid, ()))
        if not files:
            scoperte.append((vid, titolo))
            print(f"{vid:<6} {'—':>5}  {titolo[:60]}")
        else:
            print(f"{vid:<6} {len(files):>5}  {titolo[:60]}")
            for f in files:
                print(f"{'':<13}{f}")

    print("-" * 78)
    print(f"{len(voci)} voci · {len(voci) - len(scoperte)} citate · "
          f"{len(scoperte)} senza citazione")
    if scoperte:
        print("\nSenza un test che le nomini:")
        for vid, titolo in scoperte:
            print(f"  {vid} · {titolo}")
        print("\nUna voce non citata non è per forza non verificata: può essere")
        print("coperta da un test che non lo dice. Il rimedio è lo stesso —")
        print("citare la voce nel docstring del test che la fissa.")
    return 1 if (a.strict and scoperte) else 0


if __name__ == "__main__":
    raise SystemExit(main())
