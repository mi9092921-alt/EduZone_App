# EduZone App — Design System Audit

Status: **verified against repository state as of commit `4a01228`**
(local checkpoint on top of `origin/main` @ `4a9a0d2`, which itself
already includes the Auth Security Guard, CI integration-test job, and
session-validation commits). Statically inspected: `lib/design_system/`
contents, `tool/check_design_tokens.py` guard output before/after this
pass. Not verified: `flutter analyze`, `flutter test`, or how any of this
actually renders — no Flutter/Dart toolchain or emulator was available in
the environment this document was produced in. See "Verification gap".

This pass is scoped to **Design System only**, following
`EduZone_Architecture_Design_System_Accessibility_Roadmap.md`'s Phase
D–F/O (token system, typography, UI-consistency enforcement). It does not
cover per-component accessibility contracts (Phase G/H/I) or golden/visual
regression testing (Phase P/Q) — separate passes.

---

## 1. Baseline: the token system is real and reasonably complete

`lib/design_system/tokens/` (11 files, ~1080 lines) already covers:

| Token file | Covers |
|---|---|
| `app_colors.dart` | Full light/dark palette |
| `app_text_styles.dart` | `display`/`h1`–`h4`/`body*`/`label*` scale + `buildAppTextTheme()` |
| `app_spacing.dart`, `app_layout.dart`, `app_sizes.dart` | 8dp-grid spacing, layout, sizing |
| `app_radius.dart` | Corner-radius scale |
| `app_motion.dart` | `fast`/`medium`/`slow`/`shimmer` durations + curve set |
| `app_elevation.dart` | `AppShadows.level1/2/3` (neutral, `Colors.black`-based) + `AppElevation.shadowSm/Md/Lg` |
| `app_icons.dart` | Curated semantic icon set (navigation/actions/status) |
| `app_theme.dart`, `app_theme_extensions.dart` | `ThemeData` assembly, `DesignSystemColors`/`CourseCardTheme` extensions |

**Typography/locale handling (roadmap Phase F) is already well-engineered,
verified, no gap found:** `app_theme.dart` bundles a single font (Cairo)
covering both Arabic and Latin scripts, applied unconditionally regardless
of locale, with an explicit code comment explaining why: avoids a
network-fetched font (no flash-of-unstyled-text on first launch) and avoids
font-mismatch when Arabic and English text appear on the same screen (e.g.
an English course title inside an otherwise-Arabic UI). The `locale`
parameter is deliberately kept in `buildAppTextTheme()`'s signature "in
case a future locale needs a different font override" even though it's
currently unused — a reasonable, documented, forward-compatible choice, not
dead code.

## 2. What changed in this pass

### 2.1 `check_design_tokens.py`: closed a real, verified coverage gap

The guard only ever checked 4 patterns (`Color`, `TextStyle`, `EdgeInsets`,
`BorderRadius`) even though the token system also ships `AppMotion`
(animation durations) and `AppShadows`/`AppElevation` (box shadows) — two
full token families with **zero enforcement** behind them, invisible drift
by construction.

Added two more checks, both WARN-severity (matches the existing severity
policy for the other magic-number checks — doesn't newly fail CI):

- **`BoxShadow(...)` outside `design_system/`** — unambiguous, no
  false-positive risk (`BoxShadow` has no non-UI meaning in Flutter).
- **`Duration(...)` outside `design_system/`** — needed real care. A first
  attempt matching every `Duration(` literal produced ~65 warnings; manual
  inspection showed most were **false positives** — network timeouts
  (`AppConfig`), log-flush intervals, GPS position timeouts, polling
  intervals, retry backoff — business-logic timing with nothing to do with
  `AppMotion` (UI animation timing). Narrowed the regex to only match
  `Duration(...)` passed to a parameter whose *name itself* ends in
  `duration`/`Duration` (`duration:`, `transitionDuration:`,
  `reverseTransitionDuration:`) — the actual Flutter naming convention for
  animation timing (`AnimationController`, `AnimatedOpacity`,
  `PageRouteBuilder.transitionDuration` all use it). This dropped the count
  to **19** real UI-timing instances, each spot-checked to confirm.

Three more checks were **considered and deliberately not added** — each
would have produced a genuine false-positive or redundancy problem rather
than a real finding, and the reasoning for skipping each is recorded
directly in the script's own docstring so a future contributor doesn't
have to rediscover it:

- **`FontWeight.*`**: a naive check flagged 87 hits; closer inspection
  (tracing the actual multi-line call each sat inside, not just the single
  matched line) showed the near-totality were
  `AppTextStyles.x.copyWith(fontWeight: ...)` — the *already-sanctioned*
  pattern for a small per-instance variation on an existing token, not raw
  `TextStyle(fontWeight: ...)`. The real violation (a raw `TextStyle(...)`
  constructor) is already caught by the existing `TEXTSTYLE_RE` check at
  the correct point of intervention; a separate FontWeight-specific check
  would either double-report the same violation or need the same
  multi-line body-tracking `check_a11y.py` uses for `IconButton(` blocks,
  which isn't proportionate here.
- **`Icons.*`**: Flutter's `Icons` class has thousands of members; most
  icon usages in the app are legitimately one-off, not a repeated design
  value the way colors/spacing/radii are. `app_icons.dart` already exists
  for icons that *are* semantic/reused. Mandating every single `Icons.x`
  reference route through a curated token class would be the kind of
  abstraction-for-its-own-sake the project's own instructions warn
  against.
- **`.withOpacity(`**: checked separately — already fully migrated to
  `.withValues(alpha: ...)` (131 call sites); the one remaining
  `.withOpacity(` hit is inside a doc comment, not executable code.
  Nothing to enforce.

### 2.2 Fixed 6 of the 19 Duration warnings — mechanically, zero visual risk

Cross-referenced each of the 19 flagged `Duration(milliseconds: N)` values
against the actual token values in `AppMotion` (`fast`=150,
`medium`=300, `slow`=500, `shimmer`=1500). **6 were an exact match**:

| File | Was | Now |
|---|---|---|
| `shared/components/course_card/course_card_base.dart:59` | `Duration(milliseconds: 150)` | `AppMotion.fast` |
| `features/downloads/.../offline_player_controls_overlay.dart:54` | `Duration(milliseconds: 300)` | `AppMotion.medium` |
| `features/todo/.../todo_card_base.dart:24` | `Duration(milliseconds: 300)` | `AppMotion.medium` |
| `features/video_player/.../youtube_player_widget.dart:103` | `Duration(milliseconds: 300)` | `AppMotion.medium` |
| `shared/widgets/network_banner.dart:33` | `Duration(milliseconds: 300)` | `AppMotion.medium` |
| `features/profile/.../settings_floating_graduation_icon.dart:26` | `Duration(milliseconds: 1500)` | `AppMotion.shimmer` |

These are **pure deduplication, not a design decision** — the millisecond
value is numerically identical before and after, so the rendered animation
timing is unchanged; only the source of truth moved from an inline literal
to the shared token. The last file didn't previously import the design
system at all; added `import 'package:app/design_system/design_system.dart';`
in the correct alphabetical position per this repo's `directives_ordering`
lint rule (`package:app/...` sorts before `package:flutter/...` and
`package:font_awesome_flutter/...`).

**The remaining 13 Duration warnings were deliberately left alone** — their
values (200ms, 250ms, 400ms, 600ms, 1000ms, 1200ms, 2000ms) don't match any
existing `AppMotion` value. Snapping e.g. a 250ms transition to
`AppMotion.fast` (150ms) or `AppMotion.medium` (300ms) would be a real,
visible timing change to the actual animation, which is a design decision
that deserves a look at the rendered screen, not a blind find-and-replace
— consistent with this project's own "measure before optimizing, evidence
over assumption" principle.

### 2.3 All 12 BoxShadow warnings were left alone — and the reason is itself a finding

Every one of the 12 flagged `BoxShadow(...)` instances was individually
inspected. **None of them are elevation shadows that `AppShadows`/
`AppElevation` are meant to cover.** `AppShadows.level1/2/3` are always
neutral `Colors.black.withValues(alpha: ...)` — a depth/elevation effect.
Every flagged instance in the app instead uses a **semantic, contextual
color** — `AppColors.success.withValues(alpha: 0.3)` (a checkbox's
success glow), `typeColor.withValues(alpha: 0.1)` (a notification tile's
category-color halo), `colors.primary.withValues(alpha: 0.22)` (an
animated badge glow), `ds.error.withValues(alpha: 0.3)` (an error banner
shadow), etc. These are **colored emphasis/glow effects**, a different
design concept from neutral elevation, and forcing them into
`AppShadows.level1/2/3` would silently strip the color and change what the
component actually communicates (e.g. "this checkbox is in a success
state" would lose its green glow).

This is a genuine design-system gap, not application drift: **there is no
token family for colored glow/emphasis shadows**, only neutral elevation
ones. The 12 instances stay flagged as a visible, correctly-categorized
WARN backlog. The right fix is adding a new token (e.g. a
`AppShadows.glow(Color color, {double opacity, double blur})` helper or a
small `level1Tinted`/`level2Tinted` set) once someone reviews the 5–6
distinct existing glow patterns and decides how many genuinely-different
variants are needed — a design decision, not a mechanical one, so it's
intentionally not done in this pass.

## 3. Result

`python3 tool/check_design_tokens.py` before this pass: 4 checks, blind to
two entire token families (`AppMotion`, `AppShadows`/`AppElevation`).
After: 6 checks, **31 real WARN-level findings now visible in CI** (19 → 13
Duration + 12 BoxShadow, after the 6 safe fixes), down from an initial
naive attempt that would have produced ~78 warnings (65 Duration false
positives + 12 BoxShadow + a redundant FontWeight pass) if the false-positive
classes hadn't been hunted down first.

All 9 guards (`check_a11y`, `check_architecture --strict`,
`check_provider_cycles`, `check_rtl`, `check_design_tokens`,
`check_performance`, `check_memory_hygiene`, `check_localizations`,
`check_auth_security --strict`) pass via `python3 tool/check_all.py`.

## 4. What was checked but is not yet a guard (real gaps, left open)

- **The colored-glow token family described in §2.3.** Deliberately left
  as a design decision, not implemented here.
- **The remaining 13 non-exact-match Duration values (§2.2).** Same
  reasoning — a real design decision about whether to snap each to the
  nearest existing `AppMotion` value or add a new one, not something to
  guess at without seeing the rendered result.
- **"Wrong component usage" / "duplicate UI patterns"** (mentioned in the
  roadmap's Phase O as a longer-term goal for `check_design_tokens.py`).
  Not attempted here — this needs structural/AST-level comparison across
  widget trees, not a line-based regex guard, and no evidence was gathered
  in this pass on what the actual duplicate patterns are.
- **Golden tests for design-system components themselves** (roadmap Phase
  P). Requires the Flutter toolchain; not runnable in this environment.

## 5. Verification gap

Static Python inspection only — no Flutter SDK, Dart SDK, or emulator
available. Not run, therefore **not verified**:

- `flutter analyze` (would catch e.g. an unused import if one of the 6
  Duration fixes had been misapplied — each was checked by hand instead)
- `flutter pub get` / dependency resolution
- `flutter test` / any widget or golden test
- Visual confirmation that the 6 `AppMotion.*` swaps render identically to
  the literals they replaced (expected, since the millisecond values are
  numerically identical, but "expected" is not "verified")

To close this gap:

```bash
flutter pub get
flutter analyze
python3 tool/check_all.py
flutter test --coverage
```

and open a PR against `main` to let the real CI workflow run end to end.
