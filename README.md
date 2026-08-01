<div align="center">

<img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
<img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
<img src="https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" />
<img src="https://img.shields.io/badge/Material_3-Design-6750A4?style=for-the-badge&logo=material-design&logoColor=white" />
<img src="https://img.shields.io/badge/RTL-Arabic_First-CC0000?style=for-the-badge" />

<br /><br />

```
 ███████╗██████╗ ██╗   ██╗███████╗ ██████╗ ███╗   ██╗███████╗
 ██╔════╝██╔══██╗██║   ██║╚══███╔╝██╔═══██╗████╗  ██║██╔════╝
 █████╗  ██║  ██║██║   ██║  ███╔╝ ██║   ██║██╔██╗ ██║█████╗
 ██╔══╝  ██║  ██║██║   ██║ ███╔╝  ██║   ██║██║╚██╗██║██╔══╝
 ███████╗██████╔╝╚██████╔╝███████╗╚██████╔╝██║ ╚████║███████╗
 ╚══════╝╚═════╝  ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝
```

### **app**
*Student App — Multi-Tenant E-Learning Platform*

**Flutter · Dart 3 · Supabase · Material Design 3 · RTL**

[Features](#-features) · [Quick Start](#-quick-start) · [Architecture](#-architecture) · [Documentation](#-documentation) · [Contributing](#-contributing)

</div>

---

## 📋 Overview

**EduZone Student App** is the official mobile client for students on the EduZone e-learning platform. It allows students to access their enrolled courses, track progress, watch lessons, and receive notifications — all within a professional Arabic/English interface with full light and dark mode support.

The platform is built on **Supabase** with Row Level Security (RLS) policies and runs **JWT + token_version** validation on every request, ensuring complete data isolation for each tenant.

```
┌─────────────────────────────────────────────────────────────┐
│                  EduZone Platform                           │
│                                                             │
│   [ Admin Dashboard ]    [ Teacher App ]   [ Student App ] │
│      Next.js 15              Flutter           Flutter      │
│                                                 ← You are here │
│                    ↕ Supabase Backend ↕                     │
│         PostgreSQL 16 · RLS · Edge Functions               │
└─────────────────────────────────────────────────────────────┘
```

### Target Persona

> **The Student** — a user enrolled in one or more courses within a tenant (school / university / institution). Holds the `student` role and can only see data within the scope of their active subscriptions.

---

## ✨ Features

### 🔐 Authentication & Security
- Email and password sign-in via Supabase Auth
- Immediate session expiry detection with redirect to login screen
- Full `token_version` handling — forces sign-out when account is deactivated by admin
- Session persisted securely via `flutter_secure_storage` (hardware-backed Android Keystore / iOS Keychain) — no tokens in `SharedPreferences`
- Automatic device binding via `bind_device_for_current_user` after login
- Maintenance screen displayed when `maintenance_mode` is active, without signing the user out

### 📚 Courses & Lessons
- Display only enrolled courses (RLS-enforced)
- Show published sections and lessons within active courses
- Watch lessons via integrated YouTube Player
- Automatically track and save watch time in `video_views`
- Show progress percentage per course and per lesson
- Support for both free and paid courses

### 📊 Progress & Statistics
- Overall course completion percentage (`progress_pct`)
- Last watched lesson (`last_watched`)
- "Completed" badge when 100% is reached
- Course list filtered by status: active / expired / completed

### 🔔 Notifications
- Receive platform notifications via Supabase Realtime
- Personal inbox (`user_notifications`)
- Unread notification badge with counter
- Mark individual or all notifications as read

### ⚠️ Warnings
- Display warnings issued by admins or teachers
- Severity levels: low / medium / high
- Automatic alert when a temporary suspension is approaching

### 📱 User Experience
- Full bilingual support: Arabic (RTL) and English (LTR)
- Light and dark mode with instant switching
- Responsive design: mobile · tablet · desktop
- Loading states with Skeleton Shimmer
- Professional empty and error states with a "Retry" button
- Smooth animations and page transitions with Material 3

---

## 🛠 Tech Stack

| Layer | Technology | Version (pubspec) | Purpose |
|---|---|---|---|
| **Framework** | Flutter | 3.x | Core framework |
| **Language** | Dart | ^3.11.1 | Programming language |
| **Design** | Material Design 3 | — | Design system |
| **Backend** | Supabase | `supabase_flutter` ^2.6.0 | DB · Auth · Realtime · Storage |
| **Push notifications** | Firebase (`firebase_core`, `firebase_messaging`) | ^4.6.0 / ^16.1.3 | Push notifications |
| **State** | flutter_riverpod + riverpod_annotation | ^3.3.1 / ^4.0.2 | State management (codegen) |
| **Navigation** | go_router | ^17.2.0 | Routing and navigation |
| **Video** | youtube_player_flutter, media_kit | ^9.0.1 / ^1.2.6 | Lesson playback |
| **Session storage** | flutter_secure_storage | ^10.0.0 | Hardware-backed session/token storage |
| **App integrity** | freerasp, screen_protector | ^8.0.0 / ^1.5.2 | Root/jailbreak detection, screenshot guard |
| **Offline video encryption** | encrypt, crypto | ^5.0.3 / ^3.0.5 | AES-256-GCM encrypted downloads |
| **Fonts** | google_fonts | ^8.0.2 | Typography (not local — fetched/cached at runtime) |
| **Images** | cached_network_image | ^3.4.1 | Image caching |
| **i18n** | flutter_localizations + `flutter gen-l10n` | SDK | Localization & translation |
| **HTTP** | dio | ^5.9.2 | Networking (alongside `supabase_flutter`) |
| **Testing** | flutter_test · mocktail | SDK · ^1.0.5 | Tests |

> This table is generated from `pubspec.yaml` directly — if you add/remove a package, update this table in the same PR so it doesn't drift again.

---

## 🏗 Architecture

The app follows **Clean Architecture** with Feature Slices, inspired by the same architectural decisions documented in `RFC_DECISION_LOG.md` for the EduZone platform.

```
lib/
├── core/                          ← Layer 1: DOMAIN & INFRA CORE
│   ├── theme/
│   │   ├── app_colors.dart        ← Design Tokens (Colors)
│   │   ├── app_text_styles.dart   ← Typography System
│   │   ├── app_spacing.dart       ← Spacing (8dp grid)
│   │   ├── app_radius.dart        ← Border Radius
│   │   ├── app_elevation.dart     ← Elevation & Shadows
│   │   ├── app_duration.dart      ← Motion Tokens
│   │   └── app_theme.dart         ← ThemeData (Light + Dark)
│   ├── layout/
│   │   ├── breakpoints.dart       ← Responsive Breakpoints
│   │   └── adaptive_layout.dart   ← AdaptiveLayout Widget
│   ├── navigation/
│   │   ├── app_router.dart        ← go_router config
│   │   └── app_page_transition.dart
│   ├── services/
│   │   ├── supabase_service.dart  ← Singleton Supabase Client
│   │   ├── auth_service.dart      ← Auth operations
│   │   └── storage_service.dart   ← Secure storage helpers
│   └── utils/
│       ├── number_formatter.dart  ← Arabic/Western numerals
│       ├── date_formatter.dart    ← Locale-aware dates
│       └── extensions/            ← Dart extensions
│
├── shared/                        ← Layer 2: SHARED WIDGETS
│   ├── widgets/
│   │   ├── app_button.dart
│   │   ├── app_card.dart
│   │   ├── app_text_field.dart
│   │   ├── status_chip.dart
│   │   ├── confirm_dialog.dart
│   │   ├── empty_state.dart
│   │   ├── error_state.dart
│   │   ├── app_loading.dart       ← skeletonizer
│   │   └── app_bottom_nav.dart
│   └── models/
│       ├── user.dart
│       ├── course.dart
│       ├── enrollment.dart
│       ├── lesson.dart
│       └── notification.dart
│
├── features/                      ← Layer 3: FEATURE SLICES
│   │                               (each feature is isolated — no cross-imports)
│   ├── auth/
│   │   ├── data/
│   │   │   └── auth_repository.dart
│   │   ├── presentation/
│   │   │   ├── login_screen.dart
│   │   │   ├── forgot_password_screen.dart
│   │   │   └── widgets/
│   │   └── providers/
│   │       └── auth_provider.dart
│   │
│   ├── home/
│   │   ├── presentation/
│   │   │   ├── home_screen.dart
│   │   │   └── widgets/
│   │   │       ├── enrolled_courses_section.dart
│   │   │       ├── continue_watching_card.dart
│   │   │       └── stats_row.dart
│   │   └── providers/
│   │
│   ├── courses/
│   │   ├── data/
│   │   │   └── courses_repository.dart
│   │   ├── presentation/
│   │   │   ├── courses_screen.dart       ← Course list
│   │   │   ├── course_detail_screen.dart ← Course details
│   │   │   ├── lesson_screen.dart        ← Watch lesson
│   │   │   └── widgets/
│   │   │       ├── course_card.dart
│   │   │       ├── section_tile.dart
│   │   │       ├── lesson_tile.dart
│   │   │       └── progress_bar.dart
│   │   └── providers/
│   │       ├── courses_provider.dart
│   │       └── video_progress_provider.dart
│   │
│   ├── notifications/
│   │   ├── data/
│   │   │   └── notifications_repository.dart
│   │   ├── presentation/
│   │   │   ├── notifications_screen.dart
│   │   │   └── widgets/
│   │   │       └── notification_tile.dart
│   │   └── providers/
│   │       └── notifications_provider.dart
│   │
│   ├── warnings/
│   │   ├── data/
│   │   │   └── warnings_repository.dart
│   │   ├── presentation/
│   │   │   ├── warnings_screen.dart
│   │   │   └── widgets/
│   │   │       └── warning_tile.dart
│   │   └── providers/
│   │
│   └── profile/
│       ├── data/
│       │   └── profile_repository.dart
│       ├── presentation/
│       │   ├── profile_screen.dart
│       │   └── widgets/
│       │       ├── session_tile.dart
│       │       └── device_tile.dart
│       └── providers/
│           └── profile_provider.dart
│
└── main.dart                      ← Entry point + ProviderScope
```

### Feature Isolation Principle

```
✅ features/courses/ imports from core/ and shared/
✅ features/courses/ imports from features/auth/ (providers only)
❌ features/courses/ must NOT import from features/notifications/
❌ features/notifications/ must NOT import from features/courses/
```

---

## 🔄 Data Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter App                             │
│                                                             │
│  Screen → ref.watch(provider) → Repository                 │
│                                        │                   │
│                              supabase_flutter SDK          │
│                                        │                   │
│                             Supabase Client (anon key)     │
└────────────────────────────────────────┼────────────────────┘
                                         │ HTTPS + JWT
                                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   Supabase Backend                          │
│                                                             │
│   .rpc('check_user_access')  ←──── Every app open          │
│   .rpc('bind_device_...')    ←──── After login             │
│   .from('courses').select()  ←──── RLS: enrolled only      │
│   .from('user_progress')...  ←──── RLS: own records only   │
│   Realtime: user_notifications ←── Push events            │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites

| Tool | Minimum Version | Check |
|---|---|---|
| Flutter SDK | 3.22.0+ | `flutter --version` |
| Dart SDK | 3.4.0+ | `dart --version` |
| Android Studio / Xcode | Latest | — |
| Git | 2.x+ | `git --version` |
| Supabase CLI | 1.150+ | `supabase --version` |

### 1. Clone the Repository

```bash
git clone https://github.com/mi9092921-alt/EduZone_App.git
cd EduZone_App
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Environment Variables

Copy the environment template and fill in your values:

```bash
cp .env.example .env.local
```

```env
# .env.local
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here

# Environment: development | staging | production
APP_ENV=development

# Feature Flags (optional for local environment)
ENABLE_DARK_MODE=true
ENABLE_PUSH_NOTIFICATIONS=true
```

> **⚠️ Security Warning:** Never commit `.env.local` to Git. The file is listed in `.gitignore`.

### 4. Generate Build Runner Code

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 5. Run the App

```bash
# Android (emulator or physical device)
flutter run -d android

# iOS (requires macOS + Xcode)
flutter run -d ios

# Run with a specific environment
flutter run --dart-define-from-file=.env.local

# Run in Release mode for testing
flutter run --release --dart-define-from-file=.env.local
```

---

## ⚙️ Environment Variables

| Variable | Required | Accepted Values | Description |
|---|---|---|---|
| `SUPABASE_URL` | ✅ | URL | Supabase project URL |
| `SUPABASE_ANON_KEY` | ✅ | JWT | Supabase public (anon) key |
| `APP_ENV` | ✅ | `development` · `staging` · `production` | Runtime environment |
| `ENABLE_DARK_MODE` | — | `true` · `false` | Enable Dark Mode (default: true) |
| `ENABLE_PUSH_NOTIFICATIONS` | — | `true` · `false` | Push notifications |
| `SENTRY_DSN` | — | DSN URL | Error tracking in production |

> **Note:** The `service_role` key is **never** used in the app. All sensitive operations are routed through Supabase Edge Functions on the server side.

---

## 📱 Building the App

### Android

```bash
# APK for testing
flutter build apk --release \
  --dart-define-from-file=.env.local \
  --target-platform android-arm64

# App Bundle for Google Play
flutter build appbundle --release \
  --dart-define-from-file=.env.production

# Analyze bundle size
flutter build apk --analyze-size
```

### iOS

```bash
# Archive for App Store (requires macOS)
flutter build ipa --release \
  --dart-define-from-file=.env.production

# Export IPA
flutter build ipa --export-options-plist=ios/ExportOptions.plist
```

### Signing Requirements

```
Android:
  └── android/key.properties  ← (not committed to Git)
       storePassword=...
       keyPassword=...
       keyAlias=...
       storeFile=../keystore.jks

iOS:
  └── Certificates & Provisioning Profiles
      Managed via Xcode Signing Settings
```

---

## 🧪 Testing

### Run All Tests

```bash
flutter test
```

### Run with Code Coverage

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Test Structure

```
test/
├── unit/
│   ├── auth/
│   │   └── auth_repository_test.dart
│   ├── courses/
│   │   ├── courses_repository_test.dart
│   │   └── video_progress_provider_test.dart
│   └── notifications/
│       └── notifications_repository_test.dart
│
├── widget/
│   ├── shared/
│   │   ├── app_button_test.dart
│   │   ├── status_chip_test.dart
│   │   └── empty_state_test.dart
│   └── features/
│       ├── course_card_test.dart
│       └── lesson_tile_test.dart
│
└── integration/
    ├── auth_flow_test.dart     ← Login → Home
    ├── course_flow_test.dart   ← Browse → Watch
    └── notification_test.dart  ← Receive → Read
```

### Coverage Targets

| Layer | Target | Tooling |
|---|---|---|
| Repositories | ≥ 90% | flutter_test + mocktail |
| Providers | ≥ 85% | flutter_test |
| Widgets (shared) | ≥ 80% | flutter_test |
| Integration flows | 5 critical flows | integration_test |

### Standard Test Pattern

```dart
// test/unit/courses/courses_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late CoursesRepository repository;
  late MockSupabaseClient mockClient;

  setUp(() {
    mockClient = MockSupabaseClient();
    repository = CoursesRepository(client: mockClient);
  });

  group('CoursesRepository', () {
    test('getEnrolledCourses returns only active enrollments', () async {
      // Arrange
      when(() => mockClient.rpc('get_enrolled_courses'))
          .thenAnswer((_) async => mockCoursesResponse);

      // Act
      final result = await repository.getEnrolledCourses();

      // Assert
      expect(result, isA<List<Course>>());
      expect(result.every((c) => c.enrollmentStatus == 'active'), isTrue);
    });

    test('throws AuthException when token_version mismatch', () async {
      when(() => mockClient.rpc(any()))
          .thenThrow(PostgrestException(message: 'ACCOUNT_LOCKED'));

      expect(
        () => repository.getEnrolledCourses(),
        throwsA(isA<TokenVersionMismatchException>()),
      );
    });
  });
}
```

---

## 🔐 Security & Authentication

### Zero-Trust Principles in the App

```
1. ✅ Every request carries a valid JWT — no unauthenticated requests
2. ✅ check_user_access() is called on every app open
3. ✅ token_version is checked — immediate sign-out if changed by admin
4. ✅ Session persisted via `flutter_secure_storage` (hardware-backed Keystore/Keychain) — no tokens in `SharedPreferences`
5. ✅ bind_device_for_current_user() after every login
6. ✅ No service_role key in the app under any circumstances
```

### Forced Sign-Out Scenarios

| Reason | App Behavior |
|---|---|
| `account_locked` | Immediate sign-out → Login screen + "Your account has been locked" message |
| `account_banned` | Immediate sign-out → Login screen + "Your account has been permanently banned" message |
| `account_suspended` | Immediate sign-out → Message including `suspension_until` |
| `maintenance_mode` | **No sign-out** → Maintenance screen with `ends_at` |
| `app_locked` | **No sign-out** → Lock screen with custom message |
| `JWT expired` | Silent refresh attempt → If failed: sign-out |
| `MAX_DEVICES_REACHED` | Error message → "You have exceeded the allowed number of devices" |

### Full Authentication Flow

```dart
// lib/features/auth/data/auth_repository.dart

Future<AuthResult> signIn({
  required String email,
  required String password,
}) async {
  // 1. Supabase Auth
  final response = await supabase.auth.signInWithPassword(
    email: email,
    password: password,
  );

  // 2. Validate account status immediately
  final access = await supabase.rpc('check_user_access');
  if (access['allowed'] == false) {
    await supabase.auth.signOut();
    return AuthResult.blocked(reason: access['reason']);
  }

  // 3. Bind device
  await supabase.rpc('bind_device_for_current_user', params: {
    'p_device_id': await DeviceInfo.getDeviceId(),
    'p_platform': Platform.isAndroid ? 'android' : 'ios',
  });

  return AuthResult.success(user: response.user!);
}
```

---

## 🌍 Internationalization (i18n)

### Supported Languages

| Language | Code | Direction | Status |
|---|---|---|---|
| Arabic | `ar-EG` | RTL ← | ✅ Complete |
| English | `en-US` | LTR → | ✅ Complete |

### Translation Structure

```
lib/
└── l10n/
    ├── app_ar.arb    ← Arabic translations
    └── app_en.arb    ← English translations
```

```json
// lib/l10n/app_en.arb
{
  "@@locale": "en",
  "appTitle": "EduZone",
  "welcomeBack": "Welcome back, {name}!",
  "@welcomeBack": {
    "placeholders": {
      "name": { "type": "String" }
    }
  },
  "myCourses": "My Courses",
  "continueWatching": "Continue Watching",
  "progress": "Progress",
  "completed": "Completed",
  "notifications": "Notifications",
  "noCoursesYet": "No courses yet",
  "errorLoadingCourses": "Failed to load courses",
  "retry": "Retry",
  "logout": "Log Out",
  "accountLocked": "Your account has been locked. Please contact support.",
  "sessionExpired": "Your session has expired. Please log in again.",
  "maintenanceMode": "The platform is under maintenance. We'll be back soon."
}
```

---

## 🎨 Design System

The app follows the **EduZone App Design System v1.0**, fully documented at:

```
docs/EduZone_App_Design_System_v1.md
```

### Primary Colors

```dart
AppColors.primary700   // #1B4F8A — Primary buttons
AppColors.neutral0     // #FFFFFF — Card surfaces
AppColors.neutral50    // #F1F5F9 — Page background
AppColors.success700   // #0E7C61 — Success / Active
AppColors.error700     // #B91C1C — Errors / Banned
AppColors.warning700   // #B7600A — Warnings
```

### Strict Rules

```dart
// ❌ Forbidden
Container(color: Color(0xFF1B4F8A))
SizedBox(height: 16)
TextStyle(fontSize: 14)

// ✅ Correct
Container(color: AppColors.primary700)
SizedBox(height: AppSpacing.lg)
AppTextStyles.bodyMedium
```

---

## 📂 Key Configuration Files

| File | Purpose |
|---|---|
| `pubspec.yaml` | Dependencies and assets |
| `analysis_options.yaml` | Dart linting rules |
| `l10n.yaml` | Translation configuration |
| `.env.example` | Environment variable template |
| `android/key.properties` | ⚠️ Not committed — signing config |
| `ios/ExportOptions.plist` | iOS export configuration |
| `flutter_native_splash.yaml` | Splash screen setup |
| `flutter_launcher_icons.yaml` | App icon configuration |

---

## 🔀 Navigation Flow

```
/                          ← splash (session check)
│
├── /auth
│   ├── /login             ← Sign in
│   └── /forgot-password   ← Password recovery
│
├── /maintenance           ← Maintenance screen (no sign-out)
├── /app-locked            ← App lock screen
├── /onboarding            ← Welcome screen
│
└── /home                  ← Shell (Bottom Navigation)
    ├── /courses            ← Course list
    │   └── /courses/:id    ← Course details
    │       └── /lesson/:id ← Watch lesson
    ├── /notifications      ← Notification inbox
    ├── /warnings           ← Warnings
    └── /profile            ← User profile
        ├── /sessions        ← Active sessions
        └── /devices         ← Linked devices
```

---

## 🤝 Contributing

### Before You Start

1. Read `docs/EduZone_App_Design_System_v1.md` before modifying any UI
2. Ensure you follow Clean Architecture — no cross-feature imports
3. Every PR must pass CI (tests + lint + analyze)

### Contribution Steps

```bash
# 1. Create a branch from main
git checkout -b feature/EZ-123-lesson-progress-tracking

# 2. Write code with tests
# 3. Verify locally
flutter analyze
flutter test
flutter build apk --release --dart-define-from-file=.env

# 4. Commit using Conventional Commits
git commit -m "feat(courses): track video progress with debounced save"

# 5. Open a Pull Request
```

### Accepted Commit Formats

```
feat(auth):        New authentication feature
fix(courses):      Bug fix in courses
refactor(core):    Refactoring without functional change
test(providers):   Add tests
docs(readme):      Update documentation
style(widgets):    Formatting without logic change
perf(video):       Performance improvement
chore(deps):       Dependency updates
```

### PR Acceptance Criteria

```
✅ flutter analyze — zero warnings
✅ flutter test    — all tests pass
✅ Code coverage ≥ 80% for new code
✅ No hardcoded colors or spacing
✅ No cross-feature imports
✅ RTL manually tested
✅ Dark Mode tested
✅ Reviewed by at least one developer
```

---

## 📋 Roadmap

### v1.0 — Initial Launch ✅
- [x] Full authentication with token_version
- [x] Course and lesson display
- [x] Integrated YouTube player
- [x] Progress tracking
- [x] Basic notifications
- [x] Arabic / English support
- [x] Dark Mode

### v1.1 — Experience Improvements 🚧
- [ ] Offline support for downloaded courses
- [ ] In-course search
- [ ] Lesson ratings (5 stars)
- [ ] Certificate sharing
- [ ] Push Notifications (FCM)

### v1.2 — Advanced Features 📌
- [ ] Background audio playback
- [ ] Picture-in-Picture mode
- [ ] Lesson notes
- [ ] Multi-device progress sync
- [ ] Full Offline Mode

### v2.0 — AI Features 🔮
- [ ] AI Tutor (smart assistant for answering questions)
- [ ] Personalized course recommendations
- [ ] Adaptive quizzes

---

## 📚 Documentation

| Document | Description |
|---|---|
| `docs/EduZone_App_Design_System_v1.md` | Complete app design system |
| `docs/EduZone_API_Design_v1.md` | RPC and Edge Function contracts |
| `docs/EduZone_Clean_Architecture.md` | Platform architecture |
| `docs/SECURITY_DESIGN.md` | Security model and authentication flows |

---

## 📊 Target Performance Metrics

| Metric | Target |
|---|---|
| First Contentful Paint (FCP) | < 2 seconds |
| Cold Start | < 3 seconds |
| Frame Rate | Stable 60 fps |
| APK Size | < 20 MB |
| Memory Usage | < 150 MB |

---

## 📄 License

**Proprietary** — EduZone Platform © 2026. All rights reserved.

Copying, distribution, or modification is not permitted without explicit written consent from the EduZone team.

---

## 📬 Contact

| Channel | Link |
|---|---|
| Bug Reports | GitHub Issues |
| Feature Requests | GitHub Discussions |
| Security Issues | security@eduzone.io (do not open a public issue) |
| Engineering Team | #mobile-app (Slack) |

---

<div align="center">

**Built with ❤️ by the EduZone Engineering Team**

*"Learning starts with a single step — we make that step easy."*

<br />

<img src="https://img.shields.io/badge/Made_with-Flutter-02569B?style=flat-square&logo=flutter" />
<img src="https://img.shields.io/badge/Powered_by-Supabase-3ECF8E?style=flat-square&logo=supabase" />
<img src="https://img.shields.io/badge/Design-Material_3-6750A4?style=flat-square" />

</div>"# EduZone_App" 
"# EduZone_App" 
"# EduZone_App" 
