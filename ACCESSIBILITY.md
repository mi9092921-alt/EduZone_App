# EduZone App — Accessibility Audit

Status: **verified against repository state as of commit `1fc9d7a`**
(`origin/main`, includes SECURITY.md/Fastlane, the design-system patch, the
offline-security-hardening work, and an auth-error-observability commit —
all already pushed). Statically inspected: `tool/check_a11y.py` (before and
after this pass), `test/` contents. Not verified: `flutter analyze`,
`flutter test`, screen-reader behavior on a real device/emulator, or how
anything actually renders — no Flutter/Dart toolchain or emulator was
available in the environment this document was produced in. See
"Verification gap".

This pass is scoped to **Accessibility**, completing the roadmap's
three-pillar sequence (`Architecture Excellence → Design System Foundation
→ Accessible UI Implementation` — see `ARCHITECTURE.md` and
`DESIGN_SYSTEM.md` for the first two, already pushed).

---

## 1. What was found

`tool/check_a11y.py` only ever checked one thing: raw `IconButton(` with no
`tooltip:`. Two real problems with that scope, both fixed this pass:

### 1.1 The guard itself had the same tooling bug found in earlier passes

`check_a11y.py` ran its whole check as unguarded top-level module code (no
`if __name__ == "__main__":`), had no `// check-ignore` suppression support
at all (every other guard in `tool/` has it), and didn't exclude generated
files. It had silently diverged from `tool/_common.py` — which documents
itself as having been extracted *from* `check_a11y.py` in the first place.
Migrated it onto `Report`/`is_suppressed`/`iter_dart_files`, matching every
other script in `tool/`. Behavior for the IconButton check itself is
unchanged (still 0 IconButton violations found — `AppIconButton`'s
`semanticLabel` constructor parameter is `required`, which the Dart
compiler already enforces at every call site with a stronger guarantee
than any regex-based guard could add).

### 1.2 The real gap: icon-only `GestureDetector`/`InkWell` tap targets

`IconButton(`-only checking has a blind spot: a developer who reaches for
a raw `GestureDetector(`/`InkWell(` around a bare icon (rather than
`IconButton`/`AppIconButton`) produces a tap target with **zero**
accessibility check coverage — `flutter analyze` doesn't flag it either,
since it's a semantic gap, not a type error. 22 files in the app use raw
`GestureDetector`/`InkWell` outside `design_system/`; each was checked
individually (not just pattern-matched) for whether its subtree contains
an icon with no accompanying text and no `Semantics` anywhere in its
ancestry. **Two real, confirmed violations found and fixed:**

| File | What it was | Fix |
|---|---|---|
| `features/profile/presentation/widgets/user_info_card.dart` | The small camera-icon "edit profile picture" badge overlaid on the avatar was a bare `GestureDetector(onTap: onEditPressed, child: ... Icon(AppIcons.camera) ...)` with no `Semantics` anywhere — a screen reader announced nothing for it at all. | Wrapped in `Semantics(button: true, label: l10n.changeAvatar, child: ...)`. The `changeAvatar` l10n key already existed (used elsewhere), so no new translation was needed. |
| `features/profile/presentation/widgets/edit_profile_bottom_sheet.dart` | Identical pattern — the avatar-with-camera-badge in the edit-profile bottom sheet, same bare `GestureDetector`, same silent-to-a-screen-reader problem. | Same fix, same `l10n.changeAvatar` key. |

A third finding was **not** a `GestureDetector`/icon issue but the same
underlying class of bug — a missing accessible label reachable only by
tracing an optional constructor parameter through its call sites, which no
static check (including the new one below) can catch, because the
component's own contract is correct:

| File | What it was | Fix |
|---|---|---|
| `features/todo/presentation/widgets/components/todo_checkbox.dart` (component itself) | Already correctly built — `Semantics(button: true, checked: value, label: label, child: ...)` with a nullable `label` parameter, clearly intended to be supplied by the caller. | No change needed here — the component is right. |
| `features/todo/presentation/widgets/variants/todo_preview_tile.dart` and `.../todo_list_tile.dart` (both call sites) | **Both** of the only two places `TodoCheckbox` is used in the app omitted `label:` entirely. A screen reader landing on either todo's checkbox announced only "button, checked" / "button, not checked" — no indication of *which* task. | Added `label: item.title` / `label: todo.title` at each call site. |

This second case is worth calling out explicitly: `TodoCheckbox`'s own
code is a textbook-correct accessibility contract (matches the roadmap's
"Input... label, ... required state" pattern for components exactly), but
correct component design didn't stop **every single call site** from
skipping the parameter that makes it work. A `required` parameter (as
`AppIconButton.semanticLabel` uses) would have made this impossible at
compile time; a nullable one didn't. This is worth remembering next time a
new accessible component is designed with an optional label — see §4.

## 2. The new guard: how it avoids the false-positive trap found in earlier passes

A naive version of this check ("any `GestureDetector`/`InkWell` near an
`Icon` with no `Semantics` within N lines") would have produced a false
positive on exactly the kind of case that should be praised, not flagged:
`features/courses/presentation/widgets/bookmark_button.dart` wraps its
`InkWell` in a correct, deliberate `Semantics(label: ..., button: true,
...)` — but the ancestor `Semantics(` is **26 lines above** the `InkWell`
it covers, well outside any reasonable fixed line-distance window, because
of several intervening layout widgets (`ScaleTransition` → `SizedBox` →
`ClipOval` → `BackdropFilter` → `Material`).

Instead of a line-distance heuristic, the new check builds a full
open-paren → close-paren index for the entire file (a standard bracket
matcher, O(n) single pass) and asks a structural question: does the
`GestureDetector`/`InkWell`'s own opening paren fall *between* some
`Semantics(`'s opening and closing paren, however far apart they are in
the file? Verified against three synthetic cases before trusting it
against the real 22-file set: a true positive (bare icon, no Semantics
anywhere), a true negative (icon + adjacent `Text`, no Semantics needed),
and — the case that specifically mirrors `bookmark_button.dart` — a true
negative where the ancestor `Semantics` is many lines and several widgets
away. All three were classified correctly before the check was run against
the real codebase and trusted.

## 3. Result

`python3 tool/check_a11y.py` before this pass: 1 check (IconButton
tooltip), 0 violations (already clean). After: 2 checks, **2 real
violations found and fixed** (the two `GestureDetector`-around-a-camera-icon
cases), plus 2 more real violations found and fixed by manual tracing that
no static check — old or new — could have caught (the `TodoCheckbox`
missing-label call sites, §1.2).

All 9 guards (`check_a11y`, `check_architecture --strict`,
`check_provider_cycles`, `check_rtl`, `check_design_tokens`,
`check_performance`, `check_memory_hygiene`, `check_localizations`,
`check_auth_security --strict`) pass via `python3 tool/check_all.py`.

## 4. What was checked but is not yet a guard, or not fixed (real gaps, left open)

- **No widget test in the entire suite exercises `MediaQuery.textScaler`.**
  Checked all 172 files under `test/` for `textScaler`/`textScaleFactor` —
  zero matches. This is precisely the gap the project's own instructions
  call out by name ("Do not limit accessibility checks to
  `IconButton.tooltip`... Test with realistic `MediaQuery.textScaler`
  values"). **Deliberately not fixed in this pass**: writing new widget
  tests without any way to run `flutter test` in this environment means
  they could contain a typo, a bad import, or an incorrect widget-finder
  and I would have no way to know before handing them over — that would be
  exactly the "no fake completion" failure mode the project instructions
  warn against, just moved from a false claim into an unverified test file
  instead. The concrete next step: pick 3–5 critical screens (course card,
  todo list, video player controls are the highest-icon-density places
  found in this audit) and add a `testWidgets` case per screen that pumps
  the widget under `MediaQuery(data: MediaQuery.of(context).copyWith(
  textScaler: TextScaler.linear(2.0)), child: ...)` and asserts no
  overflow — in an environment where `flutter test` can actually confirm
  it passes.
- **`TodoCheckbox`'s `label` parameter is optional, not required**,
  which is exactly how both real call sites managed to skip it (§1.2). Not
  changed to `required String label` in this pass — making it required is
  itself a larger, riskier diff (Dart would refuse to compile any *other*
  caller of `TodoCheckbox` that doesn't already pass one, and this repo's
  toolchain isn't available here to find every such caller with certainty
  beyond the two already grepped and fixed). Flagged here as the
  recommended follow-up rather than done blind.
- **Minimum 48×48dp tap-target size** (mentioned in the roadmap's Button
  accessibility contract) was not checked. This needs either rendered
  layout measurement (not available without a device/emulator) or a
  static heuristic looking for tap targets wrapped in an explicit
  `SizedBox`/`Container` with `width`/`height` below 48 — not attempted in
  this pass; no evidence was gathered on whether this is even a real
  problem in the app today, and guessing at a check without that evidence
  risks the same false-positive trap `check_design_tokens.py`'s first
  `Duration` attempt fell into.
- **Focus order / keyboard traversal** (`FocusTraversalGroup`,
  `Shortcuts`, `Actions` — roadmap Phase J) not audited; this app is
  primarily touch-first, and no evidence was gathered on whether
  tablet/desktop/web targets are close enough on the roadmap to prioritize
  this now.
- **RTL** (roadmap Phase K) already has its own dedicated, actively
  maintained guard (`tool/check_rtl.py`) — checked its current scope
  (physical `EdgeInsets.only(left/right)`, `Alignment.centerLeft/Right`,
  `Positioned(left/right)`, `TextAlign.left/right`) and it already covers
  the concrete cases the roadmap names. No gap found; out of scope for
  further work in this specific pass.

## 5. Verification gap

Static Python inspection and manual code tracing only — no Flutter SDK,
Dart SDK, emulator, or screen reader available. Not run, therefore **not
verified**:

- `flutter analyze` (would catch a bracket-balance mistake in the two
  hand-edited files if one had been made; each was instead verified with a
  standalone Python paren/brace-depth counter confirming balance, since
  that's what was available)
- `flutter test` — none of the existing 172 tests were re-run to confirm
  the two edited widget files still build/render correctly
  (`user_info_card.dart`, `edit_profile_bottom_sheet.dart`)
- Actual screen-reader behavior (TalkBack/VoiceOver) confirming the new
  `Semantics(label: l10n.changeAvatar, ...)` announces as intended
- Whether `l10n.changeAvatar` ("Change Photo" / "تغيير الصورة") reads
  naturally in context for both of the newly-labeled buttons, versus a
  more specific string — it was the closest existing key rather than a
  purpose-written one; a native speaker/UX review is the right next check

To close this gap:

```bash
flutter pub get
flutter analyze
python3 tool/check_all.py
flutter test --coverage
```

and open a PR against `main` to let the real CI workflow run end to end,
plus a manual TalkBack/VoiceOver pass on the two changed screens.
