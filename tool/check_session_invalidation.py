#!/usr/bin/env python3
"""Guard keep-alive feature providers against session-cache drift.

Riverpod auto-disposes ordinary providers, but a provider using static or
dynamic keep-alive can retain account-scoped data after logout. This check is
deliberately heuristic: infrastructure objects are allow-listed by naming
convention, while data-like keep-alive providers must be reachable from the
composition-root logout invalidation function.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import LIB_ROOT, Report, is_suppressed, iter_dart_files  # noqa: E402


ANNOTATION_RE = re.compile(r"^\s*@(?:r|R)iverpod(?:\(|\s|$)")
STATIC_KEEP_ALIVE_RE = re.compile(
    r"@Riverpod\(\s*keepAlive\s*:\s*true\s*\)"
)
CLASS_RE = re.compile(r"^\s*class\s+([A-Za-z_]\w*)\s+extends\s+_\$")
FUNCTION_RE = re.compile(
    r"^\s*(?:Future|Stream|FutureOr)?(?:<[^>]+>)?\s*"
    r"[A-Za-z_]\w*(?:<[^>]+>)?\s+([a-z][A-Za-z0-9_]*)\s*\(\s*Ref\s+ref\b"
)
MANUAL_PROVIDER_RE = re.compile(
    r"^\s*(?:final|late\s+final)\s+([A-Za-z_]\w*Provider)\s*="
)
HELPER_RE = re.compile(r"^\s*void\s+(invalidate\w*Providers)\s*\(\s*Ref\s+ref")
INVALIDATE_RE = re.compile(r"\bref\.invalidate\(\s*([A-Za-z_]\w*Provider)\b")

INFRA_SUFFIXES = (
    "Repository",
    "Service",
    "DataSource",
    "Manager",
    "Engine",
    "Client",
    "Controller",
    "Factory",
    "Gateway",
    "Handler",
    "Coordinator",
    "Guard",
    "Validator",
    "Builder",
    "UseCase",
    "Usecase",
)

SESSION_FILE = LIB_ROOT / "app" / "session" / "session_invalidation.dart"
AGGREGATOR = "invalidateAllUserScopedProviders"


def generated_name_for_class(class_name: str) -> str:
    base = class_name[:-8] if class_name.endswith("Notifier") else class_name
    return f"{base[0].lower()}{base[1:]}Provider" if base else base


def provider_declarations(lines: list[str]) -> list[tuple[int, str | None]]:
    """Return provider starts; None entries are manual-provider boundaries."""
    declarations: list[tuple[int, str | None]] = []
    for index, line in enumerate(lines):
        if ANNOTATION_RE.match(line):
            for candidate_line in lines[index + 1 : index + 6]:
                candidate = candidate_line.strip()
                if not candidate or candidate.startswith("//"):
                    continue
                class_match = CLASS_RE.match(candidate_line)
                if class_match:
                    declarations.append(
                        (index, generated_name_for_class(class_match.group(1)))
                    )
                else:
                    function_match = FUNCTION_RE.match(candidate_line)
                    if function_match:
                        declarations.append((index, function_match.group(1) + "Provider"))
                break
        elif MANUAL_PROVIDER_RE.match(line):
            declarations.append((index, None))
    return declarations


def is_infrastructure(provider_name: str) -> bool:
    base = provider_name.removesuffix("Provider")
    return base.endswith(INFRA_SUFFIXES)


def kept_alive_providers() -> list[tuple[str, str, int, str]]:
    result: list[tuple[str, str, int, str]] = []
    for _path, relative, lines in iter_dart_files(
        root=LIB_ROOT / "features", extra_exclude_dirs=("features/auth",)
    ):
        declarations = provider_declarations(lines)
        for position, (start, name) in enumerate(declarations):
            if name is None:
                continue
            end = declarations[position + 1][0] if position + 1 < len(declarations) else len(lines)
            annotation = lines[start]
            if STATIC_KEEP_ALIVE_RE.search(annotation):
                if not is_suppressed(annotation):
                    result.append((relative, name, start + 1, "static"))
                continue
            for line_index in range(start, end):
                line = lines[line_index]
                if line.lstrip().startswith("//"):
                    continue
                if "ref.keepAlive()" in line:
                    if not is_suppressed(line):
                        result.append((relative, name, line_index + 1, "dynamic"))
                    break
    return result


def invalidation_index() -> dict[str, list[tuple[str, int, str | None]]]:
    result: dict[str, list[tuple[str, int, str | None]]] = {}
    for _path, relative, lines in iter_dart_files():
        helper: str | None = None
        for line_number, line in enumerate(lines, start=1):
            helper_match = HELPER_RE.match(line)
            if helper_match:
                helper = helper_match.group(1)
            for match in INVALIDATE_RE.finditer(line):
                result.setdefault(match.group(1), []).append(
                    (relative, line_number, helper)
                )
    return result


def reachable_helpers() -> set[str]:
    if not SESSION_FILE.exists():
        return set()
    text = SESSION_FILE.read_text(encoding="utf-8", errors="replace")
    function = re.search(
        rf"void\s+{AGGREGATOR}\s*\(\s*Ref\s+ref\s*\)\s*\{{(.*?)\}}",
        text,
        re.DOTALL,
    )
    if not function:
        return set()
    return set(re.findall(r"\b([A-Za-z_]\w*Providers)\s*\(\s*ref\s*\)", function.group(1)))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat reachability warnings as failures.",
    )
    args = parser.parse_args()

    report = Report("Session-invalidation / keepAlive-provider guard")
    calls = invalidation_index()
    reachable = reachable_helpers() | {AGGREGATOR}

    for relative, provider, line_number, kind in kept_alive_providers():
        if is_infrastructure(provider):
            continue
        provider_calls = calls.get(provider, [])
        if not provider_calls:
            report.add(
                relative,
                line_number,
                f"`{provider}` uses {kind} keepAlive but has no "
                f"`ref.invalidate({provider}...)` call. Add it to the owning "
                "feature's logout invalidation helper, or suppress this line "
                "only after documenting why the cache is not user-scoped.",
            )
            continue
        if not any(helper in reachable for _file, _line, helper in provider_calls):
            sites = ", ".join(f"{file}:{line}" for file, line, _ in provider_calls)
            report.add(
                relative,
                line_number,
                f"`{provider}` is invalidated at {sites}, but the call is not "
                f"provably reachable from `{AGGREGATOR}`.",
                severity="WARN",
            )

    report.print_and_exit(
        fix_hint=(
            "Keep account-scoped providers auto-disposed where possible. For a "
            "necessary keep-alive cache, add an owning invalidateXProviders(Ref) "
            "helper and call it from lib/app/session/session_invalidation.dart."
        ),
        fail_on_warn=args.strict,
    )


if __name__ == "__main__":
    main()
