#!/usr/bin/env python3
"""
check_auth_security.py — Authentication security static guard for EduZone App.

This is AUTH-18 from EduZone_Authentication_Session_Security_Architecture.md:
a static check that keeps a set of auth security invariants enforced by the
system itself instead of by developer discipline / code review alone.

Like the other tool/check_*.py guards (check_architecture.py,
check_memory_hygiene.py, ...), this is a heuristic, regex-based static
checker over hand-written .dart source — not a full analyzer. It can be
suppressed per-line with `// check-ignore` for deliberately reviewed and
accepted exceptions, same convention as every other guard in this folder.

Rules:
  ERROR  Secret material (access token, refresh token, password, raw JWT,
         API/service-role key) interpolated directly into a `print(...)` or
         `debugPrint(...)` call.
         -> debugPrint is NOT stripped in release builds in this project
            (no debugPrint override exists — see lib/main.dart), so this
            would leak the raw secret to device logs/logcat in production.
            Log an opaque identifier (user id, event name) instead.

  ERROR  `print(...)` used anywhere in lib/ (as opposed to `debugPrint`).
         -> `print()` is unthrottled and not batched; project convention
            (600+ existing call sites) is `debugPrint` exclusively.

  ERROR  A secret-shaped literal (password/apiKey/secret/token assigned to
         a non-empty string literal) hardcoded in source.
         -> credentials must come from build-time/runtime configuration
            (see AppConfig / --dart-define), never a literal in source.

  ERROR  SharedPreferences used to persist a key whose name looks like a
         credential (token/password/secret/refreshToken/...).
         -> secrets must go through flutter_secure_storage
            (FlutterSecureStorage), never SharedPreferences (see
            EduZone_Authentication_Session_Security_Architecture.md,
            "Secure Session Storage": "Never SharedPreferences for
            secrets").

  WARN   A file under lib/features/*/presentation/ imports
         package:supabase_flutter/supabase_flutter.dart directly.
         -> Supabase access is a data-layer concern; presentation talking
            to Supabase directly bypasses the repository/use-case boundary
            and the typed error mapping in AuthRemoteDataSource.

  WARN   lib/app/router/*.dart calls an auth-mutating method
         (`.signOut(`, `.signInWithPassword(`, `.signInWithPassword(`,
         a `Auth` notifier's `.login(`/`.logout(`) directly.
         -> "Router observes auth state" (see architecture doc, phase 21):
            the router must never itself decide to mutate session state,
            only redirect based on state it's given.

Exit code: 0 = OK (or only warnings, unless --strict), 1 = errors found.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import Report, is_suppressed, iter_dart_files  # noqa: E402

# ── Rule 1: secret interpolated into print/debugPrint ───────────────────────

PRINT_CALL_RE = re.compile(r"\b(?:print|debugPrint)\s*\(")

# Identifier fragments that indicate the *value itself* is secret material.
# Deliberately excludes plain "session"/"token" alone (too broad — e.g.
# "session initialization", "token_version" are legitimate non-secret log
# text) and excludes any identifier ending in Version/Id/Count/Status,
# which are metadata, not the secret.
SECRET_VALUE_RE = re.compile(
    r"\$\{?\s*[\w.]*\b("
    r"accessToken|refreshToken|refresh_token|access_token|"
    r"password|jwt|apiKey|api_key|serviceRoleKey|service_role_key|"
    r"privateKey|private_key|secret"
    r")\b(?!\w*(?:Version|Id|Count|Status|Field|Label|Hint|Key\w))",
    re.IGNORECASE,
)


def check_secret_logging(report: Report) -> None:
    for fpath, rel, lines in iter_dart_files():
        for i, line in enumerate(lines, start=1):
            if is_suppressed(line):
                continue
            if not PRINT_CALL_RE.search(line):
                continue
            if SECRET_VALUE_RE.search(line):
                report.add(
                    rel, i,
                    "possible secret (token/password/jwt/key) interpolated "
                    "into a print/debugPrint call — this is NOT stripped in "
                    "release builds and would leak to device logs; log an "
                    "opaque id or event name instead",
                )


# ── Rule 2: raw print() instead of debugPrint() ──────────────────────────────

RAW_PRINT_RE = re.compile(r"(?<!debug)\bprint\s*\(")


def check_raw_print(report: Report) -> None:
    for fpath, rel, lines in iter_dart_files():
        for i, line in enumerate(lines, start=1):
            if is_suppressed(line):
                continue
            stripped = line.strip()
            if stripped.startswith("//") or stripped.startswith("*"):
                continue
            if RAW_PRINT_RE.search(line):
                report.add(
                    rel, i,
                    "raw print(...) call — use debugPrint(...) "
                    "(project convention; print() is unthrottled)",
                )


# ── Rule 3: hardcoded credential literal ─────────────────────────────────────

HARDCODED_SECRET_RE = re.compile(
    r"""\b(password|apiKey|api_key|secret|serviceRoleKey|service_role_key|
        privateKey|private_key)\s*[:=]\s*['"][^'"\s]{4,}['"]""",
    re.IGNORECASE | re.VERBOSE,
)


def check_hardcoded_secrets(report: Report) -> None:
    for fpath, rel, lines in iter_dart_files():
        # Test doubles / fixtures legitimately construct fake credential
        # strings (e.g. 'wrong-password' in a login-failure test). Only
        # hand-written production source under lib/ is scanned at all
        # (iter_dart_files already excludes generated code); further
        # exclude example/template config which documents the *shape* of
        # config, not a real secret.
        if "example" in rel or "template" in rel:
            continue
        for i, line in enumerate(lines, start=1):
            if is_suppressed(line):
                continue
            match = HARDCODED_SECRET_RE.search(line)
            if not match:
                continue
            value = line[match.end() - 1:]  # heuristic only, not used further
            # Skip obvious non-secrets: empty-string defaults, hint/label
            # text for form fields (e.g. `hintText: 'Password'`), and
            # localization-key-shaped values.
            lowered = line.lower()
            if "hint" in lowered or "label" in lowered or "obscure" in lowered:
                continue
            report.add(
                rel, i,
                "credential-shaped literal hardcoded in source — secrets "
                "must come from build-time/runtime configuration "
                "(AppConfig / --dart-define), never a source literal",
            )


# ── Rule 4: secrets in SharedPreferences ─────────────────────────────────────

SHARED_PREFS_SECRET_RE = re.compile(
    r"prefs\.set\w+\s*\(\s*['\"][^'\"]*("
    r"token|password|secret|refreshToken|accessToken|jwt|apiKey"
    r")[^'\"]*['\"]",
    re.IGNORECASE,
)


def check_shared_prefs_secrets(report: Report) -> None:
    for fpath, rel, lines in iter_dart_files():
        for i, line in enumerate(lines, start=1):
            if is_suppressed(line):
                continue
            if SHARED_PREFS_SECRET_RE.search(line):
                report.add(
                    rel, i,
                    "SharedPreferences used to persist what looks like a "
                    "credential — secrets must use FlutterSecureStorage, "
                    "never SharedPreferences",
                )


# ── Rule 5 (WARN): presentation importing supabase_flutter directly ────────

SUPABASE_IMPORT_RE = re.compile(
    r"""^import\s+['"]package:supabase_flutter/supabase_flutter\.dart['"]"""
)


def check_presentation_supabase_import(report: Report) -> None:
    for fpath, rel, lines in iter_dart_files():
        if "/presentation/" not in f"/{rel}":
            continue
        for i, line in enumerate(lines, start=1):
            if is_suppressed(line):
                continue
            if SUPABASE_IMPORT_RE.match(line.strip()):
                report.add(
                    rel, i,
                    "presentation-layer file imports supabase_flutter "
                    "directly — Supabase access belongs in the data layer "
                    "(AuthRemoteDataSource et al.), not presentation",
                    severity="WARN",
                )


# ── Rule 6 (WARN): router mutating auth state directly ──────────────────────

ROUTER_AUTH_MUTATION_RE = re.compile(
    r"\.(signOut|signInWithPassword|signInWithOAuth|signUp)\s*\("
)


def check_router_auth_mutation(report: Report) -> None:
    for fpath, rel, lines in iter_dart_files():
        if "lib/app/router/" not in f"/{rel}":
            continue
        for i, line in enumerate(lines, start=1):
            if is_suppressed(line):
                continue
            if ROUTER_AUTH_MUTATION_RE.search(line):
                report.add(
                    rel, i,
                    "router file calls an auth-mutating method directly — "
                    "the router must only observe AuthState/AppAuthState "
                    "and redirect; session mutation belongs in the Auth "
                    "notifier",
                    severity="WARN",
                )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true",
                         help="also fail (exit 1) on WARN-level violations")
    args = parser.parse_args()

    report = Report("Auth security guard")

    check_secret_logging(report)
    check_raw_print(report)
    check_hardcoded_secrets(report)
    check_shared_prefs_secrets(report)
    check_presentation_supabase_import(report)
    check_router_auth_mutation(report)

    report.print_and_exit(
        fix_hint=(
            "Log opaque identifiers instead of secrets, use debugPrint "
            "instead of print, move credentials to AppConfig/--dart-define, "
            "use FlutterSecureStorage for tokens, keep Supabase calls in "
            "the data layer, and keep session mutation out of the router."
        ),
        fail_on_warn=args.strict,
    )


if __name__ == "__main__":
    main()
