#!/usr/bin/env python3
"""
check_dependency_floor.py — Known-vulnerable dependency floor guard.

AUTH-00 audit finding (Section 8, "Authentication and Authorization" review
against EduZone_Authentication_Session_Security_Architecture.md, Phase 7 —
"Refresh Race Protection"):

  pubspec.yaml pins `supabase_flutter: ^2.6.0` (a permissive caret
  constraint), but pubspec.lock had resolved it to 2.12.2, which transitively
  locks `gotrue` to 2.19.0. That gotrue version predates a real, upstream-
  confirmed concurrency bug in `GoTrueClient._callRefreshToken()`:

    "fix(gotrue): prevent stale token refresh from overwriting concurrent
    session changes" — supabase/supabase-flutter PR #1351, merged in gotrue
    2.22.0. Upstream's own before/after test matrix
    (packages/gotrue/test/src/token_refresh_race_test.dart) shows 7 of 8
    race-condition tests FAIL on the pre-fix code, including:
      - "signOut during in-flight refresh does not restore session"
        -> a completed logout could be silently undone by a stale refresh
           response landing afterwards.
      - "signIn during in-flight refresh preserves new session"
        -> a fresh login's session could be overwritten by an older
           refresh response still in flight from the previous session.
      - "dispose completes active refresh with error"
        -> a pending refresh could hang indefinitely (30s timeout in
           upstream's own test) instead of resolving on teardown.

  This is exactly the "Refresh Race Protection" gap
  (EduZone_Authentication_Session_Security_Architecture.md, Phase 7): the
  project's own Auth notifier has a solid generation-counter guard for ITS
  OWN state (see `_authOperationGeneration` in
  lib/features/auth/application/providers/auth_provider.dart), but that
  guard cannot protect against corruption happening one layer below, inside
  the Supabase SDK's own `_currentSession` object, before the app ever sees
  an event.

  The existing `pubspec.yaml` constraint (`^2.6.0`) already permits
  resolving to a fixed version — this is a stale-lockfile problem, not a
  pubspec.yaml problem. No pubspec.yaml edit is required; re-resolving
  dependencies is the fix:

      flutter pub upgrade supabase_flutter

  This guard exists so that gap can never silently regress again (e.g. a
  future `flutter pub downgrade`, an unrelated lockfile regeneration on an
  offline machine, or a merge conflict resolved the wrong way): CI fails
  loudly instead of quietly shipping the vulnerable range again.

Like the other tool/check_*.py guards, this is a small, explicit, hand-
maintained table rather than a general CVE database integration — matching
this project's "smallest safe change" convention. Add an entry to
KNOWN_VULNERABLE_FLOORS for any future dependency where a specific
upstream-confirmed fix version needs to be enforced as a floor.

Exit code: 0 = OK, 1 = a locked package resolves below its known-safe floor.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

REPO_ROOT = Path(__file__).parent.parent
PUBSPEC_LOCK = REPO_ROOT / "pubspec.lock"

# package_name -> (min_safe_version, reason, upstream_reference)
#
# min_safe_version is the first version KNOWN to contain the fix — not
# necessarily the latest version. This guard only asserts a floor, it does
# not enforce staying current in general (that is Section 27's dependency
# audit, a separate, broader, human-judgment process).
KNOWN_VULNERABLE_FLOORS: dict[str, tuple[str, str, str]] = {
    "gotrue": (
        "2.22.0",
        "Concurrent session/refresh race: a stale in-flight token refresh "
        "can silently overwrite a newer signIn/signOut/setSession, or hang "
        "on dispose. Fixed via _SessionState version-guard + token-aware "
        "_pendingRefreshes map.",
        "supabase/supabase-flutter PR #1351 "
        "(commit 368609abfd59ca04f9d3df80ebcaeedae89a4bef)",
    ),
}


def _parse_version(v: str) -> tuple[int, ...]:
    """Best-effort semver parse. '2.19.0' -> (2, 19, 0). Pre-release
    suffixes (e.g. '-beta.1') are stripped for comparison purposes since
    none of our current floor entries need that precision."""
    core = re.split(r"[+-]", v, maxsplit=1)[0]
    parts = []
    for chunk in core.split("."):
        m = re.match(r"\d+", chunk)
        parts.append(int(m.group()) if m else 0)
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts[:3])


def _iter_locked_packages(text: str):
    """Yield (package_name, version, line_no) for every top-level package
    block in pubspec.lock. Matches the stable, pub-generated 2-space /
    4-space indentation (see packages:\\n  name:\\n    ...\\n    version: "x").
    """
    lines = text.splitlines()
    current_pkg: str | None = None
    current_pkg_line = 0
    pkg_header_re = re.compile(r"^  ([A-Za-z0-9_]+):\s*$")
    version_re = re.compile(r'^\s{4}version:\s*"?([^"\s]+)"?\s*$')

    for i, line in enumerate(lines, start=1):
        header = pkg_header_re.match(line)
        if header:
            current_pkg = header.group(1)
            current_pkg_line = i
            continue
        if current_pkg is not None:
            m = version_re.match(line)
            if m:
                yield current_pkg, m.group(1), current_pkg_line
                current_pkg = None  # one version line per package block


def check_dependency_floors(report) -> None:
    if not PUBSPEC_LOCK.exists():
        report.add(
            "pubspec.lock",
            1,
            "pubspec.lock not found — run `flutter pub get` before this "
            "check (dependency floors cannot be verified without a "
            "resolved lockfile).",
        )
        return

    text = PUBSPEC_LOCK.read_text(encoding="utf-8", errors="replace")
    locked = {name: (version, line) for name, version, line in _iter_locked_packages(text)}

    for pkg, (min_safe, reason, upstream_ref) in KNOWN_VULNERABLE_FLOORS.items():
        if pkg not in locked:
            continue  # not a dependency of this project (yet) — nothing to check
        resolved, line_no = locked[pkg]
        if _parse_version(resolved) < _parse_version(min_safe):
            report.add(
                "pubspec.lock",
                line_no,
                f"{pkg} is locked at {resolved}, below the known-safe floor "
                f"{min_safe}. {reason} ({upstream_ref})",
            )


def main() -> None:
    # Imported lazily so this file has zero import-time dependency on the
    # rest of tool/ beyond _common, matching the other check_*.py scripts.
    sys.path.insert(0, str(Path(__file__).parent))
    from _common import Report  # noqa: E402

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--strict",
        action="store_true",
        help="No effect currently (all findings here are ERROR, not WARN) "
        "— present for CLI consistency with the other check_*.py guards.",
    )
    args = parser.parse_args()
    _ = args.strict

    report = Report("Dependency floor guard (known-vulnerable versions)")
    check_dependency_floors(report)

    report.print_and_exit(
        fix_hint=(
            "Re-resolve dependencies so the affected package(s) move past "
            "their known-safe floor, e.g.:\n"
            "      flutter pub upgrade <package>\n"
            "  The existing pubspec.yaml constraint typically already "
            "permits this — no pubspec.yaml edit should be needed unless "
            "`flutter pub outdated` shows otherwise. See Section 8 review "
            "notes and EduZone_Authentication_Session_Security_Architecture.md "
            "Phase 7 (\"Refresh Race Protection\") for the auth-specific case."
        ),
    )


if __name__ == "__main__":
    main()
