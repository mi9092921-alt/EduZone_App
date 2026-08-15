#!/usr/bin/env python3
"""
check_config_security.py — Secrets & configuration static guard for
EduZone App (Production EduZone App — Agent Instructions.md, Section 10).

Like the other tool/check_*.py guards, this is a heuristic static checker,
not a full secret scanner (that's `gitleaks`, already wired as the
`secret_scan` CI job) and not a substitute for reading Section 10 by hand.
It exists to keep a small set of *configuration integrity* invariants
enforced by the system itself instead of by developer discipline alone —
the kind of drift that compiles fine, that `flutter analyze` never sees,
and that gitleaks (which looks for secret-shaped strings, not missing
`.gitignore` entries or dangling file references) does not catch either.

Rules:

  ERROR  A signing/service-account artifact pattern that this project's own
         CI/deploy workflows *write to disk* (`android/play-store-key.json`,
         `*.p8`, `*.p12`, `*.mobileprovision`, plus the already-established
         `.env*` / `*.keystore` / `*.jks` / `key.properties` /
         `google-services.json` / `GoogleService-Info.plist`) has no
         matching entry in any tracked `.gitignore` in the repo.
         -> a file `deploy.yml` writes locally during a run (or that an
            engineer generates by hand while testing a fastlane lane) must
            never be one `git add -A` away from being committed.

  ERROR  A tracked file (per `git ls-files`) matches `.env` naming
         convention but is not `.env.example` / `.env.security.example`.
         -> Section 10: ".env.example ... [is a] documentation/
            configuration template, not secret storage." A real `.env*`
            file must never be committed, regardless of gitignore state.

  ERROR  `String.fromEnvironment('SOME_KEY_OR_SECRET_OR_TOKEN_NAME', ...,
         defaultValue: '<non-empty literal>')` in lib/ — a non-empty
         fallback for a secret-shaped variable name defeats the point of
         reading it from build-time config in the first place, and means
         a build that forgets --dart-define-from-file silently ships a
         hardcoded value instead of failing closed (contrast
         SECURITY_ANDROID_SIGNING_HASH / SECURITY_IOS_TEAM_ID in
         freerasp_config.dart, which correctly have no default and fail
         fast in release mode).

  ERROR  A deploy/setup script under `supabase/` references a `.sql` file
         path that does not exist anywhere in the repository.
         -> exactly the class of bug this guard was added for: a script
            that looks correct, runs on a machine with the right CWD, and
            fails (or silently no-ops) for anyone else, or documents a
            deploy story that no longer matches `supabase/schema/`.

  WARN   A tracked non-template file contains a JWT-shaped literal
         (`eyJ...eyJ...` two dot-separated base64url segments). Cheap
         local pre-check; the authoritative scan is the `secret_scan`
         (gitleaks) CI job, which also covers full git history.

Exit code: 0 = OK (or only warnings, unless --strict), 1 = errors found.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import Report, iter_dart_files  # noqa: E402

REPO_ROOT = Path(__file__).parent.parent

# ── Rule 1: gitignore coverage for signing / service-account artifacts ──────

# Patterns already relied upon elsewhere (SECURITY.md, .gitignore itself) are
# included too, so this guard also catches a future `.gitignore` edit that
# accidentally drops one of them, not just the ones it's newly adding.
REQUIRED_IGNORE_PATTERNS = [
    ".env*",
    "*.keystore",
    "*.jks",
    "key.properties",
    "google-services.json",
    "GoogleService-Info.plist",
    # Written to disk by .github/workflows/deploy.yml's deploy_android job
    # from the PLAY_STORE_JSON_KEY secret (a Play Console service-account
    # key — as sensitive as a service-role credential).
    "play-store-key.json",
    # Not currently written by any workflow (iOS deploy is fail-closed —
    # see deploy.yml), but these are exactly the artifact types a fastlane
    # `match`/App Store Connect API key setup drops locally, and Section 10
    # is explicit that private certificates/signing credentials must never
    # be committed even "by accident" once someone starts iOS release work.
    "*.p8",
    "*.p12",
    "*.mobileprovision",
]


def check_gitignore_coverage(report: Report) -> None:
    gitignore_files = sorted(REPO_ROOT.rglob(".gitignore"))
    if not gitignore_files:
        report.add(".gitignore", 0, "No .gitignore file found anywhere in the repository.")
        return

    combined = "\n".join(
        f.read_text(encoding="utf-8", errors="replace") for f in gitignore_files
    )

    for pattern in REQUIRED_IGNORE_PATTERNS:
        if pattern not in combined:
            report.add(
                ".gitignore",
                0,
                f"No .gitignore (root/android/ios) covers `{pattern}` — a "
                f"file matching this pattern could be committed by accident.",
            )


# ── Rule 2: no real .env* file tracked in git ───────────────────────────────

ALLOWED_ENV_FILENAMES = {".env.example", ".env.security.example"}


def _git_ls_files() -> list[str] | None:
    try:
        proc = subprocess.run(
            ["git", "ls-files"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError, OSError):
        return None
    return [line for line in proc.stdout.splitlines() if line.strip()]


def check_no_tracked_env_files(report: Report, tracked: list[str] | None) -> None:
    if tracked is None:
        report.add(
            "(git)",
            0,
            "Could not run `git ls-files` (not a git checkout, or git "
            "unavailable) — skipped tracked-.env-file check.",
            severity="WARN",
        )
        return

    for rel in tracked:
        name = Path(rel).name
        if name in ALLOWED_ENV_FILENAMES:
            continue
        if name == ".env" or (name.startswith(".env.") and not name.endswith(".example")):
            report.add(
                rel,
                0,
                "A real .env-style file is tracked in git — only "
                "`.env.example` and `.env.security.example` may be "
                "committed; this looks like it could contain real config.",
            )


# ── Rule 3: no non-empty defaultValue for a secret-shaped env var name ──────

SECRET_NAME_RE = re.compile(r"(KEY|SECRET|TOKEN|PASSWORD|CREDENTIAL)", re.IGNORECASE)

FROM_ENV_CALL_RE = re.compile(
    r"""String\.fromEnvironment\(\s*
        ['"](?P<name>[A-Za-z0-9_]+)['"]\s*
        (?:,\s*defaultValue\s*:\s*['"](?P<default>[^'"]*)['"])?
    """,
    re.VERBOSE,
)


def check_no_hardcoded_secret_defaults(report: Report) -> None:
    for fpath, rel, lines in iter_dart_files():
        text = "\n".join(lines)
        for m in FROM_ENV_CALL_RE.finditer(text):
            name = m.group("name")
            default = m.group("default")
            if not default:
                continue
            if not SECRET_NAME_RE.search(name):
                continue
            line_no = text.count("\n", 0, m.start()) + 1
            report.add(
                rel,
                line_no,
                f"String.fromEnvironment('{name}', defaultValue: '...') has "
                f"a non-empty fallback for a secret-shaped variable name — "
                f"a build that omits --dart-define-from-file would silently "
                f"ship this hardcoded value instead of failing closed.",
            )


# ── Rule 4: deploy scripts must not reference nonexistent .sql files ───────

JOIN_PATH_SCRIPT_DIR_RE = re.compile(
    r"""Join-Path\s+\$ScriptDir\s+["']([^"']+\.sql)["']"""
)


def check_deploy_script_paths(report: Report) -> None:
    deploy_ps1 = REPO_ROOT / "supabase" / "deploy.ps1"
    if not deploy_ps1.exists():
        return

    script_dir = deploy_ps1.parent  # supabase/
    text = deploy_ps1.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()

    for i, line in enumerate(lines):
        m = JOIN_PATH_SCRIPT_DIR_RE.search(line)
        if not m:
            continue
        # PowerShell '..\x' / '.\x' style relative path -> POSIX-ish resolve.
        rel_path = m.group(1).replace("\\", "/")
        resolved = (script_dir / rel_path).resolve()
        if not resolved.exists():
            report.add(
                "supabase/deploy.ps1",
                i + 1,
                f"References `{rel_path}` (resolved: "
                f"{resolved.relative_to(REPO_ROOT).as_posix()}), which does "
                f"not exist in the repository. Point this at the canonical "
                f"files under supabase/schema/ (see supabase/config.toml's "
                f"db.migrations.schema_paths) instead of a legacy path.",
            )


# ── Rule 5 (WARN): JWT-shaped literal in a tracked, non-template file ──────

JWT_RE = re.compile(r"eyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{10,}")

TEXT_EXTENSIONS = {
    ".dart", ".ts", ".js", ".json", ".yaml", ".yml", ".toml", ".md",
    ".sh", ".ps1", ".sql", ".gradle", ".kts", ".plist", ".xml",
}

SKIP_DIR_NAMES = {".git", "build", ".dart_tool", "node_modules", ".pub-cache"}


def check_no_jwt_literals(report: Report, tracked: list[str] | None) -> None:
    if tracked is None:
        return  # already warned once in check_no_tracked_env_files

    for rel in tracked:
        p = Path(rel)
        if p.suffix not in TEXT_EXTENSIONS:
            continue
        if any(part in SKIP_DIR_NAMES for part in p.parts):
            continue
        fpath = REPO_ROOT / rel
        if not fpath.exists():
            continue
        try:
            text = fpath.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for i, line in enumerate(text.splitlines()):
            if JWT_RE.search(line):
                report.add(
                    rel,
                    i + 1,
                    "Line contains a JWT-shaped literal (three dot-separated "
                    "base64url segments starting `eyJ`). Verify this is a "
                    "test fixture / placeholder, not a real committed "
                    "token — the authoritative check is the gitleaks "
                    "`secret_scan` CI job.",
                    severity="WARN",
                )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat warnings (e.g. JWT-shaped literal found) as failures too.",
    )
    args = parser.parse_args()

    report = Report("Config/secrets security guard")

    tracked = _git_ls_files()

    check_gitignore_coverage(report)
    check_no_tracked_env_files(report, tracked)
    check_no_hardcoded_secret_defaults(report)
    check_deploy_script_paths(report)
    check_no_jwt_literals(report, tracked)

    report.print_and_exit(
        fix_hint=(
            "See Section 10 (Secrets and Configuration) of "
            "'Production EduZone App — Agent Instructions.md'. Add the "
            "missing .gitignore pattern, remove the tracked .env-style "
            "file, remove the hardcoded default, or fix the dangling "
            "script path — then re-run this guard."
        ),
        fail_on_warn=args.strict,
    )


if __name__ == "__main__":
    main()
