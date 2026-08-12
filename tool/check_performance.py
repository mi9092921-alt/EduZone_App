#!/usr/bin/env python3
"""
check_performance.py — Flutter performance guard for EduZone App.

Deliberately narrow scope: only checks patterns `flutter analyze` +
flutter_lints (see analysis_options.yaml -- prefer_const_constructors etc.
already cover the const-related cases) do NOT catch, and that this codebase
has already been shown to mostly avoid, so the bar for "worth a script" is
that a violation is a real, fixable perf bug, not a style nit.

Flags:
  ListView( / GridView( constructed with a `children:` list that is itself
  built from `.map(` over a collection, when NOT already using the
  `.builder`/`.separated` constructor
    -> use `.builder` so items are lazily laid out instead of the whole
       (possibly unbounded) list being built up front on every rebuild.
       (Column/Row are intentionally not flagged here: they have no
       `.builder` equivalent, and are normally fine for short, fixed content
       -- that's a design judgement call, not a mechanical one.)

  Image.network(...)
    -> the project already depends on cached_network_image elsewhere; a raw
       Image.network bypasses that cache, re-downloading on every rebuild
       and giving no placeholder/error handling for slow connections.

  FutureBuilder( / StreamBuilder( whose `future:`/`stream:` argument is a
  bare function call (e.g. `future: fetchData()`) rather than a field/
  variable/provider read
    -> a fresh Future/Stream is created on every rebuild, re-triggering the
       async work (classic Flutter bug -- should be created once in
       initState/a provider and passed in as a value).

Exit code: 0 = OK, 1 = violations found.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import Report, is_suppressed, iter_dart_files  # noqa: E402

LISTVIEW_GRIDVIEW_RE = re.compile(r"\b(ListView|GridView)\(")
BUILDER_RE = re.compile(r"\b(ListView|GridView)\.(builder|separated)\(")
IMAGE_NETWORK_RE = re.compile(r"\bImage\.network\(")
INLINE_ASYNC_RE = re.compile(r"\b(future|stream)\s*:\s*[a-zA-Z_]\w*\s*\(")


def block_contains_map(lines: list[str], start: int, max_lookahead: int = 40) -> bool:
    """Cheap heuristic: does '.map(' appear within the next N lines (same widget block)?"""
    depth = 0
    seen_open = False
    for line in lines[start: start + max_lookahead]:
        if ".map(" in line:
            return True
        for ch in line:
            if ch == "(":
                depth += 1
                seen_open = True
            elif ch == ")":
                depth -= 1
        if seen_open and depth <= 0:
            break
    return False


def main() -> None:
    report = Report("Performance guard")

    for fpath, rel, lines in iter_dart_files():
        for i, line in enumerate(lines):
            if is_suppressed(line):
                continue

            m = LISTVIEW_GRIDVIEW_RE.search(line)
            if m and not BUILDER_RE.search(line):
                widget = m.group(1)
                if block_contains_map(lines, i):
                    report.add(
                        rel, i + 1,
                        f"{widget}(...) built from a .map(...) collection -- "
                        f"use {widget}.builder(...) for lazy item building",
                        severity="ERROR",
                    )

            if IMAGE_NETWORK_RE.search(line):
                report.add(
                    rel, i + 1,
                    "raw Image.network(...) -- use CachedNetworkImage(...) "
                    "(already a project dependency) for caching + placeholder/error handling",
                    severity="ERROR",
                )

            im = INLINE_ASYNC_RE.search(line)
            if im:
                report.add(
                    rel, i + 1,
                    f"{im.group(1)}: calls a function inline -- if this widget "
                    f"can rebuild (e.g. it's inside build()), a new "
                    f"{'Future' if im.group(1) == 'future' else 'Stream'} is created "
                    "and the async work restarts on every rebuild; hoist it to "
                    "initState/a provider and pass the stored instance instead",
                    severity="WARN",
                )

    report.print_and_exit(
        fix_hint=(
            "ListView/GridView: switch to the .builder/.separated constructor "
            "with itemCount + itemBuilder instead of pre-mapping every item. "
            "Image.network: replace with CachedNetworkImage. "
            "FutureBuilder/StreamBuilder: store the Future/Stream in state "
            "(initState, a late field, or a Riverpod provider) instead of "
            "calling the function directly in the future:/stream: argument."
        ),
    )


if __name__ == "__main__":
    main()
