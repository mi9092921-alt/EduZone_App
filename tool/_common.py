"""
_common.py — Shared utilities for EduZone App's tool/check_*.py scripts.

Not a check itself. Imported by the other scripts in this folder so each one
stays as small and readable as check_a11y.py, without repeating the same
file-walking / exclusion / reporting boilerplate five times.

Conventions matched from check_a11y.py:
  - ROOT points at <repo>/lib
  - Windows console encoding fix
  - PASS/FAIL text report to stdout, exit code 0/1
"""

from __future__ import annotations

import sys
from dataclasses import dataclass, field
from pathlib import Path

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

REPO_ROOT = Path(__file__).parent.parent
LIB_ROOT = REPO_ROOT / "lib"

# Generated code is not hand-written and must never be flagged — running
# `dart run build_runner build` again would just regenerate the same
# "violation" forever.
GENERATED_SUFFIXES = (".freezed.dart", ".g.dart", ".gr.dart", ".config.dart")

# A line ending in one of these suppresses that single line from any of the
# checks in this toolset — mirrors `// ignore:` for the Dart analyzer, so
# a team member can consciously accept one specific case instead of the
# check being deleted or muted wholesale.
SUPPRESS_MARKER = "check-ignore"


def iter_dart_files(root: Path = LIB_ROOT, extra_exclude_dirs: tuple[str, ...] = ()):
    """Yield (path, rel_posix, lines) for every hand-written .dart file under root."""
    for fpath in sorted(root.rglob("*.dart")):
        if any(fpath.name.endswith(suf) for suf in GENERATED_SUFFIXES):
            continue
        rel = fpath.relative_to(REPO_ROOT).as_posix()
        if any(f"/{d}/" in f"/{rel}" for d in extra_exclude_dirs):
            continue
        text = fpath.read_text(encoding="utf-8", errors="replace")
        yield fpath, rel, text.splitlines()


def is_suppressed(line: str) -> bool:
    return SUPPRESS_MARKER in line


@dataclass
class Violation:
    rel: str
    line_no: int  # 1-indexed
    message: str
    severity: str = "ERROR"  # "ERROR" or "WARN"

    def __str__(self) -> str:
        return f"  [{self.severity}] {self.rel}:{self.line_no}  -- {self.message}"


@dataclass
class Report:
    check_name: str
    violations: list[Violation] = field(default_factory=list)

    def add(self, rel: str, line_no: int, message: str, severity: str = "ERROR"):
        self.violations.append(Violation(rel, line_no, message, severity))

    def errors(self):
        return [v for v in self.violations if v.severity == "ERROR"]

    def warnings(self):
        return [v for v in self.violations if v.severity == "WARN"]

    def print_and_exit(self, fix_hint: str, fail_on_warn: bool = False) -> None:
        errs, warns = self.errors(), self.warnings()

        if not errs and not warns:
            print(f"PASS: {self.check_name} -- no violations found.")
            sys.exit(0)

        if errs:
            print(f"FAIL: {self.check_name} -- {len(errs)} error(s) found:\n")
            for v in errs:
                print(v)
        if warns:
            print(f"\nWARN: {self.check_name} -- {len(warns)} warning(s) found "
                  f"(non-blocking{' but treated as failures via --strict' if fail_on_warn else ''}):\n")
            for v in warns:
                print(v)

        print(f"\nFix: {fix_hint}")
        print(f"\n(Suppress a specific line you've deliberately reviewed and accepted by "
              f"appending `// {SUPPRESS_MARKER}` as a trailing comment on that line.)")

        sys.exit(1 if (errs or (warns and fail_on_warn)) else 0)
