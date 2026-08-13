# EduZone App — Architecture Contract

Status: **verified against repository state as of commit `21e14cb`**
(`origin/main`, includes the Auth Security Guard / CI fix / import-ordering
commits already pushed). Statically inspected: directory layout,
`tool/check_architecture.py` guard output, `tool/check_provider_cycles.py`
guard output, `.github/workflows/ci.yml`, `Makefile`. Not verified: runtime
behavior, `flutter analyze`, `flutter test` — no Flutter/Dart toolchain was
available in the environment this document was produced in. See
"Verification gap" at the end.

This document is the single source of truth for EduZone's layering rules. It
exists so architectural boundaries are **enforced by CI**, not by developer
memory. If this file and `tool/check_architecture.py` ever disagree, the
guard's actual behavior is correct until one of them is fixed to match the
other — file an issue rather than assume either is right.

This pass is scoped to **Architecture only** (layering + Riverpod provider
dependency graph). It does not touch Design System / Accessibility tooling,
which were covered separately.

> **Why this file lives at the repo root and not in `docs/`:** `.gitignore`
> excludes `docs/` entirely (grouped with `.agents/`, `.amazonq/`,
> `.devin/`, `AGENTS.md`, `CLAUDE.md`, `ROLE.md` — evidently AI-agent
> working/scratch material, not shipped documentation). A file placed under
> `docs/` would never actually be tracked or pushed. Confirmed with
> `git check-ignore -v docs/ARCHITECTURE.md` before choosing this location.

---

## 1. The five zones

```
lib/
├── app/            composition root — bootstrap, router, session, app-level state
├── core/            infrastructure — network, storage, security, logging, error, l10n plumbing
├── design_system/   UI platform — tokens, components; app/feature-agnostic
├── features/        feature slices — one directory per user-facing capability
└── shared/           cross-cutting glue — shared widgets/models AND the one
                       sanctioned cross-feature facade layer (cross_feature/)
```

Verified current top-level contents:

| Zone | Verified subfolders |
|---|---|
| `app/` | `router/`, `session/`, `state/` |
| `core/` | `cache/`, `config/`, `constants/`, `error/`, `l10n/`, `layout/`, `logging/` (own `data/`, `domain/`, `handlers/`, `infrastructure/`), `navigation/`, `network/`, `permissions/`, `providers/`, `security/` (`guards/`), `services/`, `utils/` |
| `design_system/` | `components/` (`button/`, `card/`, `input/`, `layout/`, `progress/`, `status/`), `rules/`, `tokens/` |
| `features/` | `auth/`, `courses/`, `downloads/`, `home/`, `notifications/`, `profile/`, `todo/`, `video_player/` |
| `shared/` | `components/`, `cross_feature/`, `models/`, `providers/`, `utils/`, `widgets/` |

`README.md`'s own "🏗 Architecture" section currently describes a different,
older tree (e.g. `core/theme/`, and references a `RFC_DECISION_LOG.md` file
that **does not exist anywhere in this repository**) that does not match the
folders above — `lib/core/theme/` does not exist in this checkout. That
section is stale and should be treated as **not authoritative**; this
document and the guard scripts are. Fixed in §4 below.

## 2. Dependency direction (the contract)

```
        app/  (composition root — may depend on everything)
          │
          ▼
     features/*/presentation
          │
          ▼
     features/*/application
          │
          ▼
     features/*/domain   ◄── pure Dart, no Flutter, no outer-layer imports
          │
          ▲
     features/*/data
          │
          ▲
   core/  +  design_system/   (infrastructure — must stay feature-agnostic)
```

Rules, and which tool enforces each one today:

| # | Rule | Enforced by |
|---|---|---|
| 1 | `domain/` must not import `package:flutter/{material,widgets,cupertino}.dart` | `check_architecture.py` (pre-existing) |
| 2 | `domain/` must not import its own feature's `data/`, `application/`, or `presentation/` | `check_architecture.py` (pre-existing) |
| 3 | `data/` must not import `presentation/` (own feature) | `check_architecture.py` (pre-existing) |
| 4 | Feature A importing feature B's `data/`/`application/`/`presentation/` internals directly | `check_architecture.py` (pre-existing, WARN / `--strict` in CI) |
| 5 | `core/**` must not import `features/**` | `check_architecture.py` (**added this pass**) |
| 6 | `design_system/**` must not import `features/**` | `check_architecture.py` (**added this pass**) |
| 7 | Widget/UI code must not call Supabase/Dio/SQLite directly (must go through `data/`) | not statically enforced; verified by spot-check only (see §5) |
| 8 | Riverpod provider dependency graph must not contain a cycle | `check_provider_cycles.py` (**new this pass**) |

Rule 4 stays WARN-by-default/`--strict`-in-CI rather than a hard ERROR
because `lib/shared/cross_feature/**` is the sanctioned escape hatch for
legitimate cross-feature reads (see §3) — a blanket ERROR would make that
pattern itself a violation, which is not the intent.

## 3. The `shared/cross_feature/` facade pattern

`lib/shared/cross_feature/*.dart` are **barrel/facade files**, not
implementation. Example (`downloads_shared.dart`):

```dart
/// Cross-feature facade for `features/downloads`.
/// `courses`' lesson list needs download state (progress, quality picker)
/// per lesson row. See `auth_shared.dart` for the full rationale.
library;

export '../../features/downloads/application/providers/downloads_provider.dart';
export '../../features/downloads/presentation/widgets/quality_selector.dart';
```

This is the sanctioned version of "Feature A → shared contract → Feature B":
a feature that needs another feature's provider or a specific widget imports
the `*_shared.dart` facade in `lib/shared/cross_feature/`, never the other
feature's internals directly. One facade file exists per feature that is a
cross-feature dependency target (`auth_shared.dart`,
`notifications_shared.dart`, `courses_shared.dart`, `downloads_shared.dart`,
`profile_shared.dart`, `todo_shared.dart`) — verified present.

**Do not** extend this pattern by having `core/` or `design_system/` export
through a similar facade to reach into `features/`; rule 5/6 above apply to
those zones without exception, because they are meant to be usable
independently of any one feature (and, for `design_system/`, independently
of the app entirely).

## 4. What changed in this pass

Two concrete architecture gaps were found and closed, plus one stale-docs
fix, all in enforcement tooling / documentation rather than application
behavior, per the change-discipline principle of the smallest safe diff:

1. **`tool/check_architecture.py` had no rule for `core/` or
   `design_system/` importing `features/`.** The script's own docstring
   already promised this class of violation would be caught
   ("core → feature violations") but the code never implemented it. Running
   the extended guard against the tree surfaced exactly one real instance:
   `lib/core/services/cleanup_scheduler.dart` imports
   `features/downloads/data/datasources/download_local_ds.dart` directly.
   That import is structurally necessary — the importing code
   (`CleanupScheduler.callbackDispatcher`) runs inside a WorkManager
   background isolate with no Flutter binding and no Riverpod container, so
   it cannot reach the data source through the normal
   `application`/`domain` layers the way every other `core/` file must. It
   has been marked as a reviewed, suppressed exception (`// check-ignore`)
   with an inline comment explaining why, and recorded here as tracked
   architecture debt: the long-term fix is a small feature-agnostic
   "expired downloads" data contract living in `core/` or `shared/` so this
   isolate entrypoint stops reaching into `features/downloads/data/` at
   all. It is not yet done, because it changes production download-cleanup
   code for an isolate that has no test harness in this pass — out of
   scope for "smallest safe diff."

2. **No guard existed for circular Riverpod provider dependencies.**
   Added `tool/check_provider_cycles.py`: it statically rebuilds the same
   `ref.watch(...)`/`ref.read(...)` dependency graph Riverpod itself would
   build at runtime (using riverpod_generator's actual naming convention —
   e.g. a `class FooNotifier extends _$FooNotifier` generates `fooProvider`,
   stripping the trailing `Notifier`) and runs a DFS for cycles, so a
   circular dependency fails in CI on the PR that introduces it instead of
   surfacing later as a runtime `CircularDependencyError` the first time
   that provider subtree is built. Verified the detector itself actually
   works (not just trivially passing) by running it against a synthetic
   3-provider cycle in an isolated test directory before trusting its
   "no cycles" result on the real tree. Wired into `check_all.py`, the
   `Makefile`, and `ci.yml`, immediately after the Architecture Guard step
   and ahead of the RTL Guard — same relative position used in each of
   those three files. Scanned **103 providers** across the app with
   **zero cycles found** — a real, verified result, not an assumption.

3. **README's "🏗 Architecture" section is stale and references a file
   that doesn't exist** (`RFC_DECISION_LOG.md` — confirmed absent from the
   entire repository, not just moved). It also describes folders that don't
   exist in this checkout (`core/theme/`). Per the project's own
   documentation-integrity rule ("do not leave documentation claiming
   features that do not exist"), replaced that section with an accurate,
   short tree plus a pointer to this document, which is kept in sync with
   the guard's actual behavior on purpose.

All 9 guards currently in the repo (`check_a11y`, `check_architecture
--strict`, `check_provider_cycles`, `check_rtl`, `check_design_tokens`,
`check_performance`, `check_memory_hygiene`, `check_localizations`,
`check_auth_security --strict`) were run locally after these changes via
`python3 tool/check_all.py` and all **PASS**.

Note on process: an earlier draft of this document was written against
commit `e9126bd`. Before finalizing this pass, `origin/main` was re-fetched
and found to have moved to `21e14cb` (3 new commits already pushed: an Auth
Security Guard addition, an import-ordering refactor, and a CI
`continue-on-error` removal). Two of those commits touched files this pass
also needed to touch (`splash_screen.dart`'s `TextStyle` suppression-marker
placement, and `video_provider.dart`'s `lessonProgressSyncEngineProvider`
documentation) — **both were already fixed on `origin/main`, independently
and correctly**, so this pass does not re-touch either file; the local
working tree was reset to `origin/main` and only the two genuinely new
architecture items above (the `core/` → `features/` rule +
`cleanup_scheduler` exception, and the provider-cycle guard) were re-applied
on top of the current baseline.

## 5. What was checked but is not yet a guard (real gaps, left open)

These were verified by manual grep against the current tree, not by an
automated, CI-enforced check. They currently pass, but nothing prevents a
future regression:

- **Widget → backend calls (rule 7 above).** `grep`-checked that no file
  under `features/*/presentation/` references
  `supabase_flutter|Dio(|sqflite|Isar|Hive\.` — clean today, but this is a
  manual spot-check, not a guard. A `check_architecture.py` rule that flags
  those imports/symbols inside any `presentation/` file (mirroring the
  existing `domain/`-must-be-pure-Dart rule) would close this permanently;
  not implemented in this pass to keep the diff to the gaps actually found
  by running the tooling, rather than speculatively adding rules for
  violations that don't currently exist.
- **Generated-code boundary drift** (hand-edited `.freezed.dart`/`.g.dart`).
  Not checked here; `flutter analyze` / a `build_runner` dry-run in CI is
  the correct tool for this and was not runnable in this environment (see
  §6).

## 6. Verification gap

This pass was done with `python3` and static inspection only — no Flutter
SDK, Dart SDK, or emulator was available in the working environment. Not
run, and therefore **not verified**:

- `flutter analyze`
- `flutter pub get` / dependency resolution
- `flutter test`
- The two new/changed CI steps (`Architecture Guard`'s extended rule set,
  `Provider Cycle Guard`) have only been verified by running
  `python3 tool/check_architecture.py --strict` and
  `python3 tool/check_provider_cycles.py` locally; the actual GitHub
  Actions run has not executed.

To close this gap, run in an environment with the Flutter toolchain:

```bash
flutter pub get
flutter analyze
python3 tool/check_all.py
flutter test --coverage
```

and open a PR against `main` to let the real CI workflow execute `ci.yml`
end to end.
