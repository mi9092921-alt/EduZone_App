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

  ListView(/GridView(/ListView.builder(/GridView.builder( with
  `shrinkWrap: true` but WITHOUT `NeverScrollableScrollPhysics` in the same
  block (P8.8 in the performance roadmap: "ShrinkWrap abuse")
    -> shrinkWrap forces the scrollable to lay out every child up front to
       measure its own extent, which defeats lazy building even when
       `.builder`/`.separated` is already used. `shrinkWrap: true` paired
       with `physics: const NeverScrollableScrollPhysics()` is the
       standard, deliberate pattern for embedding a short, bounded list
       inside another scrollable (verified against several existing call
       sites in this codebase, including ones with an explicit "P8.8 fix"
       comment already reviewing this exact tradeoff) and is NOT flagged.
       `shrinkWrap: true` WITHOUT that physics override is the real smell:
       paying the eager-layout cost while the list also remains
       independently scrollable is almost never the intended combination
       -- if it scrolls on its own, it should not be shrink-wrapped.

  IntrinsicHeight(...) / IntrinsicWidth(...)
    -> both force a two-pass layout (lay out every child once to measure,
       then again to size to the max), which is O(n) extra layout work per
       build and gets more expensive the larger/deeper the subtree is.
       Usually a fixed size, CrossAxisAlignment.stretch, or a differently
       structured layout avoids the need for it; flagged as a WARN (not an
       ERROR) because there are legitimate uses (aligning mismatched-height
       siblings) -- this is a "make sure this was a deliberate choice" flag,
       not an automatic violation.

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

LISTVIEW_GRIDVIEW_RE = re.compile(r"\b(ListView|GridView)(?:\.(builder|separated))?\(")
IMAGE_NETWORK_RE = re.compile(r"\bImage\.network\(")
INLINE_ASYNC_RE = re.compile(r"\b(future|stream)\s*:\s*[a-zA-Z_]\w*\s*\(")
INTRINSIC_RE = re.compile(r"\b(IntrinsicHeight|IntrinsicWidth)\(")
MAP_CALL_RE = re.compile(r"\.map\(")
SHRINKWRAP_TRUE_RE = re.compile(r"\bshrinkWrap\s*:\s*true\b")
NEVER_SCROLLABLE_RE = re.compile(r"\bNeverScrollableScrollPhysics\b")


def block_contains(
    lines: list[str], start: int, pattern: re.Pattern[str], max_lookahead: int = 40
) -> bool:
    """Cheap heuristic: does `pattern` appear within the next N lines (same widget block)?"""
    depth = 0
    seen_open = False
    for line in lines[start: start + max_lookahead]:
        if pattern.search(line):
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
            if m:
                widget = m.group(1)
                is_builder_variant = m.group(2) is not None

                if not is_builder_variant and block_contains(lines, i, MAP_CALL_RE):
                    report.add(
                        rel, i + 1,
                        f"{widget}(...) built from a .map(...) collection -- "
                        f"use {widget}.builder(...) for lazy item building",
                        severity="ERROR",
                    )

                if block_contains(
                    lines, i, SHRINKWRAP_TRUE_RE
                ) and not block_contains(lines, i, NEVER_SCROLLABLE_RE):
                    report.add(
                        rel, i + 1,
                        f"{widget}{'.builder' if is_builder_variant else ''}(...) has "
                        "shrinkWrap: true without physics: "
                        "NeverScrollableScrollPhysics() -- paying the eager-layout "
                        "cost of shrinkWrap while the list also remains "
                        "independently scrollable is almost never intended; if this "
                        "is a short, bounded list nested inside another scrollable, "
                        "pair shrinkWrap with NeverScrollableScrollPhysics (the "
                        "pattern already used elsewhere in this codebase) -- if it "
                        "genuinely needs its own scrolling, drop shrinkWrap and "
                        "bound it with a sized/Expanded ancestor instead",
                        severity="ERROR",
                    )

            im_intrinsic = INTRINSIC_RE.search(line)
            if im_intrinsic:
                report.add(
                    rel, i + 1,
                    f"{im_intrinsic.group(1)}(...) forces a two-pass layout (measure, "
                    "then size to the max) -- expensive the larger/deeper the subtree "
                    "is; confirm this is a deliberate choice (e.g. aligning "
                    "mismatched-height siblings) rather than the default reach for a "
                    "layout problem with a cheaper fix (fixed size, "
                    "CrossAxisAlignment.stretch, restructuring the layout)",
                    severity="WARN",
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
            "shrinkWrap: true should be paired with physics: "
            "NeverScrollableScrollPhysics() (a short list nested inside another "
            "scrollable) -- otherwise drop shrinkWrap and bound the list's size "
            "from an ancestor instead. "
            "IntrinsicHeight/IntrinsicWidth: confirm the two-pass layout "
            "cost is deliberate, or restructure to avoid it. "
            "Image.network: replace with CachedNetworkImage. "
            "FutureBuilder/StreamBuilder: store the Future/Stream in state "
            "(initState, a late field, or a Riverpod provider) instead of "
            "calling the function directly in the future:/stream: argument."
        ),
    )


if __name__ == "__main__":
    main()
