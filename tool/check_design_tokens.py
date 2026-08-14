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
  Duration(...) passed to a *Duration: named parameter
                                               -> use AppMotion.* (fast/medium/slow/shimmer)
  BoxShadow(...)                              -> use AppShadows.level1/2/3 or
                                                  AppElevation.shadowSm/Md/Lg

`.copyWith(` on an existing token, `const Color(0x00000000)` transparent, and
`EdgeInsets.zero` are intentionally NOT flagged -- those are normal, harmless.

The Duration check is deliberately narrow: it only fires when `Duration(...)`
is passed to a parameter whose own name ends in `duration`/`Duration`
(`duration:`, `transitionDuration:`, `reverseTransitionDuration:` -- the
actual Flutter convention for animation timing, e.g. AnimationController,
AnimatedOpacity, PageRouteBuilder.transitionDuration). A first attempt at
this check matched every `Duration(...)` literal anywhere and produced ~65
warnings, most of them false positives: network timeouts, polling
intervals, retry backoff, debounce/flush intervals -- business-logic timing
that has nothing to do with AppMotion (UI animation timing). Narrowing to
the named-parameter convention above dropped that to the real ~19 UI-timing
instances. Do not widen this regex back to a bare `Duration(` match without
re-auditing for that same false-positive class.

FontWeight, Icons.*, and .withOpacity( were each considered for a similar
check and deliberately NOT added:
  - FontWeight: raw `TextStyle(fontWeight: ...)` is already caught by the
    TEXTSTYLE_RE check above at the right point of intervention (the
    constructor, not each property inside it); a from-scratch look at every
    `FontWeight.*` hit found nearly all of the "raw-looking" ones were
    `AppTextStyles.x.copyWith(fontWeight: ...)` on a multi-line call --
    exactly the sanctioned override-a-token-for-one-property pattern this
    guard already allows. A separate line-based FontWeight regex can't
    reliably tell those apart from a genuinely raw `TextStyle(fontWeight:
    ...)` without the same multi-line body-tracking `check_a11y.py` uses
    for its IconButton( blocks, which isn't worth the complexity here since
    the outer-constructor check already covers the real violation.
  - Icons.*: unlike Color/TextStyle/Spacing/Radius/Motion/Shadow (a small,
    genuinely finite, fully-centralizable value set), Flutter's Icons class
    has thousands of members; most icon usages in the app are legitimately
    one-off (used in exactly one place) rather than a repeated design
    value. `lib/design_system/tokens/app_icons.dart` exists for icons that
    *are* reused/semantic, but mandating every single `Icons.x` reference
    route through it would be exactly the kind of "abstraction for its own
    sake" the project's own instructions warn against.
  - .withOpacity(: checked separately -- the codebase has already migrated
    essentially everywhere to `.withValues(alpha: ...)` (131 call sites);
    the one remaining `.withOpacity(` hit is inside a doc comment, not
    executable code. Nothing to enforce; noted here so a future contributor
    doesn't re-add this check against a problem that doesn't exist.

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
DURATION_NUM_RE = re.compile(
    r"\b\w*[Dd]uration\s*:\s*(?:const\s+)?Duration\(\s*"
    r"(?:milliseconds|seconds|minutes)\s*:\s*[1-9]\d*"
)
BOXSHADOW_RE = re.compile(r"(?<!\w)BoxShadow\(")


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

            if DURATION_NUM_RE.search(line):
                report.add(rel, i + 1,
                            "magic-number Duration(...) -- use an AppMotion.* token "
                            "(fast/medium/slow/shimmer)",
                            severity="WARN")

            if BOXSHADOW_RE.search(line):
                report.add(rel, i + 1,
                            "raw BoxShadow(...) -- use AppShadows.level1/2/3 or "
                            "AppElevation.shadowSm/Md/Lg instead of a one-off shadow",
                            severity="WARN")

    report.print_and_exit(
        fix_hint=(
            "Replace the literal with the matching token from "
            "lib/design_system/tokens/ (AppColors / AppTextStyles / AppSpacing / "
            "AppRadius / AppMotion / AppShadows / AppElevation). If no existing "
            "token fits, that's a signal the design system is missing a value -- "
            "add it as a new named token there instead of inlining another "
            "one-off literal."
        ),
    )


if __name__ == "__main__":
    main()
