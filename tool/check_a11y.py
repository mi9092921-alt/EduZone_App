#!/usr/bin/env python3
"""
check_a11y.py — Accessibility guard for EduZone App.

Two checks:

1. IconButton( tooltip check (unchanged behavior from the original version
   of this script): a raw IconButton( with no tooltip: at all, or a
   hard-coded (non-localised) tooltip string, is flagged. AppIconButton
   (lib/design_system/components/input/app_icon_button.dart) is exempt --
   it has a *required* `semanticLabel` constructor parameter, so the Dart
   compiler itself already guarantees every call site provides one; no
   static check can add anything a required parameter doesn't already give
   for free.

2. Icon-only GestureDetector(/InkWell( tap-target check (new): a
   GestureDetector( or InkWell( block whose subtree contains an
   Icon(/Icons.*/AppIcons.* but no Text(/Text.rich(, and that has no
   Semantics(...) either wrapping it or inside it, is flagged. This is the
   pattern IconButton( tooltip-checking alone cannot see: a developer who
   reaches for a raw GestureDetector around a bare icon (e.g. a small
   "edit" pencil/camera badge overlaid on an avatar) produces a tap target
   a screen reader announces nothing about, and neither of Flutter's own
   tooling nor `flutter analyze` catches this -- it's a semantic gap, not
   a type error.

   This check is structural, not line-based: it builds a full
   open-paren -> close-paren index for the whole file (a simple bracket
   matcher), so it can correctly tell whether a GestureDetector(/InkWell(
   sits *inside* an ancestor Semantics(...) even when that ancestor is
   dozens of lines away with several intervening widgets (verified against
   lib/features/courses/presentation/widgets/bookmark_button.dart, where
   the Semantics ancestor is 26 lines above the InkWell it covers -- a
   naive "look N lines back" heuristic would have produced a false
   positive there).

   A GestureDetector(/InkWell( that wraps a whole card/row/tile alongside
   visible Text( is NOT flagged -- the text itself is what a screen reader
   announces, which is the normal, fine case. Only the icon-only case is
   ambiguous enough to require an explicit Semantics label.

Files excluded from check 1:
  - lib/design_system/components/input/app_icon_button.dart (the component itself)

Exit code: 0 = OK, 1 = found violations.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import Report, is_suppressed, iter_dart_files  # noqa: E402

EXCLUDED_ICON_BUTTON_CHECK = {
    "lib/design_system/components/input/app_icon_button.dart",
}

ICON_BUTTON_RE = re.compile(r'\bIconButton\s*\(')
L10N_TOOLTIP_RE = re.compile(
    r'tooltip\s*:\s*'
    r'(?:'
    r'AppLocalizations\.of\('   # AppLocalizations.of(context)!.key
    r'|l10n\.'                  # l10n.key
    r'|widget\.'                # widget.someLabel
    r'|_\w+'                    # _localVariable
    r'|[a-z]\w+\s*\?'          # ternary starting with variable e.g. isPlaying ?
    r'|[a-z]\w+\('             # function call
    r'|[a-z]\w*\s*[,)]'        # bare identifier pass-through, e.g. `tooltip: tooltip,`
    r')'
)
HARDCODED_TOOLTIP_RE = re.compile(r"tooltip\s*:\s*['\"]")

GESTURE_OR_INKWELL_RE = re.compile(r'\b(GestureDetector|InkWell)\s*\(')
SEMANTICS_RE = re.compile(r'\bSemantics\s*\(')
ICON_HINT_RE = re.compile(r'\bIcon\s*\(|\bIcons\.\w|\bAppIcons\.\w')
TEXT_HINT_RE = re.compile(r'\bText\s*\(|\bText\.rich\s*\(')


def extract_block(lines: list[str], start_line: int) -> str:
    """
    Extract the full IconButton(...) block by tracking parenthesis depth.
    Returns the content between the opening ( and matching ).
    """
    depth = 0
    block_lines = []
    found_open = False

    for line in lines[start_line:]:
        for ch in line:
            if ch == '(':
                depth += 1
                found_open = True
            elif ch == ')':
                depth -= 1
        block_lines.append(line)
        if found_open and depth == 0:
            break
        if len(block_lines) > 60:
            break

    return "\n".join(block_lines)


def match_parens(text: str) -> dict[int, int]:
    """Full open-index -> close-index map for every '(' / ')' pair in text."""
    stack: list[int] = []
    pairs: dict[int, int] = {}
    for i, ch in enumerate(text):
        if ch == '(':
            stack.append(i)
        elif ch == ')' and stack:
            pairs[stack.pop()] = i
    return pairs


def check_icon_button(report: Report) -> None:
    for fpath, rel, lines in iter_dart_files():
        if rel in EXCLUDED_ICON_BUTTON_CHECK:
            continue

        for i, line in enumerate(lines):
            if not ICON_BUTTON_RE.search(line) or is_suppressed(line):
                continue

            block = extract_block(lines, i)
            has_l10n_tooltip = bool(L10N_TOOLTIP_RE.search(block))
            has_hardcoded_tooltip = bool(HARDCODED_TOOLTIP_RE.search(block))

            if has_l10n_tooltip:
                continue

            if has_hardcoded_tooltip:
                report.add(rel, i + 1, "hard-coded tooltip string (not localised)")
            else:
                report.add(
                    rel, i + 1,
                    "IconButton( with no tooltip -- use AppIconButton or add "
                    "tooltip: l10n.key",
                )


def check_icon_only_tap_targets(report: Report) -> None:
    for fpath, rel, lines in iter_dart_files():
        text = "\n".join(lines)
        if not GESTURE_OR_INKWELL_RE.search(text):
            continue

        pairs = match_parens(text)
        open_to_close = pairs
        close_to_open = {v: k for k, v in pairs.items()}

        # Every Semantics( open-paren index, for ancestor lookups.
        semantics_opens = [m.end() - 1 for m in SEMANTICS_RE.finditer(text)]

        for m in GESTURE_OR_INKWELL_RE.finditer(text):
            open_idx = m.end() - 1  # index of this construct's own '('
            if open_idx not in open_to_close:
                continue  # unbalanced/truncated -- skip rather than guess
            close_idx = open_to_close[open_idx]

            line_no = text.count("\n", 0, m.start()) + 1
            line_text = lines[line_no - 1] if line_no - 1 < len(lines) else ""
            if is_suppressed(line_text):
                continue

            block = text[open_idx:close_idx]
            has_icon = bool(ICON_HINT_RE.search(block))
            has_text = bool(TEXT_HINT_RE.search(block))
            has_semantics_inside = bool(SEMANTICS_RE.search(block))
            has_semantics_ancestor = any(
                s_open < open_idx < open_to_close.get(s_open, -1)
                for s_open in semantics_opens
            )

            if has_icon and not has_text and not has_semantics_inside and not has_semantics_ancestor:
                kind = m.group(1)
                report.add(
                    rel, line_no,
                    f"{kind}( wraps an icon-only tap target with no Semantics "
                    "label anywhere in its subtree or ancestry -- a screen "
                    "reader announces nothing for this button. Wrap in "
                    "Semantics(button: true, label: l10n.key, child: ...) or "
                    "use AppIconButton instead.",
                )


def main() -> None:
    report = Report("Accessibility guard")
    check_icon_button(report)
    check_icon_only_tap_targets(report)
    report.print_and_exit(
        fix_hint=(
            "IconButton(: replace with AppIconButton(semanticLabel: l10n.key, "
            "...) or add tooltip: l10n.key.\n"
            "GestureDetector(/InkWell( around a bare icon: wrap in "
            "Semantics(button: true, label: l10n.key, child: ...)."
        ),
    )


if __name__ == "__main__":
    main()
