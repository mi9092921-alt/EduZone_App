# AGENTS.md — EduZone Student App

This file is read by Code AGENT at the start of every session.
Follow every instruction here precisely. When in doubt, ask before assuming.

---

## Project Identity

**EduZone Student App** — Flutter mobile client for students.
Part of a multi-tenant e-learning platform (EduZone) with three separate apps:
Admin Dashboard (Next.js), Teacher App (Flutter), and this Student App (Flutter).

This app is **students-only**. It never exposes admin or teacher data.
Every data access is enforced by Supabase RLS — never bypass or work around it.

---

## Essential Commands

```bash
# Install dependencies
flutter pub get

# Generate code (Riverpod, freezed, json_serializable)
dart run build_runner build --delete-conflicting-outputs

# Run the app (development)
flutter run --dart-define-from-file=.env

# Lint — must be zero warnings before committing
flutter analyze

# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Build APK (release check)
flutter build apk --release --dart-define-from-file=.env --target-platform android-arm64

# Build App Bundle (production)
flutter build appbundle --release --dart-define-from-file=.env.prod
```

Run `flutter analyze` and `flutter test` after every non-trivial change.
Never commit code that fails either command.

---

## Architecture — Read This First

The app follows **Clean Architecture** with Feature Slices, three layers:

```
core/       ← Layer 1: infrastructure, theme, navigation, services, utils
shared/     ← Layer 2: reusable widgets and shared data models
features/   ← Layer 3: isolated feature slices (auth, downloads, home, courses, notifications, warnings, profile, todo, video_player)
```

### Import Rules — Hard Constraints

```
core/     → imports nothing from shared/ or features/
shared/   → imports from core/ only
features/ → imports from core/ and shared/ freely
features/ → may import from features/auth/ (providers only, for auth state)
features/ → MUST NOT import from other features/
```

Violating these rules breaks the architecture. If a feature needs data from another feature, route it through a shared model in `shared/models/` or a provider in `core/`.

### Feature Slice Structure

Every feature follows this exact layout:

```
features/<name>/
├── data/
│   ├── datasources/               ← All Supabase calls live here
│   └── repositories/              ← Repository implementations
├── domain/
│   ├── entities/                  ← Freezed models
│   └── repositories/              ← Repository interfaces
├── application/
│   └── providers/                 ← Riverpod providers
│       └── <name>_provider.dart
└── presentation/
    ├── <name>_screen.dart
    └── widgets/                   ← Feature-specific widgets only
```

Screens only call providers. Providers call repositories. Repositories call Supabase.
Never put Supabase calls directly in a widget or provider.

---

## State Management — Riverpod

The app uses **Flutter Riverpod 3.x with codegen** (`flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`) exclusively. Do not introduce any other state solution.

- Use `AsyncNotifierProvider` for data that loads asynchronously
- Use `NotifierProvider` for synchronous state
- Use `ref.watch()` in build methods, `ref.read()` in callbacks and handlers
- Providers are defined under each feature's `application/providers/` files — never inside widgets
- Invalidate providers with `ref.invalidate()` when data must be refreshed (e.g. after a user action)

```dart
// ✅ Correct provider pattern
@riverpod
class CoursesNotifier extends _$CoursesNotifier {
  @override
  Future<List<Course>> build() async {
    return ref.read(coursesRepositoryProvider).getEnrolledCourses();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(coursesRepositoryProvider).getEnrolledCourses(),
    );
  }
}
```

---

## Navigation — go_router

All routes are defined in `lib/app/router/app_router.dart` (route name constants in `lib/core/constants/app_constants.dart` `AppRoutes`). Do not define routes elsewhere.

Route hierarchy:

```
/                  → session check, redirects to /login or /home
/login
/legal/:type
/locked            → security kill-switch screen
/app-locked        → no sign-out, shows custom message
/suspended
/banned
/maintenance       → no sign-out, shows ends_at
/force-update      → blocks all until update

StatefulShellRoute (bottom-nav shell):
  /home            → children: notifications
  /discover        → children: saved, course-preview/:courseId
  /courses         → children: downloads (→ offline-player/:downloadId),
                     :courseId (→ lesson/:lessonId, lesson3/:lessonId, lesson4/:lessonId)
  /todo
  /profile
```

Use `context.go()` for top-level navigation and `context.push()` for drill-down.
Never use `Navigator.push()` directly.

---

## Supabase — Critical Rules

### Authentication

Every app open must call `check_student_app_access()` before showing any content:

```dart
final access = await supabase.rpc('check_student_app_access');
if (access['allowed'] == false) {
  // Handle based on access['reason']
}
```

After every login, call `bind_device_for_current_user`:

```dart
await supabase.rpc('bind_device_for_current_user', params: {
  'p_device_id': await DeviceInfo.getDeviceId(),
  'p_platform': Platform.isAndroid ? 'android' : 'ios',
});
```

### Token Handling

### Token Handling

- **The JWT/session token is persisted ONLY through the app's custom `SecureLocalStorage`**
  (`lib/core/network/supabase_client.dart`) backed by `flutter_secure_storage` with
  hardware-backed Android Keystore / iOS Keychain (`first_unlock_this_device`). This is the
  one audited deviation from the earlier "memory only" policy — session restore and the
  offline `AuthDegraded` flow depend on it. It is wiped on logout by `LogoutOrchestrator`.
  Never write tokens to `SharedPreferences`, plain files, or any storage other than that
  implementation.
- `token_version` mismatches must trigger immediate sign-out. Catch `ACCOUNT_LOCKED` / `TOKEN_VERSION_MISMATCH` errors from every RPC call.
- Never use the `service_role` key anywhere in this app. All sensitive operations go through Edge Functions.
- The `anon` key is the only Supabase key that belongs in this app.

### Forced Sign-Out Scenarios

| Reason | Behavior |
|---|---|
| `account_locked` | Sign out → `/login` with error message |
| `account_banned` | Sign out → `/login` with error message |
| `account_suspended` | Sign out → `/login`, show `suspension_until` |
| `maintenance_mode` | **No sign-out** → `/maintenance` with `ends_at` |
| `app_locked` | **No sign-out** → `/app-locked` with custom message |
| `JWT expired` | Silent refresh → if failed: sign out |
| `MAX_DEVICES_REACHED` | Show error, do not sign out |

### Data Access

- Never call Supabase `.from()` directly in a widget or provider — only in repository classes
- All queries are automatically filtered by RLS. Do not add manual `userId` filters on top of RLS; trust the policy
- Use `.rpc()` for complex queries; keep raw `.from().select()` calls for simple reads
- Always handle `PostgrestException` in repositories and convert to domain exceptions

---

## Design System — Hard Rules

All UI values come from the design system. Using raw values is forbidden.

```dart
// ❌ NEVER
Color(0xFF1B4F8A)
SizedBox(height: 16)
TextStyle(fontSize: 14, fontWeight: FontWeight.w600)
BorderRadius.circular(8)

// ✅ ALWAYS
AppColors.primary700
SizedBox(height: AppSpacing.lg)
AppTextStyles.bodyMedium
AppRadius.md
```

### Token Files

| File | What It Defines |
|---|---|
| `design_system/tokens/app_colors.dart` | All color constants |
| `design_system/tokens/app_text_styles.dart` | All `TextStyle` values |
| `design_system/tokens/app_spacing.dart` | `xs`, `sm`, `md`, `lg`, `xl`, `2xl`... |
| `design_system/tokens/app_radius.dart` | `sm`, `md`, `lg`, `full` |
| `design_system/tokens/app_elevation.dart` | Shadow levels |
| `design_system/tokens/app_motion.dart` | Animation durations & curves |

The design system lives in `lib/design_system/` (components/, tokens/, rules/, `design_system.dart` barrel). Import it via `package:app/design_system/design_system.dart`.

### Widget Rules

- Use `AppButton`, `AppCard`, `AppTextField` from `shared/widgets/` — never raw `ElevatedButton`, `Card`, `TextField`
- Empty states → `EmptyState` widget. Error states → `ErrorState` widget with a retry callback
- Loading states → skeletonizer via `AppLoading`, never `CircularProgressIndicator` in page-level loads
- Dialogs → `ConfirmDialog` for destructive actions

---

## Internationalization (i18n)

The app supports Arabic (`ar-EG`, RTL) and English (`en-US`, LTR).

- All user-facing strings go in `lib/core/l10n/arb/app_ar.arb` and `lib/core/l10n/arb/app_en.arb` (both files must keep identical key sets — 370 keys as of the last audit)
- Never hardcode a user-visible string in Dart. Use `context.l10n.someKey`
- After adding a key to both ARB files, run `flutter gen-l10n` (or `flutter pub get` triggers it via `l10n.yaml`)
- Test every new screen in both locales. RTL layout must be verified manually

```dart
// ✅ Correct
Text(context.l10n.myCourses)

// ❌ Wrong
Text('My Courses')
Text('كورساتي')
```

---

## Responsiveness

Use `AdaptiveLayout` from `core/layout/adaptive_layout.dart` for layout differences across breakpoints.

```dart
// Breakpoints defined in core/layout/breakpoints.dart
// mobile  < 600px
// tablet  600–1200px
// desktop ≥ 1200px
```

All layouts must work at all three breakpoints. Test on a tablet emulator before submitting UI changes.

---

## Testing Requirements

| Scope | Coverage Target | Tool |
|---|---|---|
| Repositories | ≥ 90% | flutter_test + mocktail |
| Providers | ≥ 85% | flutter_test |
| Shared widgets | ≥ 80% | flutter_test |
| Integration flows | 5 critical flows | integration_test |

- Mock Supabase with `MockSupabaseClient extends Mock implements SupabaseClient`
- Never make real network calls in unit or widget tests
- One test file per source file, mirroring the `lib/` structure under `test/`
- New code submitted without tests will be rejected in PR review

### Standard Test Structure

```dart
void main() {
  late MyRepository repository;
  late MockSupabaseClient mockClient;

  setUp(() {
    mockClient = MockSupabaseClient();
    repository = MyRepository(client: mockClient);
  });

  group('MyRepository', () {
    test('description of expected behavior', () async {
      // Arrange
      when(() => mockClient.rpc('some_rpc')).thenAnswer((_) async => mockData);
      // Act
      final result = await repository.someMethod();
      // Assert
      expect(result, expectedValue);
    });
  });
}
```

---

## Code Style

Follow the rules in `analysis_options.yaml`. Zero tolerance for warnings.

- File names: `snake_case.dart`
- Class names: `PascalCase`
- Private members: `_camelCase`
- Constants: `camelCase` (Dart convention, not `SCREAMING_SNAKE_CASE`)
- Max line length: 100 characters
- Always add trailing commas on multi-line parameter lists (enables `dart format` to format correctly)
- No `print()` in production code — use a proper logger or remove debug output before committing

### Async

- Always `await` futures; never fire-and-forget unless intentional (document why)
- Wrap repository calls in `try/catch` and convert `PostgrestException` to domain exceptions
- Use `AsyncValue.guard()` in Riverpod notifiers

---

## What NOT to Do

These are common mistakes that will be caught in review:

```
❌ Import one feature from another feature (except auth providers)
❌ Put Supabase calls in widgets or providers directly
❌ Hardcode colors, spacing, font sizes, or border radii
❌ Hardcode user-facing strings (use l10n)
❌ Store JWT on disk in any form
❌ Use service_role key anywhere in the app
❌ Call Navigator.push() — use go_router
❌ Add state management other than Riverpod
❌ Skip tests for new repository or provider code
❌ Use CircularProgressIndicator for full-page loading states
❌ Use print() for debugging in committed code
❌ Bypass RLS with manual userId filters
```

---

## Environment

The app is configured via `--dart-define-from-file`:

```
.env                  ← development (not committed)
.env.prod             ← production (not committed)
.env.security         ← RASP/security flags (not committed)
.env.example          ← committed, template only
.env.security.example ← committed, template only
```

Read env values via:

```dart
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
```

Never read from `.env` files at runtime. Never use `dotenv` packages.

---

## Commit Convention

```
feat(scope):     New feature
fix(scope):      Bug fix
refactor(scope): Refactor without behavior change
test(scope):     Add or fix tests
docs(scope):     Documentation only
style(scope):    Formatting, no logic change
perf(scope):     Performance improvement
chore(scope):    Deps, build, tooling
```

Valid scopes: `auth`, `home`, `courses`, `notifications`, `warnings`, `profile`, `core`, `shared`, `theme`, `nav`, `deps`

Example: `feat(courses): add lesson completion badge with animation`

---

## Key Reference Files

| File | What to find there |
|---|---|
| `lib/app/router/app_router.dart` | All route definitions (+ `lib/core/constants/app_constants.dart` `AppRoutes`) |
| `design_system/tokens/app_colors.dart` | Color tokens |
| `core/network/supabase_client.dart` | Supabase singleton + cert pinning wiring + secure session storage |
| `features/auth/data/datasources/auth_remote_ds.dart` | Login, sign-out, device binding, token_version handling |
| `features/auth/application/providers/auth_provider.dart` | Auth state machine, forced sign-out scenarios |
| `docs/EduZone_App_Design_System_v1.md` | Full design system reference |
| `docs/EduZone_API_Design_v1.md` | All RPC and Edge Function contracts |
| `docs/SECURITY_DESIGN.md` | Auth flows and security model |
| `RFC_DECISION_LOG.md` | Architectural decisions and their rationale |

### Shared Supabase Schema

The nested `supabase/` tree in this repo is a **synced mirror** of the canonical schema
owned by the `EduZone_dashboard` repository (`supabase/schema/` + `config.toml`).
Never edit the schema here and expect it to reach production — the dashboard repo is the
source of truth and deployment (`supabase/deploy.js`) runs from there.
