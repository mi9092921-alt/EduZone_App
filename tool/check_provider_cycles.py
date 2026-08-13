#!/usr/bin/env python3
"""
check_provider_cycles.py — static circular-dependency guard for Riverpod
providers in EduZone App.

Riverpod already raises a runtime `CircularDependencyError` if a provider
transitively watches/reads itself, but that only surfaces the first time the
affected provider tree is actually built (e.g. in a widget test, or live in
the app) — it is not caught by `flutter analyze` and easily slips past a
reviewer skimming a diff across multiple files. This script builds the same
dependency graph statically from source and fails fast in CI instead.

Heuristic, same spirit as the other tool/check_*.py scripts: it maps
`ref.watch(xProvider...)` / `ref.read(xProvider...)` calls found in a
provider's own declaration to a directed edge (thisProvider -> xProvider),
using riverpod_generator's actual naming convention to recover a provider's
generated variable name from its Dart source declaration:

  @riverpod T fooBar(Ref ref, ...)              -> fooBarProvider
  @riverpod class FooBar extends _$FooBar       -> fooBarProvider
  @riverpod class FooNotifier extends _$FooNotifier -> fooProvider
      (riverpod_generator strips a trailing "Notifier" from the class name)
  final xProvider = Provider<T>((ref) => ...)   -> xProvider (used as-is)

A provider's "body" is heuristically everything from its declaration up to
the next top-level provider declaration in the same file (or EOF) — good
enough to catch same-file and cross-file cycles without a full Dart parser.

Exit code: 0 = OK, 1 = a cycle was found.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import LIB_ROOT, iter_dart_files  # noqa: E402

RIVERPOD_ANNOTATION_RE = re.compile(r"^\s*@[Rr]iverpod(?:\(|\s|$)")
FUNCTION_DECL_RE = re.compile(
    r"^\s*(?:Future|Stream|FutureOr)?(?:<[^>]+>)?\s*"
    r"[A-Za-z_][\w<>,?\s]*?\s+([a-z][A-Za-z0-9_]*)\s*\(\s*Ref\s+ref\b"
)
CLASS_DECL_RE = re.compile(r"^\s*class\s+([A-Za-z_]\w*)\s+extends\s+_\$")
MANUAL_PROVIDER_DECL_RE = re.compile(
    r"^\s*(?:final|late\s+final)\s+([a-zA-Z_]\w*Provider)\s*="
)
WATCH_OR_READ_RE = re.compile(r"\bref\.(?:watch|read)\(\s*([a-zA-Z_]\w*Provider)\b")


def _generated_name_for_class(class_name: str) -> str:
    base = class_name[: -len("Notifier")] if class_name.endswith("Notifier") else class_name
    return base[0].lower() + base[1:] + "Provider" if base else base


def _generated_name_for_function(fn_name: str) -> str:
    return fn_name + "Provider"


def _collect_declarations(lines: list[str]) -> list[tuple[int, str]]:
    """Returns [(start_line_index, provider_var_name), ...] in file order."""
    decls: list[tuple[int, str]] = []
    for i, line in enumerate(lines):
        if RIVERPOD_ANNOTATION_RE.match(line):
            # Look ahead a few lines for the class/function this annotation
            # attaches to (skips blank lines / doc comments).
            for j in range(i + 1, min(i + 6, len(lines))):
                candidate = lines[j].strip()
                if not candidate or candidate.startswith("//") or candidate.startswith("///"):
                    continue
                cls = CLASS_DECL_RE.match(lines[j])
                if cls:
                    decls.append((i, _generated_name_for_class(cls.group(1))))
                    break
                fn = FUNCTION_DECL_RE.match(lines[j])
                if fn:
                    decls.append((i, _generated_name_for_function(fn.group(1))))
                    break
                # Doesn't match either pattern (e.g. non-Ref first param,
                # or a form this heuristic doesn't recognize) -- skip.
                break
            continue

        m = MANUAL_PROVIDER_DECL_RE.match(line)
        if m:
            decls.append((i, m.group(1)))

    return decls


def build_graph() -> dict[str, set[str]]:
    graph: dict[str, set[str]] = {}

    for fpath, _rel, lines in iter_dart_files():
        decls = _collect_declarations(lines)
        if not decls:
            continue

        for idx, (start, name) in enumerate(decls):
            end = decls[idx + 1][0] if idx + 1 < len(decls) else len(lines)
            body = "\n".join(lines[start:end])
            deps = set(WATCH_OR_READ_RE.findall(body))
            deps.discard(name)  # self-watch inside e.g. ref.invalidateSelf() context, not a cycle input
            graph.setdefault(name, set()).update(deps)

    return graph


def find_cycles(graph: dict[str, set[str]]) -> list[list[str]]:
    WHITE, GRAY, BLACK = 0, 1, 2
    color: dict[str, int] = {n: WHITE for n in graph}
    cycles: list[list[str]] = []
    stack: list[str] = []

    def dfs(node: str) -> None:
        color[node] = GRAY
        stack.append(node)
        for dep in sorted(graph.get(node, ())):
            if dep not in graph:
                continue  # dependency outside our provider graph (fine)
            if color.get(dep, WHITE) == WHITE:
                dfs(dep)
            elif color.get(dep) == GRAY:
                cycle_start = stack.index(dep)
                cycles.append(stack[cycle_start:] + [dep])
        stack.pop()
        color[node] = BLACK

    for node in sorted(graph):
        if color[node] == WHITE:
            dfs(node)

    return cycles


def main() -> None:
    graph = build_graph()
    cycles = find_cycles(graph)

    if not cycles:
        total = len(graph)
        print(
            f"PASS: Provider dependency-cycle guard -- no cycles found "
            f"({total} providers scanned)."
        )
        sys.exit(0)

    print(f"FAIL: Provider dependency-cycle guard -- {len(cycles)} cycle(s) found:\n")
    for cycle in cycles:
        print(f"  {' -> '.join(cycle)}")
    print(
        "\nFix: break the cycle by having one side depend on a narrower "
        "provider (e.g. split shared state into its own provider both can "
        "watch) instead of watching each other directly, or by switching "
        "one edge from ref.watch to ref.read only if reactivity genuinely "
        "isn't needed there (read still participates in Riverpod's own "
        "circular-dependency check, so this only helps if it changes which "
        "provider actually needs which)."
    )
    sys.exit(1)


if __name__ == "__main__":
    main()
