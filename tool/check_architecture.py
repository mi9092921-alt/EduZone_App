#!/usr/bin/env python3
"""
check_architecture.py — Clean Architecture / feature-first layering guard for EduZone App.

EduZone's own convention (see lib/features/*/{domain,data,application,presentation})
is standard Clean Architecture per feature, wired together with relative imports
(no `package:app/...` imports are used internally — see any file under
lib/features/*/domain/usecases/ for the pattern this script assumes).

This script statically resolves every relative import (`import '../../x.dart'`)
to the file it points at, and checks it against layering rules. It cannot see
what a class *does* — only what a file *imports* — so it is a heuristic guard,
same spirit as check_a11y.py, not a full architecture linter.

Rules:
  ERROR  domain/  file imports package:flutter/material.dart (or widgets/cupertino)
         -> domain must stay pure Dart (no Flutter framework dependency).
  ERROR  domain/  file imports anything under a data/, application/, or
         presentation/ folder (own feature or another feature)
         -> domain must not depend on outer layers (dependency inversion).
  ERROR  data/    file imports anything under a presentation/ folder
         -> data must not depend on the UI layer.
  WARN   a file in feature A imports feature B's data/, application/, or
         presentation/ internals directly (not just feature B's domain/)
         -> tight cross-feature coupling; consider exposing a domain
            interface, or moving the shared piece into lib/shared/.
  ERROR  a file under lib/core/ imports anything under lib/features/**
         -> core is infrastructure and must stay feature-agnostic; a
            feature may depend on core, never the reverse. This is the
            "core -> feature" direction called out in the architecture
            contract. lib/shared/cross_feature/**  is intentionally
            exempt: those files are the one sanctioned facade layer for
            controlled cross-feature access (see that folder's own
            doc-comments), so this rule does not apply to lib/shared/.
  ERROR  a file under lib/design_system/ imports anything under
         lib/features/** -> the design system must stay app-agnostic so
         it can be reused/tested independently of any one feature.

Composition-root files are exempt (they are allowed to know about
everything): lib/app/**, lib/main.dart, and any *_providers.dart /
*injection*.dart dependency-injection wiring file.

Note: the two new core/design_system ERROR rules only scan files that
live under lib/core/ or lib/design_system/. lib/shared/cross_feature/**
is untouched by them (it lives under lib/shared/, not lib/core/), which
is intentional: those files are the one sanctioned facade layer for
controlled cross-feature access -- see that folder's own doc-comments.

Exit code: 0 = OK (or only warnings, unless --strict), 1 = errors found.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import LIB_ROOT, REPO_ROOT, Report, is_suppressed, iter_dart_files  # noqa: E402

LAYERS = ("domain", "data", "application", "presentation")

IMPORT_RE = re.compile(r"""^import\s+['"](\.\.?/[^'"]+)['"]""")
FLUTTER_UI_IMPORT_RE = re.compile(
    r"""^import\s+['"]package:flutter/(material|widgets|cupertino)\.dart['"]"""
)

EXEMPT_PATH_FRAGMENTS = ("lib/app/", "lib/main.dart")
EXEMPT_NAME_FRAGMENTS = ("_providers.dart", "injection", "_di.dart", "service_locator")


def is_exempt(rel: str) -> bool:
    if any(frag in rel for frag in EXEMPT_PATH_FRAGMENTS):
        return True
    name = rel.rsplit("/", 1)[-1]
    return any(frag in name for frag in EXEMPT_NAME_FRAGMENTS)


def feature_and_layer(rel_parts: tuple[str, ...]) -> tuple[str | None, str | None]:
    """rel_parts is relative to lib/, e.g. ('features','auth','domain','x.dart')."""
    if len(rel_parts) < 3 or rel_parts[0] != "features":
        return None, None
    feature = rel_parts[1]
    layer = rel_parts[2] if rel_parts[2] in LAYERS else None
    return feature, layer


def infra_zone(rel_parts: tuple[str, ...]) -> str | None:
    """Returns 'core' or 'design_system' if rel_parts (relative to lib/) is
    inside that infrastructure zone, else None."""
    if not rel_parts:
        return None
    if rel_parts[0] == "core":
        return "core"
    if rel_parts[0] == "design_system":
        return "design_system"
    return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true",
                         help="also fail (exit 1) on WARN-level cross-feature coupling")
    args = parser.parse_args()

    report = Report("Architecture / layering guard")

    for fpath, rel, lines in iter_dart_files():
        rel_parts = fpath.relative_to(LIB_ROOT).parts
        feature, layer = feature_and_layer(rel_parts)
        zone = infra_zone(rel_parts)

        if zone is not None and not is_exempt(rel):
            for i, line in enumerate(lines):
                stripped = line.strip()
                m = IMPORT_RE.match(stripped)
                if not m or is_suppressed(line):
                    continue
                target = (fpath.parent / m.group(1)).resolve()
                try:
                    target_rel_parts = target.relative_to(LIB_ROOT.resolve()).parts
                except ValueError:
                    continue
                if target_rel_parts and target_rel_parts[0] == "features":
                    report.add(
                        rel, i + 1,
                        f"{zone}/ file imports lib/features/ "
                        f"({'/'.join(target_rel_parts)}) -- {zone} must stay "
                        "feature-agnostic; a feature may depend on "
                        f"{zone}, never the reverse",
                    )

        if feature is None or is_exempt(rel):
            continue

        for i, line in enumerate(lines):
            stripped = line.strip()

            if layer == "domain" and FLUTTER_UI_IMPORT_RE.match(stripped):
                if not is_suppressed(line):
                    report.add(
                        rel, i + 1,
                        "domain/ file imports Flutter UI framework "
                        f"({stripped}) -- domain must be pure Dart",
                    )
                continue

            m = IMPORT_RE.match(stripped)
            if not m:
                continue
            if is_suppressed(line):
                continue

            target = (fpath.parent / m.group(1)).resolve()
            try:
                target_rel_parts = target.relative_to(LIB_ROOT.resolve()).parts
            except ValueError:
                continue  # import escapes lib/ (shouldn't happen) -- ignore

            target_feature, target_layer = feature_and_layer(target_rel_parts)
            if target_feature is None:
                continue  # target is shared/, core/, design_system/, etc. -- always OK

            if layer == "domain" and target_layer in ("data", "application", "presentation"):
                report.add(
                    rel, i + 1,
                    f"domain/ imports {target_layer}/ ({'/'.join(target_rel_parts)}) "
                    "-- domain must not depend on outer layers",
                )
            elif layer == "data" and target_layer == "presentation":
                report.add(
                    rel, i + 1,
                    f"data/ imports presentation/ ({'/'.join(target_rel_parts)}) "
                    "-- data must not depend on the UI layer",
                )
            elif target_feature != feature and target_layer in ("data", "application", "presentation"):
                report.add(
                    rel, i + 1,
                    f"feature '{feature}' imports feature '{target_feature}' internals "
                    f"({'/'.join(target_rel_parts)}) directly",
                    severity="WARN",
                )

    report.print_and_exit(
        fix_hint=(
            "For ERRORs: move the dependency direction to point inward (outer layers may "
            "depend on domain/, never the reverse), or move the shared type into a "
            "domain-level interface. For WARNs: consider whether the imported piece "
            "belongs in lib/shared/ instead of inside another feature, or whether the "
            "consuming feature should depend on it via that feature's domain/ entities "
            "only instead of its data/application/presentation internals."
        ),
        fail_on_warn=args.strict,
    )


if __name__ == "__main__":
    main()
