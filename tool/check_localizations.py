#!/usr/bin/env python3
"""
check_localizations.py — Hardcoded-string guard for EduZone App.

  3. Positional (unnamed) string-literal arguments passed to:
       - any *Exception(...) / *Failure(...) constructor call, e.g.
         ServerException('Failed to log download attempt'),
         Exception('Maximum concurrent downloads limit reached')
         -- these `.message` values are frequently rendered straight to
         the user by shared error widgets (see error_state.dart, which
         does exactly `Text(message, ...)`), so a hardcoded literal here
         is just as user-facing as one inside Text(...) directly.
       - TaskNotification(...) (background_downloader package) -- the
         title/body shown in the OS-level download notification, e.g.
         TaskNotification('EduZone download', 'Download complete'),
         which is 100% user-facing and currently English-only regardless
         of the device locale.

  4. `message = 'literal'` as a constructor default value, e.g.
       AlreadyDownloadedFailure([super.message = 'Lesson already downloaded']);
     -- the exception's own built-in default message, hit whenever the
     caller doesn't override it.

NOT flagged (these are not hardcoded UI copy):
  Text(l10n.someKey)             -- already using the localization system
  Text(widget.someLabel)         -- pass-through of a caller-supplied value
  Text(lesson.lessonTitle)       -- dynamic data from a model/backend
  Text('${count}')               -- pure interpolation, no literal wording
  Text('•') / Text('-')          -- punctuation/symbols only, nothing to
                                     translate
  title: someVariable            -- not a literal, nothing to flag
  'tenant_id': tenantId ?? '00...'  -- a quoted MAP KEY (not a bare
                                     identifier followed by `:`), and a
                                     fallback UUID, not UI copy -- pattern
                                     #2 only matches a bare identifier
                                     immediately before `:`, so this is
                                     correctly never matched
  String get entityId => '';     -- empty string, no wording to translate

This mirrors check_a11y.py's philosophy: a narrow set of specific, known
signals, not a general-purpose i18n linter that tries to trace every
String value in the codebase (that would flag route names, map keys,
enum-like values, and asset paths as false positives). A literal that IS
intentional (a fixed brand name like 'EduZone', a language switcher's own
native-script label like 'العربية'/'English', a semantic accessibility
label that's deliberately not translated, or a genuinely developer-only
exception message that never reaches a user-facing widget) should be
marked with a trailing `// check-ignore` comment after a conscious review,
exactly like the other guards in this folder -- not silently exempted
here.

Exit code: 0 = OK, 1 = violations found.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import Report, is_suppressed, iter_dart_files  # noqa: E402

# Text(<quote>...<same quote>  -- captures the quote char via a backreference
# so a stray apostrophe/quote of the other kind inside the string doesn't
# truncate the match early.
TEXT_LITERAL_RE = re.compile(r"""\bText\(\s*(['"])((?:(?!\1).)*)\1""")

# Named parameters that, by strong convention across this codebase (and
# Flutter generally), end up rendered as user-facing text -- regardless of
# which widget they're passed to. `\s*` after the colon lets this span a
# newline, matching the common `title:\n  'literal',` multi-line style.
# Requires a bare identifier immediately before `:`, so a quoted map key
# like 'tenant_id': is never matched.
UI_TEXT_PARAM_RE = re.compile(
    r"""\b(hintText|labelText|helperText|errorText|title|subtitle|label|message)"""
    r"""\s*:\s*(['"])((?:(?!\2).)*)\2"""
)

# Constructor calls whose positional string arguments end up shown to the
# user one way or another (exception/failure `.message`, or an OS-level
# download notification's title/body).
CALL_CLASS_RE = re.compile(r"\b(\w*(?:Exception|Failure)|TaskNotification)\(")

# Any quoted literal, used to scan *inside* a CALL_CLASS_RE match's
# parenthesised argument list for every positional string it contains.
QUOTED_STRING_RE = re.compile(r"""(['"])((?:(?!\1).)*)\1""")

# `message = 'literal'` as a constructor default value (super.message = ...,
# this.message = ..., or a plain local default) -- distinct syntax from
# both Text(...) and `name: 'literal'`.
MESSAGE_DEFAULT_RE = re.compile(r"""\bmessage\s*=\s*(['"])((?:(?!\1).)*)\1""")


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

# Strips ${expr} and $identifier interpolations before checking what's left
# for actual wording -- interpolation alone isn't hardcoded UI copy.
INTERPOLATION_RE = re.compile(r"\$\{[^}]*\}|\$[A-Za-z_]\w*")

# Latin or Arabic letters, 2+ in a row, after interpolations are stripped --
# the actual signal that literal *wording* (not just punctuation/whitespace)
# remains in the string.
WORDING_RE = re.compile(r"[A-Za-z\u0600-\u06FF]{2,}")


def has_hardcoded_wording(literal: str) -> bool:
    stripped = INTERPOLATION_RE.sub("", literal)
    return bool(WORDING_RE.search(stripped))


def main() -> None:
    report = Report("Localization guard")

    for fpath, rel, lines in iter_dart_files():
        text = "\n".join(lines)
        candidates: list[tuple[int, int, str]] = []  # (start, end, snippet)

        # Pattern 1: Text('literal')
        for match in TEXT_LITERAL_RE.finditer(text):
            if has_hardcoded_wording(match.group(2)):
                candidates.append((*match.span(), match.group(0)))

        # Pattern 2: title:/subtitle:/label:/hintText:/... 'literal'
        for match in UI_TEXT_PARAM_RE.finditer(text):
            if has_hardcoded_wording(match.group(3)):
                candidates.append((*match.span(), match.group(0)))

        # Pattern 3: positional string args inside *Exception(...),
        # *Failure(...), TaskNotification(...) calls -- scan every quoted
        # literal within the call's own parenthesised block, not just the
        # first, since TaskNotification takes two (title, body).
        for call_match in CALL_CLASS_RE.finditer(text):
            open_idx = call_match.end() - 1
            block = extract_paren_block(text, open_idx)
            for qmatch in QUOTED_STRING_RE.finditer(block):
                if has_hardcoded_wording(qmatch.group(2)):
                    abs_start = open_idx + qmatch.start()
                    abs_end = open_idx + qmatch.end()
                    candidates.append((abs_start, abs_end, qmatch.group(0)))

        # Pattern 4: `message = 'literal'` constructor default values.
        for match in MESSAGE_DEFAULT_RE.finditer(text):
            if has_hardcoded_wording(match.group(2)):
                candidates.append((*match.span(), match.group(0)))

        # Different patterns can catch the SAME underlying string literal
        # via spans that overlap but aren't identical -- e.g.
        # `AlreadyDownloadedFailure([super.message = 'Lesson already
        # downloaded'])` matches both CALL_CLASS_RE (whole block) and
        # MESSAGE_DEFAULT_RE (just `message = '...'`). Sort by position and
        # keep only non-overlapping matches so each literal is reported
        # exactly once, preferring whichever pattern matched first at that
        # position (earlier start, then wider span).
        candidates.sort(key=lambda c: (c[0], -c[1]))
        accepted: list[tuple[int, int, str]] = []
        last_end = -1
        for start, end, snippet in candidates:
            if start < last_end:
                continue
            accepted.append((start, end, snippet))
            last_end = end

        for start, end, snippet in accepted:
            start_line = text.count("\n", 0, start)
            end_line = text.count("\n", 0, end)

            # A `// check-ignore` on ANY line the match spans suppresses it --
            # the identifier/class name and its string argument are
            # frequently on different lines.
            if any(is_suppressed(lines[j])
                   for j in range(start_line, min(end_line + 1, len(lines)))):
                continue

            report.add(
                rel, start_line + 1,
                f"hardcoded string: {snippet!r} "
                f"-- use an AppLocalizations key (l10n.*) instead",
                severity="ERROR",
            )

    report.print_and_exit(
        fix_hint=(
            "Add a key for this string to both lib/core/l10n/arb/app_en.arb "
            "and app_ar.arb, run `flutter gen-l10n`, then reference it as "
            "l10n.yourKey instead of the literal. If the text is genuinely "
            "not user-facing copy (e.g. a fixed brand name, a debug-only "
            "label), mark the line with `// check-ignore` after a conscious "
            "review instead of leaving it as a silent violation."
        ),
    )


if __name__ == "__main__":
    main()