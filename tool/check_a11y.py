#!/usr/bin/env python3
"""
check_a11y.py — Accessibility guard for EduZone App.

Checks for raw IconButton( blocks that:
  1. Have no tooltip: parameter at all, OR
  2. Have a hard-coded tooltip string (not an l10n key)

Files excluded:
  - lib/design_system/components/input/app_icon_button.dart (the component itself)

Exit code: 0 = OK, 1 = found violations.
"""

import re
import sys
from pathlib import Path

# Fix Windows console encoding
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).parent.parent / "lib"
EXCLUDED = {
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
        # Safety: don't scan too far
        if len(block_lines) > 60:
            break

    return "\n".join(block_lines)


violations = []

for fpath in ROOT.rglob("*.dart"):
    rel = fpath.relative_to(ROOT.parent).as_posix()
    if rel in EXCLUDED:
        continue

    text = fpath.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()

    for i, line in enumerate(lines):
        if not ICON_BUTTON_RE.search(line):
            continue

        block = extract_block(lines, i)

        has_l10n_tooltip = bool(L10N_TOOLTIP_RE.search(block))
        has_hardcoded_tooltip = bool(HARDCODED_TOOLTIP_RE.search(block))

        if has_l10n_tooltip:
            continue  # OK — tooltip is localised

        if has_hardcoded_tooltip:
            violations.append(
                f"  {rel}:{i + 1}  -- hard-coded tooltip string (not localised)"
            )
        else:
            violations.append(
                f"  {rel}:{i + 1}  -- IconButton( with no tooltip"
                " (use AppIconButton or add tooltip: l10n.key)"
            )

if violations:
    print("FAIL: Accessibility violations found:\n")
    for v in violations:
        print(v)
    print(
        "\nFix: replace raw IconButton( with AppIconButton(semanticLabel: l10n.key, ...)"
        " or add tooltip: l10n.key to the existing IconButton."
    )
    sys.exit(1)
else:
    print("PASS: Accessibility check passed -- no unlabelled IconButton found.")
    sys.exit(0)
    