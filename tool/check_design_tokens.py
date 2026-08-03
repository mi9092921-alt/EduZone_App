#!/usr/bin/env python3
"""
check_design_tokens.py — Design-system compliance guard for EduZone App.

EduZone has a real design-token system (lib/design_system/tokens/: AppColors,
AppTextStyles, AppSpacing, AppRadius, ...). This script flags places outside
that folder that bypass the tokens with raw literals, which is exactly how a
design system quietly rots: each individual raw Color(0xFF...) looks harmless,
but a few dozen of them is an undocumented second, drifting palette.

Flags (all outside lib/design_system/):
  Color(0x...)                                -> use an AppColors.* constant
  TextStyle(...)  [constructor call, not .copyWith] -> use AppTextStyles.* (+.copyWith if needed)
  EdgeInsets.all(<number>) / .symmetric(...)  -> use AppSpacing.* constants
  BorderRadius.circular(<number>)             -> use AppRadius.* constants

`.copyWith(` on an existing token, `const Color(0x00000000)` transparent, and
`EdgeInsets.zero` are intentionally NOT flagged -- those are normal, harmless.

Exit code: 0 = OK, 1 = violations found.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import Report, is_suppressed, iter_dart_files  # noqa: E402

EXCLUDE_DIRS = ("design_system",)

COLOR_RE = re.compile(r"(?<!App)(?<!\w)Color\(0x")
TEXTSTYLE_RE = re.compile(r"(?<!\w)TextStyle\(")
EDGEINSETS_NUM_RE = re.compile(r"EdgeInsets\.(all|symmetric)\([^)]*(?<![\w.])[1-9]\d*")
BORDERRADIUS_NUM_RE = re.compile(r"BorderRadius\.circular\((?<![\w.])[1-9]\d*")


def main() -> None:
    report = Report("Design-system token guard")

    for fpath, rel, lines in iter_dart_files(extra_exclude_dirs=EXCLUDE_DIRS):
        for i, line in enumerate(lines):
            if is_suppressed(line):
                continue

            if COLOR_RE.search(line):
                report.add(rel, i + 1,
                            "raw Color(0x...) literal -- use an AppColors.* token",
                            severity="ERROR")

            if TEXTSTYLE_RE.search(line):
                report.add(rel, i + 1,
                            "raw TextStyle(...) constructor -- use AppTextStyles.* "
                            "(with .copyWith(...) if a small variation is needed)",
                            severity="WARN")

            if EDGEINSETS_NUM_RE.search(line):
                report.add(rel, i + 1,
                            "magic-number EdgeInsets -- use an AppSpacing.* token",
                            severity="WARN")

            if BORDERRADIUS_NUM_RE.search(line):
                report.add(rel, i + 1,
                            "magic-number BorderRadius.circular(...) -- use an AppRadius.* token",
                            severity="WARN")

    report.print_and_exit(
        fix_hint=(
            "Replace the literal with the matching token from "
            "lib/design_system/tokens/ (AppColors / AppTextStyles / AppSpacing / "
            "AppRadius). If no existing token fits, that's a signal the design "
            "system is missing a value -- add it as a new named token there "
            "instead of inlining another one-off literal."
        ),
    )


if __name__ == "__main__":
    main()
