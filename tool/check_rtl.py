#!/usr/bin/env python3
"""
check_rtl.py — RTL layout guard for EduZone App.

EduZone ships Arabic (app_ar.arb) as a primary locale alongside English, so
any *physical* (left/right) layout API instead of a *directional* (start/end)
one will render mirrored/wrong in RTL without Flutter or `flutter analyze`
ever raising a warning -- these are all valid, compiling Dart.

Flags:
  EdgeInsets.only(left: / right: ...)   -> EdgeInsetsDirectional.only(start:/end:)
  EdgeInsets.fromLTRB(...)              -> EdgeInsetsDirectional.fromSTEB(...)
  Alignment.centerLeft / centerRight /
    topLeft / topRight / bottomLeft /
    bottomRight                         -> AlignmentDirectional equivalents
  Positioned(left: / right: ...)        -> PositionedDirectional(start:/end:)
  TextAlign.left / TextAlign.right      -> TextAlign.start / TextAlign.end

Some of these are legitimate even in an RTL-aware app (e.g. a phone-number
field, a code snippet, or a deliberately-fixed watermark that should NOT
mirror). Suppress a specific, reviewed line with a trailing `// check-ignore`
comment rather than leaving it as a silent violation.

Exit code: 0 = OK, 1 = violations found.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import Report, is_suppressed, iter_dart_files  # noqa: E402

PATTERNS: list[tuple[re.Pattern, str, str]] = [
    (
        re.compile(r"EdgeInsets\.only\([^)]*\b(left|right)\s*:"),
        "EdgeInsets.only(left:/right: ...)",
        "use EdgeInsetsDirectional.only(start:/end: ...)",
    ),
    (
        re.compile(r"EdgeInsets\.fromLTRB\("),
        "EdgeInsets.fromLTRB(...)",
        "use EdgeInsetsDirectional.fromSTEB(start, top, end, bottom)",
    ),
    (
        re.compile(r"\bAlignment\.(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)\b"),
        "Alignment.{}",  # filled in below
        "use the AlignmentDirectional equivalent (e.g. AlignmentDirectional.centerStart)",
    ),
    (
        re.compile(r"\bPositioned\([^)]*\b(left|right)\s*:"),
        "Positioned(left:/right: ...)",
        "use PositionedDirectional(start:/end: ...)",
    ),
    (
        re.compile(r"\bTextAlign\.(left|right)\b"),
        "TextAlign.{}",
        "use TextAlign.start / TextAlign.end",
    ),
]


def main() -> None:
    report = Report("RTL layout guard")

    for fpath, rel, lines in iter_dart_files():
        for i, line in enumerate(lines):
            if is_suppressed(line):
                continue
            for pattern, label, fix in PATTERNS:
                m = pattern.search(line)
                if not m:
                    continue
                shown = label.format(m.group(1)) if "{}" in label else label
                report.add(rel, i + 1, f"{shown} -- {fix}", severity="ERROR")

    report.print_and_exit(
        fix_hint=(
            "Replace the physical (left/right) API with its directional "
            "(start/end) equivalent so layout flips correctly under the "
            "Arabic (RTL) locale. If the physical direction is intentional "
            "(e.g. content that must never mirror), append `// check-ignore` "
            "to that line after confirming it visually in RTL."
        ),
    )


if __name__ == "__main__":
    main()
