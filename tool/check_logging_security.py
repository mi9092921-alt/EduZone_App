#!/usr/bin/env python3
"""
check_logging_security.py — Logging/observability static guard for EduZone App.

This is P15 from Production EduZone App — Agent Instructions.md, Section 15
("Logging and Observability"): a static check that keeps three concrete,
previously-real regressions in lib/core/logging/ enforced by the system
itself rather than by code review alone. Each rule below corresponds
one-to-one to a bug that genuinely existed in this codebase and was fixed
in the same change that introduced this guard — this is not a hypothetical
checklist.

Like the other tool/check_*.py guards (check_auth_security.py,
check_memory_hygiene.py, ...), this is a heuristic, regex-based static
checker over hand-written .dart source — not a full analyzer. It can be
suppressed per-line with `// check-ignore` for deliberately reviewed and
accepted exceptions, same convention as every other guard in this folder.

Rules:

  ERROR  Direct PostgREST access to `activity_log_queue`
         (`.from('activity_log_queue')` / `.from("activity_log_queue")`).
         -> That table has `REVOKE ALL ... FROM anon, authenticated`
            (supabase/schema/10_permissions.sql) plus a deny-all RLS policy
            (supabase/schema/09_rls.sql, "CRIT-05: Deny all PostgREST
            access to internal tables"). A direct insert/select against it
            always fails for every client role — this used to be exactly
            how LogRemoteDataSource tried to sync entries, silently
            breaking the entire client observability pipeline. The only
            legitimate client write path is the
            `public.log_activity_async` RPC.

  ERROR  `LogEntry.fromEvent(event)` called with no `encryptedDetails:`
         argument anywhere in audit_handler.dart.
         -> AuditHandler only ever receives auth-category or
            high/critical-risk events. The encryption-failure fallback
            used to call exactly this — `LogEntry.fromEvent(event)` with
            no encryptedDetails override — which ships the event's *raw
            plaintext* sensitive `details` to Supabase, defeating the
            reason this handler encrypts in the first place. The
            fail-closed fix always passes an explicit `encryptedDetails:`
            (either the real ciphertext wrapper or the redacted
            placeholder) — a bare call is the fail-open bug returning.

  ERROR  `Sentry.captureException(` whose first argument is
         `event.errorMessage` (or any `*.errorMessage`).
         -> `errorMessage` on AppEvent/ErrorOccurredEvent is always a
            short, already-sanitized `String` — never a real `Throwable`
            — and passing it as the `throwable` argument to
            captureException() (rather than captureMessage()) produces
            malformed grouping/fingerprinting in Sentry and duplicates
            the real exception GlobalErrorHandler.logError() already
            reports. This exact call existed in crash_handler.dart.

  ERROR  An empty (`catch (_) {}`) or fully-silent (`catch (e) {}`) catch
         block anywhere under lib/core/logging/.
         -> Every file in this directory *is* the observability pipeline;
            silently discarding an exception here (as
            EventDispatcher._dispatch used to) makes bugs inside the
            logging system itself permanently invisible, which is itself
            a Section 15 violation ("Audit: ... unexpected exceptions").
            Handler-level isolation (one handler's failure must not stop
            others from running) is fine and expected in this directory —
            but the catch body must at minimum surface what happened
            (e.g. via debugPrint), not be empty.

Exit code: 0 = OK (or only warnings, unless --strict), 1 = errors found.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import LIB_ROOT, Report, is_suppressed, iter_dart_files  # noqa: E402

# ── Rule 1: direct PostgREST access to activity_log_queue ───────────────────

ACTIVITY_LOG_QUEUE_INSERT_RE = re.compile(
    r"""\.from\s*\(\s*['"]activity_log_queue['"]\s*\)"""
)


def check_no_direct_activity_log_queue_access(report: Report) -> None:
    for fpath, rel, lines in iter_dart_files():
        for i, line in enumerate(lines, start=1):
            if is_suppressed(line):
                continue
            stripped = line.strip()
            if stripped.startswith("//") or stripped.startswith("*"):
                continue
            if ACTIVITY_LOG_QUEUE_INSERT_RE.search(line):
                report.add(
                    rel, i,
                    "direct .from('activity_log_queue') PostgREST access — "
                    "this table denies all client access at the database "
                    "layer (10_permissions.sql / 09_rls.sql); use the "
                    "public.log_activity_async RPC instead",
                )


# ── Rule 2: AuditHandler fail-open regression ────────────────────────────────

# Matches `LogEntry.fromEvent(event)` (optionally with trailing whitespace)
# but NOT `LogEntry.fromEvent(event, ...)` — i.e. no further named args at
# all, which is exactly the old fail-open fallback's shape.
BARE_LOG_ENTRY_FROM_EVENT_RE = re.compile(
    r"LogEntry\.fromEvent\s*\(\s*event\s*\)"
)


def check_audit_handler_fails_closed(report: Report) -> None:
    target = LIB_ROOT / "core" / "logging" / "handlers" / "audit_handler.dart"
    if not target.exists():
        return
    lines = target.read_text(encoding="utf-8", errors="replace").splitlines()
    rel = target.relative_to(LIB_ROOT.parent).as_posix()
    for i, line in enumerate(lines, start=1):
        if is_suppressed(line):
            continue
        stripped = line.strip()
        if stripped.startswith("//") or stripped.startswith("*"):
            continue
        if BARE_LOG_ENTRY_FROM_EVENT_RE.search(line):
            report.add(
                rel, i,
                "LogEntry.fromEvent(event) with no encryptedDetails: "
                "argument in audit_handler.dart — this ships the event's "
                "raw plaintext `details` to Supabase; always pass an "
                "explicit encryptedDetails: (ciphertext wrapper or "
                "redacted placeholder) instead",
            )


# ── Rule 3: malformed Sentry.captureException(event.errorMessage, ...) ──────

CAPTURE_EXCEPTION_ERROR_MESSAGE_RE = re.compile(
    r"Sentry\.captureException\s*\(\s*\w*\.?errorMessage\b"
)


def check_no_error_message_as_throwable(report: Report) -> None:
    for fpath, rel, lines in iter_dart_files():
        for i, line in enumerate(lines, start=1):
            if is_suppressed(line):
                continue
            stripped = line.strip()
            if stripped.startswith("//") or stripped.startswith("*"):
                continue
            if CAPTURE_EXCEPTION_ERROR_MESSAGE_RE.search(line):
                report.add(
                    rel, i,
                    "Sentry.captureException(event.errorMessage, ...) — "
                    "errorMessage is a sanitized String, not a Throwable; "
                    "use Sentry.captureMessage(event.errorMessage, "
                    "level: SentryLevel.error) instead",
                )


# ── Rule 4: silent catch inside lib/core/logging/ ────────────────────────────

# A catch clause whose entire body (up to the closing brace) is empty or
# whitespace-only. Scoped to lib/core/logging/ only — deliberately not a
# codebase-wide rule, since `catch (_) {}` is an accepted pattern elsewhere
# (e.g. best-effort cleanup in video player wrappers) that is out of scope
# for a logging/observability guard.
CATCH_OPEN_RE = re.compile(r"catch\s*\([\w\s]*\)\s*\{")


def check_no_silent_catch_in_logging(report: Report) -> None:
    logging_dir = LIB_ROOT / "core" / "logging"
    for fpath, rel, lines in iter_dart_files(root=logging_dir):
        for i, line in enumerate(lines):
            if is_suppressed(line):
                continue
            match = CATCH_OPEN_RE.search(line)
            if not match:
                continue
            # Everything after the opening `{` on this line, plus
            # subsequent lines up to the matching close, checked heuristically:
            # look at the very next non-blank content after the brace.
            after_brace = line[match.end():].strip()
            if after_brace.startswith("}"):
                # catch (...) { }  on a single line
                report.add(
                    rel, i + 1,
                    "empty catch block in lib/core/logging/ — silently "
                    "discarding an exception here makes bugs in the "
                    "observability pipeline itself invisible; at minimum "
                    "debugPrint the exception type",
                )
                continue
            if after_brace == "":
                # Body starts on the next line(s) — check the immediate
                # next non-blank line; if it's just the closing brace,
                # the body is empty.
                j = i + 1
                while j < len(lines) and lines[j].strip() == "":
                    j += 1
                if j < len(lines) and lines[j].strip() == "}":
                    report.add(
                        rel, i + 1,
                        "empty catch block in lib/core/logging/ — silently "
                        "discarding an exception here makes bugs in the "
                        "observability pipeline itself invisible; at "
                        "minimum debugPrint the exception type",
                    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true",
                         help="also fail (exit 1) on WARN-level violations")
    args = parser.parse_args()

    report = Report("Logging/observability security guard")

    check_no_direct_activity_log_queue_access(report)
    check_audit_handler_fails_closed(report)
    check_no_error_message_as_throwable(report)
    check_no_silent_catch_in_logging(report)

    report.print_and_exit(
        fix_hint=(
            "Route activity_log_queue writes through the "
            "public.log_activity_async RPC, always pass an explicit "
            "encryptedDetails: to LogEntry.fromEvent() in "
            "audit_handler.dart, use Sentry.captureMessage() for plain "
            "String diagnostics, and never leave a catch block in "
            "lib/core/logging/ silently empty."
        ),
        fail_on_warn=args.strict,
    )


if __name__ == "__main__":
    main()
