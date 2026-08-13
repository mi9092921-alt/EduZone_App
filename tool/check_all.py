#!/usr/bin/env python3
"""
check_all.py — Runs every tool/check_*.py guard in one command and prints a
single pass/fail summary table.

This exists for environments without `make` available on PATH (notably a
default Windows shell/PowerShell), so the same five guards CI runs can be
run locally with one command:

    py -3 tool/check_all.py        (Windows, py launcher)
    python3 tool/check_all.py      (macOS / Linux)

It does not replace `make check-all` — both call the same underlying
scripts and will always agree, since this file just orchestrates
subprocess calls to the exact same check_*.py files as the Makefile does.

Exit code: 0 if every guard passed, 1 if any guard failed.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

TOOL_DIR = Path(__file__).parent

# Order matches the Makefile's check-all target / ci.yml step order.
CHECKS = [
    ("Accessibility Guard", "check_a11y.py"),
    ("Architecture Guard", "check_architecture.py"),
    ("Provider Cycle Guard", "check_provider_cycles.py"),
    ("RTL Guard", "check_rtl.py"),
    ("Design Token Guard", "check_design_tokens.py"),
    ("Performance Guard", "check_performance.py"),
    ("Memory Hygiene Guard", "check_memory_hygiene.py"),
    ("Localization Guard", "check_localizations.py"),
    ("Auth Security Guard", "check_auth_security.py"),
]


def main() -> int:
    results: list[tuple[str, str, int]] = []

    for label, script in CHECKS:
        script_path = TOOL_DIR / script
        print(f"\n{'=' * 60}")
        print(f"Running: {label}  ({script})")
        print("=" * 60)

        proc = subprocess.run([sys.executable, str(script_path)])
        results.append((label, script, proc.returncode))

    print(f"\n{'=' * 60}")
    print("SUMMARY")
    print("=" * 60)

    failed = False
    for label, script, code in results:
        status = "PASS" if code == 0 else "FAIL"
        if code != 0:
            failed = True
        print(f"  [{status}] {label:<22} ({script})")

    print()
    if failed:
        print("Overall: FAIL — one or more guards found violations above.")
        return 1

    print("Overall: PASS — all guards clean.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
