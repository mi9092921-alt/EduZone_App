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
  EdgeInsets.all/only/symmetric/fromLTRB with a numeric argument
                                              -> use AppSpacing.* constants
                                                 (block-scanned: catches
                                                 MULTI-LINE calls, which the
                                                 original single-line regex
                                                 silently missed)
  BorderRadius.circular(<number>)             -> use AppRadius.* constants
  Radius.circular(<number>)                   -> use AppRadius.* constants
  SizedBox(height: <n> / width: <n>)          -> use an AppSpacing.* constant
  Colors.white (raw material Colors class)    -> use AppColors.neutral0
                                                 (mapping-based: only raw
                                                 Colors.<name> values that have
                                                 an EXACT AppColors token are
                                                 flagged -- see RAW_COLORS_EXACT_MAP)
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
BORDERRADIUS_NUM_RE = re.compile(r"BorderRadius\.circular\((?<![\w.])[1-9]\d*")
DURATION_NUM_RE = re.compile(
    r"\b\w*[Dd]uration\s*:\s*(?:const\s+)?Duration\(\s*"
    r"(?:milliseconds|seconds|minutes)\s*:\s*[1-9]\d*"
)
BOXSHADOW_RE = re.compile(r"(?<!\w)BoxShadow\(")

# ---------------------------------------------------------------------------
# v2 additions
#
# (a) SizedBox(height:/width: <numeric literal>) -- the same magic-number
#     class as the EdgeInsets/BorderRadius rules, but the constructor name
#     precedes the named argument, so it needs its own pattern. `\s*` spans
#     newlines so multi-line `SizedBox(\n  height: 240,\n)` is caught too.
SIZEDBOX_NUM_RE = re.compile(
    r"\bSizedBox\(\s*(?:height|width)\s*:\s*(?<![\w.])[1-9]\d*"
)

# (b) Raw material `Colors.*` where an EXACT AppColors token exists.
#     Deliberately mapping-based: only names with a value-identical token are
#     flagged, so the error always names a real replacement and never
#     false-positives on a value the design system simply doesn't define.
#       white    -> AppColors.neutral0 (AppColors.neutral0 == Colors.white)
#     Colors.transparent is intentionally NOT flagged -- same precedent as
#     `const Color(0x00000000)` above (transparent is normal, harmless).
#     Families like white70/white54/white30/white24/white12/black54/black87/
#     black26/grey/redAccent/amber have NO exact token and are therefore NOT
#     flagged; add the token first, then an entry here.
RAW_COLORS_EXACT_MAP = {
    "white": "AppColors.neutral0",
}
RAW_COLORS_EXACT_RE = re.compile(
    r"(?<![\w.])Colors\.(" + "|".join(RAW_COLORS_EXACT_MAP) + r")\b"
)

# (c) EdgeInsets.all/only/symmetric/fromLTRB with a numeric argument,
#     INCLUDING multi-line calls. The original line-based
#     `EdgeInsets\.(all|symmetric)\([^)]*[0-9]` regex could never see a
#     value on a continuation line, so e.g.
#         EdgeInsets.symmetric(
#           horizontal: 6,
#         )
#     passed silently. This check extracts the balanced paren block and
#     scans it for numeric literals instead. Replaces the old rule.
EDGEINSETS_CALL_RE = re.compile(r"\bEdgeInsets\.(all|only|symmetric|fromLTRB)\s*\(")
NUMERIC_ARG_RE = re.compile(r"(?<![\w.])[1-9]\d*(?:\.\d+)?")

# (d) Standalone Radius.circular(<number>). `\b` before "Radius" guarantees
#     BorderRadius.circular(...) is NOT matched here (it has its own rule
#     above), since the substring "Radius.circular" never starts a word
#     boundary inside "BorderRadius".
RADIUS_CIRCULAR_NUM_RE = re.compile(r"\bRadius\.circular\((?<![\w.])[1-9]\d*")


def extract_paren_block(text: str, open_paren_idx: int) -> str:
    """Returns the substring from `open_paren_idx` (a '(') through its
    matching ')', tracking nesting depth. Falls back to the rest of the
    text if unbalanced (should not happen in valid Dart)."""
    depth = 0
    i = open_paren_idx
    n = len(text)
    while i < n:
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return text[open_paren_idx:i + 1]
        i += 1
    return text[open_paren_idx:]


# ---------------------------------------------------------------------------
# Narrowly-scoped exemptions (v1 audit -- every entry consciously reviewed).
#
# These are pre-existing sites the new rules trip that were NOT auto-fixed in
# the pass that introduced the rules. Each entry is keyed by repo-relative
# path; a key ending in "/" exempts the whole directory. The value is the
# documented justification. Prefer fixing with tokens over adding entries;
# prefer a `// check-ignore` on the specific line when only one site in a
# file is deliberate.
RAW_COLORS_EXEMPT = {
    # Video-player surfaces render controls over live video: white/black
    # families are functional overlay colors, and most siblings in the same
    # files (white70, black54, ...) have no exact token yet, so these files
    # migrate together in a dedicated pass rather than piecemeal.
    "lib/features/video_player/": "player overlays over video content (v1)",
    "lib/features/downloads/presentation/widgets/offline_player/":
        "offline-player overlays over video content (v1)",
    "lib/features/downloads/presentation/screens/offline_player_screen.dart":
        "offline-player surface over video content (v1)",
    # Splash glassmorphism: white glass fill over animated brand artwork.
    "lib/features/auth/presentation/screens/splash_screen.dart":
        "splash glassmorphism over artwork (v1)",
    "lib/features/auth/presentation/screens/splash/":
        "splash glassmorphism over artwork (v1)",
    # White text/icons composited over gradient imagery / colored fills --
    # over-artwork colors, same rationale as the player surfaces.
    "lib/features/home/presentation/widgets/discovery_banner.dart":
        "text over gradient artwork (v1)",
    "lib/features/home/presentation/widgets/welcome_header.dart":
        "text over gradient artwork (v1)",
    "lib/features/courses/presentation/screens/course_preview_screen.dart":
        "controls over hero artwork (v1)",
    "lib/shared/components/course_card/discover_course_card.dart":
        "overlay over thumbnail artwork (v1)",
    "lib/features/todo/presentation/widgets/components/todo_swipe_background.dart":
        "icon glyph on colored swipe fill (v1)",
    "lib/shared/components/todo/todo_checkbox.dart":
        "check glyph on colored fill (v1)",
    "lib/shared/components/optional_update_dialog.dart":
        "content on primary-colored dialog artwork (v1)",
    "lib/core/utils/global_error_handler.dart":
        "blocking error overlay surface (v1)",
}

SIZEDBOX_EXEMPT = {
    # 208 = the recent-course card width; the loading shimmer must match it
    # exactly. No AppSpacing token exists for a card width (v1).
    "lib/features/home/presentation/screens/home_screen.dart":
        "208 recent-course card width, no token (v1)",
    "lib/features/courses/presentation/screens/discover_screen.dart":
        "200/240 discover card dims, no token (v1)",
    "lib/features/todo/presentation/widgets/add_todo_bottom_sheet.dart":
        "54 fixed sheet header height, no token (v1)",
    # 48 == AppSpacing.xl4; left for the file owner to tokenize (v1).
    "lib/shared/components/course/instructor_card.dart":
        "48 == AppSpacing.xl4, pending migration (v1)",
    "lib/features/video_player/presentation/widgets/player4/player4_seek_bar.dart":
        "20 seek-bar height, no token (v1)",
}

EDGEINSETS_EXEMPT = {
    "lib/features/courses/presentation/widgets/course_curriculum_preview.dart":
        "4==AppSpacing.xs2, 6==AppSpacing.xs, 2==AppSpacing.hairline; "
        "pending migration (v1)",
    "lib/shared/components/todo/todo_preview_tile.dart":
        "4 == AppSpacing.xs2, pending migration (v1)",
}


def _is_exempt(rel: str, table: dict[str, str]) -> bool:
    for prefix in table:
        if rel == prefix or rel.startswith(prefix):
            return True
    return False


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

        # --- v2 full-text scans -------------------------------------------
        # These rules must see across line breaks (multi-line SizedBox /
        # EdgeInsets calls), so they run over the joined file text and map
        # each match back to its start line. A `// check-ignore` on ANY line
        # the match spans suppresses it, mirroring check_localizations.py.
        text = "\n".join(lines)

        def span_suppressed(start: int, end: int) -> bool:
            first = text.count("\n", 0, start)
            last = min(text.count("\n", 0, end), len(lines) - 1)
            return any(is_suppressed(lines[j]) for j in range(first, last + 1))

        # (b) raw material Colors.* with an exact AppColors token.
        for match in RAW_COLORS_EXACT_RE.finditer(text):
            if span_suppressed(match.start(), match.end()):
                continue
            if _is_exempt(rel, RAW_COLORS_EXEMPT):
                continue
            name = match.group(1)
            report.add(rel, text.count("\n", 0, match.start()) + 1,
                        f"raw Colors.{name} -- use {RAW_COLORS_EXACT_MAP[name]}",
                        severity="ERROR")

        # (a) SizedBox(height:/width: <numeric literal>).
        for match in SIZEDBOX_NUM_RE.finditer(text):
            if span_suppressed(match.start(), match.end()):
                continue
            if _is_exempt(rel, SIZEDBOX_EXEMPT):
                continue
            report.add(rel, text.count("\n", 0, match.start()) + 1,
                        "magic-number SizedBox height/width -- use an "
                        "AppSpacing.* token",
                        severity="WARN")

        # (c) EdgeInsets.all/only/symmetric/fromLTRB with a numeric argument,
        #     including multi-line calls.
        for match in EDGEINSETS_CALL_RE.finditer(text):
            block = extract_paren_block(text, match.end() - 1)
            if not NUMERIC_ARG_RE.search(block):
                continue
            if span_suppressed(match.start(), match.start() + len(block)):
                continue
            if _is_exempt(rel, EDGEINSETS_EXEMPT):
                continue
            report.add(rel, text.count("\n", 0, match.start()) + 1,
                        "magic-number EdgeInsets -- use an AppSpacing.* token",
                        severity="WARN")

        # (d) Radius.circular(<numeric literal>).
        for match in RADIUS_CIRCULAR_NUM_RE.finditer(text):
            if span_suppressed(match.start(), match.end()):
                continue
            report.add(rel, text.count("\n", 0, match.start()) + 1,
                        "magic-number Radius.circular(...) -- use an "
                        "AppRadius.* token",
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
