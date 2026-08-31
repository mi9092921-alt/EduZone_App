#!/usr/bin/env python3
"""
check_memory_hygiene.py - lifecycle guard for EduZone App.

The project default is strict auto-disposal:
  - generated Riverpod providers use @riverpod unless explicitly allow-listed
  - hand-written Riverpod providers must use AutoDispose provider variants
  - owned controllers (Text/Animation/Scroll/Tab/PageController, FocusNode),
    timers, stream subscriptions, and stream controllers must have a
    disposal hook in the same hand-written source file
  - a `.addListener(` registration (on a self-owned or externally-passed
    ChangeNotifier-based object) must have a matching `.removeListener(`
    or the owning controller's `.dispose(` in the same file

Exit code: 0 = OK, 1 = violations found.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import Report, is_suppressed, iter_dart_files  # noqa: E402

LONG_LIVED_PROVIDER_ALLOWLIST = {
    # App-wide singletons/state roots. Adding a new keepAlive provider should be
    # a deliberate architecture decision, not a default.
    "storageService",
    "requestCancellationManager",
    "router",
    "eventBus",
    "logQueue",
    "logRemoteDataSource",
    "logEncryptionService",
    "auditHandler",
    "activityHandler",
    "analyticsHandler",
    "crashHandler",
    "syncEngine",
    "eventDispatcher",
    "Auth",
    "supabaseClient",
    "authRemoteDataSource",
    "authRepository",
    "loginUserUseCase",
    "checkStudentAppAccessUseCase",
    "bindDeviceUseCase",
    "logoutUserUseCase",
    "validateDeviceExistsUseCase",
    "getCurrentUserUseCase",
    "updateRemoteDataSource",
    "updateService",
    "authActivitySyncService",
    "watchedLessonsService",
    "courseAccessService",
    "courseProgress",
    "BookmarkedCourses",
    "encryptionService",
    "downloadRemoteDataSource",
    "downloadLocalDataSource",
    "downloadManager",
    "downloadLinkRefresher",
    "downloadExecutionService",
    "downloadRepository",
    "downloadChanges",
    "DownloadsNotifier",
    # One app-wide queue shared by every video-progress family instance;
    # the provider registers ref.onDispose(engine.dispose).
    "lessonProgressSyncEngine",
}

MANUAL_PROVIDER_RE = re.compile(
    r"\b(?<!AutoDispose)(Provider|NotifierProvider|AsyncNotifierProvider|"
    r"FutureProvider|StreamProvider|StateProvider)\s*(?:<|\()"
)
KEEP_ALIVE_ANNOTATION_RE = re.compile(r"@Riverpod\(\s*keepAlive:\s*true\s*\)")
CLASS_DECLARATION_RE = re.compile(r"^\s*class\s+([A-Za-z_]\w*)\b")
FUNCTION_DECLARATION_RE = re.compile(
    r"^\s*(?:Future|Stream|[A-Z][A-Za-z0-9_]*)(?:<[^>]+>)?\s+"
    r"([a-zA-Z_]\w*)\s*\("
)
REF_KEEP_ALIVE_RE = re.compile(r"\bref\.keepAlive\(")

RESOURCE_PATTERNS = (
    ("TextEditingController", r"\bTextEditingController\("),
    ("AnimationController", r"\bAnimationController\("),
    ("ScrollController", r"\bScrollController\("),
    ("TabController", r"\bTabController\("),
    ("PageController", r"\bPageController\("),
    ("FocusNode", r"\bFocusNode\("),
    ("Timer", r"\bTimer(?:\.periodic)?\("),
    ("StreamSubscription", r"(?:\bfinal\b|\bvar\b|\blate\b|[_a-zA-Z]\w*\s*=).*\.listen\("),
    ("StreamController", r"\bStreamController(?:<[^>]+>)?\("),
    # Not a constructor -- `.addListener(` registers a callback on any
    # ChangeNotifier-based object (own AnimationController/FocusNode/
    # ScrollController above, or one owned by a parent and passed in, e.g.
    # `widget.controller`). Flagged separately from the owning controller
    # checks above because the two can diverge: a widget can own-and-
    # dispose a controller it never listens to, or listen to a controller
    # it does NOT own (so the controller-specific dispose() checks above
    # don't apply) and still be responsible for detaching that one
    # listener. See M3/M13 in the resource-safety roadmap ("listener
    # added in initState... old listener remains").
    ("Listener", r"\baddListener\("),
)

DISPOSAL_PATTERNS = {
    "TextEditingController": re.compile(r"\.dispose\("),
    "AnimationController": re.compile(r"\.dispose\("),
    "ScrollController": re.compile(r"\.dispose\("),
    "TabController": re.compile(r"\.dispose\("),
    "PageController": re.compile(r"\.dispose\("),
    "FocusNode": re.compile(r"\.dispose\("),
    "Timer": re.compile(r"\.cancel\("),
    "StreamSubscription": re.compile(r"\.cancel\("),
    "StreamController": re.compile(r"\.close\("),
    # Disposing the owning controller implicitly detaches every listener
    # registered on it, so `.dispose(` alone (no explicit `.removeListener(`
    # required) is accepted here too -- the common, correct pattern for a
    # self-owned controller. `.removeListener(` is what covers the
    # not-self-owned case (e.g. `widget.controller?.addListener(...)`,
    # where this widget cannot call `.dispose()` on a controller it does
    # not own and must detach its own listener explicitly instead).
    "Listener": re.compile(r"\.removeListener\(|\.dispose\("),
}


def _next_declaration_name(lines: list[str], start: int) -> str | None:
    for line in lines[start + 1: start + 8]:
        stripped = line.strip()
        if not stripped or stripped.startswith("///") or stripped.startswith("//"):
            continue
        class_match = CLASS_DECLARATION_RE.search(stripped)
        if class_match:
            return class_match.group(1)
        function_match = FUNCTION_DECLARATION_RE.search(stripped)
        if function_match:
            return function_match.group(1)
    return None


def _file_has_disposal(resource: str, text: str) -> bool:
    if "ref.onDispose(" in text:
        return True
    return bool(DISPOSAL_PATTERNS[resource].search(text))


def main() -> None:
    report = Report("Memory hygiene guard")

    for _fpath, rel, lines in iter_dart_files():
        text = "\n".join(lines)

        for i, line in enumerate(lines):
            if is_suppressed(line):
                continue

            if MANUAL_PROVIDER_RE.search(line):
                report.add(
                    rel,
                    i + 1,
                    "manual Riverpod provider is not AutoDispose -- use an "
                    "AutoDispose*Provider variant unless it is an allow-listed "
                    "app-wide singleton",
                )

            if KEEP_ALIVE_ANNOTATION_RE.search(line):
                name = _next_declaration_name(lines, i)
                if name not in LONG_LIVED_PROVIDER_ALLOWLIST:
                    report.add(
                        rel,
                        i + 1,
                        f"keepAlive provider `{name or '<unknown>'}` is not "
                        "allow-listed with a lifecycle rationale",
                    )

            if REF_KEEP_ALIVE_RE.search(line):
                context = "\n".join(lines[max(0, i - 8): i + 3])
                if "IMPORTANT" not in context and "keepAlive" not in context:
                    report.add(
                        rel,
                        i + 1,
                        "ref.keepAlive() needs a nearby lifecycle comment "
                        "explaining why auto-disposal is unsafe here",
                    )

        for resource, pattern in RESOURCE_PATTERNS:
            if re.search(pattern, text) and not _file_has_disposal(resource, text):
                report.add(
                    rel,
                    1,
                    f"owns {resource} but no matching dispose/ref.onDispose "
                    "cleanup hook was found in this file",
                )

    report.print_and_exit(
        fix_hint=(
            "Use @riverpod/AutoDispose*Provider by default. If a provider must "
            "be keepAlive, add it to LONG_LIVED_PROVIDER_ALLOWLIST with a "
            "short rationale. Dispose controllers, cancel timers/subscriptions, "
            "close stream controllers, and detach addListener( registrations "
            "(.removeListener(, or .dispose( on a self-owned controller) from "
            "dispose() or ref.onDispose()."
        ),
    )


if __name__ == "__main__":
    main()
