# IMPLEMENTATION.md — خطة تنفيذ تحسينات EduZone Student App

> مستند تنفيذي مفصّل مبني على المراجعة التقنية الاحترافية للمستودع `mi9092921-alt/EduZone_App`.
> الهدف: رفع متوسط جودة المشروع من **6.4/10** إلى **9/10** عبر 4 مراحل مرتبة حسب الأولوية.
> كل مهمة تحتوي على: الملف المتأثر، المشكلة، الحل، الكود المقترح، ومعايير القبول.

---

## الفهرس

1. [نظرة عامة والمعايير](#1-نظرة-عامة-والمعايير)
2. [المرحلة 1 — إصلاحات أمنية عاجلة (الأسبوع 1)](#2-المرحلة-1--إصلاحات-أمنية-عاجلة)
3. [المرحلة 2 — تصحيح المعمارية (الأسبوع 2)](#3-المرحلة-2--تصحيح-المعمارية)
4. [المرحلة 3 — جودة الكود والتوثيق (الأسبوع 3)](#4-المرحلة-3--جودة-الكود-والتوثيق)
5. [المرحلة 4 — أداء واختبار (الأسبوع 4)](#5-المرحلة-4--أداء-واختبار)
6. [مصفوفة التتبع والتقدم](#6-مصفوفة-التتبع-والتقدم)
7. [معايير القبول النهائية (Definition of Done)](#7-معايير-القبول-النهائية)
8. [المخاطر والاعتبارات](#8-المخاطر-والاعتبارات)

---

## 1. نظرة عامة والمعايير

### 1.1 ملخص التقييم الحالي

| المحور | الحالي | المستهدف |
|---|---|---|
| Architecture | 7.0 | 9.0 |
| Flutter | 6.5 | 9.0 |
| UI/UX | 8.0 | 9.0 |
| Code Quality | 6.5 | 9.0 |
| Security | 4.5 | 9.5 |
| Performance | 5.5 | 8.5 |
| Project Structure | 6.0 | 9.0 |
| GitHub | 7.0 | 9.5 |
| **المتوسط** | **6.4** | **9.1** |

### 1.2 المبادئ الحاكمة للتنفيذ

- **الحد الأدنى من التغييرات**: لا تعمل وظيفة غير مطلوبة؛ كل خطوة تحل مشكلة موثّقة.
- **الاختبار قبل وبعد**: كل إصلاح يجب التحقق منه بـ `flutter analyze` + `flutter test` + اختبار يدوي على المسار المتأثر.
- **الالتزام الذري**: كل مهمة = PR منفصل بعنوان `fix(security): ...` أو `refactor(auth): ...`.
- **عدم كسر التوافق**: الحفاظ على واجهات `AuthRepository` و`AuthRemoteDataSource` حتى نهاية المرحلة 2.

### 1.3 الأدوات المطلوبة

```bash
flutter --version          # 3.22.0+
dart --version            # 3.4.0+
supabase --version        # 1.150+
git status                # نظيف قبل البدء
```

---

## 2. المرحلة 1 — إصلاحات أمنية عاجلة

> الأولوية القصوى. هذه المرحلة تغلق الثغرات الفعلية (Critical) المتعلقة بـ freeRASP و`token_version`.

### المهمة 1.1 — تفعيل SecurityService في AppInitializer

**الملف**: `lib/app/app_initializer.dart`

**المشكلة**: السطر معلّق:
```dart
// import '../core/security/security_service.dart';
// await SecurityService.init();
```
بقيت الحماية (screenshot، screen share، freeRASP) معطّلة في الإنتاج.

**الشرط المسبق**: يجب إنجاز المهمة 1.2 (ملء قيم freeRASP) أولًا، وإلا سيفشل التهيئة.

**الحل**:

```dart
// lib/app/app_initializer.dart
import '../core/security/security_service.dart'; // أزل التعليق

class AppInitializer {
  static Future init() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      // 1. SharedPreferences (مع timeout)
      prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('SharedPreferences timed out'),
      );

      // 2. System UI
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
      );

      // 3. Security protections — مفعّل بعد ملء قيم freeRASP
      await SecurityService.init();

      // 4. Network + Device (مع retry)
      await _initializeWithRetry(() async {
        await SupabaseService.initialize();
        await DeviceInfoHelper.init();
      }, maxRetries: 3);

      // 4.5 MediaKit
      MediaKit.ensureInitialized();

      // 5. Notifications
      final pushEnabled = prefs.getBool('push_notifications_enabled') ?? true;
      if (pushEnabled) {
        unawaited(FcmService.init());
      } else {
        unawaited(FcmService.initLocalNotifications());
      }
    } catch (e) {
      debugPrint('CRITICAL INITIALIZATION ERROR: $e');
      rethrow;
    }
  }
}
```

**معايير القبول**:
- [ ] `flutter run --release` لا يطرح استثناءً من freeRASP.
- [ ] على جهاز root، يظهر سجل `[SECURITY][THREAT DETECTED]: Privileged Access` (في وضع عدم الإنهاء) أو يُغلق التطبيق (في وضع الإنهاء).
- [ ] لا يتم استدعاء `Talsec.instance.start()` قبل `Supabase.initialize` — يجب أن التهيئة الحالية لا تعتمد على Supabase.

---

### المهمة 1.2 — ملء قيم freeRASP الحقيقية

**الملف**: `lib/core/security/freerasp_config.dart`

**المشكلة**: قيم placeholder:
```dart
const String kExpectedSignatureHash = 'YOUR_SIGNING_HASH';
const String kIosTeamId = 'YOUR_TEAM_ID';
const String kWatcherMail = 'watcher@eduzone.com';
```

**الحل**: نقل القيم الحساسة إلى `--dart-define` بدلًا من الكود المصدري.

#### الخطوة 1: إنشاء ملف `.env.security` (لا يُلتزم في git)

```bash
# .env.security (محلي فقط — مُضاف لـ .gitignore)
SECURITY_ANDROID_SIGNING_HASH=SHA256:base64_encoded_hash_here
SECURITY_IOS_TEAM_ID=ABCDE12345
SECURITY_WATCHER_MAIL=security@eduzone.com
SECURITY_ENFORCE_THREAT_TERMINATION=true
```

#### الخطوة 2: تحديث `.gitignore`

أضف:
```
.env.security
```

#### الخطوة 3: تحديث `freerasp_config.dart`

```dart
part of 'security_service.dart';

TalsecConfig _getTalsecConfig() {
  const String kWatcherMail = String.fromEnvironment(
    'SECURITY_WATCHER_MAIL',
    defaultValue: 'security@eduzone.com',
  );

  const String kExpectedSignatureHash = String.fromEnvironment(
    'SECURITY_ANDROID_SIGNING_HASH',
    defaultValue: '',
  );

  const String kIosBundleId = String.fromEnvironment(
    'SECURITY_IOS_BUNDLE_ID',
    defaultValue: 'com.eduzone.learn.app',
  );

  const String kIosTeamId = String.fromEnvironment(
    'SECURITY_IOS_TEAM_ID',
    defaultValue: '',
  );

  // فشل مبكر إذا كانت القيم ناقصة في release
  assert(() {
    if (kReleaseMode) {
      if (kExpectedSignatureHash.isEmpty || kIosTeamId.isEmpty) {
        throw StateError(
          'freeRASP: SECURITY_ANDROID_SIGNING_HASH و SECURITY_IOS_TEAM_ID '
          'مطلوبان في release. استخدم --dart-define-from-file=.env.security',
        );
      }
    }
    return true;
  }());

  return TalsecConfig(
    androidConfig: AndroidConfig(
      packageName: 'com.eduzone.learn.app',
      signingCertHashes: kExpectedSignatureHash.isEmpty
          ? const []
          : [kExpectedSignatureHash],
      supportedStores: const ['com.android.vending'],
    ),
    iosConfig: IOSConfig(
      bundleIds: const [kIosBundleId],
      teamId: kIosTeamId,
    ),
    watcherMail: kWatcherMail,
    isProd: kReleaseMode,
  );
}
```

#### الخطوة 4: حساب SHA-256 لتوقيع Android

```bash
# استخراج الـ hash بصيغة Base64 المطلوبة من freeRASP
keytool -list -v -keystore your-release.keystore -alias your-alias \
  | grep SHA256
# ثم حوّله إلى Base64:
echo -n "SHA256:HASH_HEX" | xxd -r -p | base64
```

**معايير القبول**:
- [ ] `flutter build apk --release --dart-define-from-file=.env.security` ينجح.
- [ ] بدون الملف، يفشل البناء في release (بسبب الـ assert).
- [ ] في debug، يعمل التطبيق بقيم افتراضية (فارغة) دون تعطل.

---

### المهمة 1.3 — إصلاح ثغرة `token_version == null`

**الملف**: `lib/features/auth/application/services/check_user_access_service.dart` (الأسطر 107–115)

**المشكلة**:
```dart
} else if (dbTokenVersion != null && jwtVersion == null) {
  debugPrint('[Security] WARNING: jwtVersion is NULL. Check Supabase Auth Hooks.');
  // لا يجبر logout
}
```
مستخدم يحمل JWT بلا `token_version` يبقى متصلًا حتى لو رفعت قاعدة البيانات نسخته.

**الحل**: اجبر logout فوري مع تمييز السبب لتفادي lockout الدائم في حال misconfig الخادم.

```dart
// lib/features/auth/application/services/check_user_access_service.dart

void _handleVersionMismatch({
  required int? dbTokenVersion,
  required int? jwtVersion,
}) {
  // الحالة 1: JWT يحمل نسخة أقدم من قاعدة البيانات → logout فوري
  if (dbTokenVersion != null &&
      jwtVersion != null &&
      dbTokenVersion > jwtVersion) {
    _onAccessDenied(reason: 'token_version_stale');
    return;
  }

  // الحالة 2: قاعدة البيانات تحمل نسخة لكن JWT بلا نسخة → logout فوري
  // هذا يمنع بقاء الجلسة بعد فقدان التزامن. نمنح مهلة قصيرة فقط في debug
  // لتفادي lockout المطورين أثناء اختبار hooks مكسورة.
  if (dbTokenVersion != null && jwtVersion == null) {
    if (kDebugMode) {
      debugPrint(
        '[Security] DEBUG: jwtVersion is NULL — skipping forced logout '
        'in debug mode. Fix Supabase Auth Hook before release.',
      );
      return;
    }
    // في release: إنهاء الجلسة فورًا
    _onAccessDenied(reason: 'token_version_missing_in_jwt');
    return;
  }
}

void _onAccessDenied({required String reason}) {
  // 1. سجّل الحدث
  debugPrint('[Security] Access denied: $reason');
  // 2. ابدأ حالة الإنهاء (تُدار عبر LogoutOrchestrator)
  _logoutOrchestrator.forceLocalCleanup();
  // 3. غيّر حالة Auth إلى unauthenticated مع رسالة محددة
  _onSessionInvalidated(reason);
}
```

**الاعتبار**: قبل تفعيل هذا في release، تأكد أن **Supabase Auth Hook** يحقن `token_version` فعليًا في JWT. اختبر:
```sql
-- تحقق أن الـ hook يعمل
SELECT auth.uid(), (auth.jwt() ->> 'token_version')::int AS tv;
```

**معايير القبول**:
- [ ] اختبار: مستخدم بـ JWT بلا `token_version` + قاعدة بيانات `token_version=2` → يُسجّل خروج تلقائيًا في release.
- [ ] في debug، يظهر تحذير فقط (لا logout) لتفادي إعاقة التطوير.
- [ ] رسالة الخطأ `token_version_missing_in_jwt` تُمرّر للشاشة بشكل محلي (l10n).

---

### المهمة 1.4 — تفعيل إنهاء التطبيق عند التهديدات

**الملف**: `lib/core/security/security_service.dart`

**المشكلة**: `SECURITY_ENFORCE_THREAT_TERMINATION` افتراضي `false` → التهديدات تُسجّل فقط.

**الحل**: اربط القيمة بـ `--dart-define` وفعّلها في release افتراضيًا.

```dart
class SecurityService with WidgetsBindingObserver {
  static const bool _enforceThreatTermination = bool.fromEnvironment(
    'SECURITY_ENFORCE_THREAT_TERMINATION',
    // افتراضي true في release، false في debug — عبر kReleaseMode
    defaultValue: false,
  );

  static final bool _kReleaseEnforce = kReleaseMode ? true : _enforceThreatTermination;

  static void _onThreatDetected(String threatName) {
    _logThreatToSupabase(threatName);

    final shouldKill = _kReleaseEnforce || _enforceThreatTermination;

    if (!shouldKill) {
      debugPrint('[SECURITY][THREAT DETECTED]: $threatName');
      // في debug: اسمح بعرض تنبيه للمطور بدل القتل الصامت
      if (kDebugMode) {
        _showThreatBanner(threatName);
      }
      return;
    }

    _killApp(threatName);
  }
}
```

**ملاحظة**: `exit(0)` لا يُنصح به على iOS (قد يُرفض من App Store). البديل:
```dart
static Never _killApp(String reason) {
  debugPrint('[SECURITY] App killed: $reason');
  // على iOS: النهاية الأكثر أمانًا هي إعادة التوجيه لشاشة قفل
  if (Platform.isIOS) {
    _navigateToLockScreen(reason);
  } else {
    exit(0);
  }
  // لا نصل هنا على iOS لكن لضمان Never
  while (true) {}
}
```

**معايير القبول**:
- [ ] في release، root/emulator → إنهاء التطبيق.
- [ ] في debug، يظهر تنبيه مرئي فقط (لا قتل) لتسهيل التطوير.
- [ ] لا يُستخدم `exit(0)` على iOS (يفشل مراجعة App Store).

---

### المهمة 1.5 — تحسين جودة تسجيل التهديدات

**الملف**: `lib/core/security/security_service.dart` → `_logThreatToSupabase`

**المشكلة**: بيانات ناقصة (نسخة افتراضية `1.0.0` عند الفشل)، ابتلاع صامت للأخطاء.

**الحل**: سجل محلي احتياطي + معلومات أغنى.

```dart
static void _logThreatToSupabase(String threat) {
  try {
    final client = Supabase.instance.client;
    pip.PackageInfo.fromPlatform().then((packageInfo) {
      final payload = {
        'threat': threat,
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion,
        'app_version': packageInfo.version,
        'app_build_number': packageInfo.buildNumber,
        'detected_at': DateTime.now().toUtc().toIso8601String(),
        'device_id': _anonymousDeviceId(), // hash لا يكشف الهوية
        'is_release': kReleaseMode,
      };
      client
          .from('security_incidents')
          .insert(payload)
          .then((_) => _logToLocalBuffer(threat, status: 'synced'))
          .catchError((e) => _logToLocalBuffer(threat, status: 'failed', error: e.toString()));
    }).catchError((e) {
      _logToLocalBuffer(threat, status: 'pkg_info_failed', error: e.toString());
    });
  } on StateError catch (_) {
    _logToLocalBuffer(threat, status: 'supabase_not_ready');
  } catch (e) {
    _logToLocalBuffer(threat, status: 'unknown', error: e.toString());
  }
}

// buffer محلي يُفرغ لاحقًا عند توفر الشبكة
static final List<Map<String, dynamic>> _localBuffer = [];

static void _logToLocalBuffer(String threat, {required String status, String? error}) {
  final entry = {
    'threat': threat,
    'status': status,
    'error': error,
    'timestamp': DateTime.now().toIso8601String(),
  };
  _localBuffer.add(entry);
  if (_localBuffer.length > 50) _localBuffer.removeAt(0);
  debugPrint('[SECURITY][LOG] $entry');
}
```

**معايير القبول**:
- [ ] عند فشل Supabase، يُحفظ الحدث محليًا (buffer) ولا يُفقد.
- [ ] الـ payload يحوي `platform_version` و`app_build_number` و`device_id` مجهول الهوية.

---

## 3. المرحلة 2 — تصحيح المعمارية

### المهمة 2.1 — إعادة توجيه AuthProvider عبر AuthRepository

**الملف**: `lib/features/auth/presentation/providers/auth_provider.dart` (الأسطر 209–233)

**المشكلة**: `AuthProvider` يستدعي `_remoteDataSource.login()` مباشرةً متجاوزًا `AuthRepository` وuse cases `LoginUser`/`CheckUserAccess`.

**الحل**: حقن `AuthRepository` عبر Riverpod provider واستخدامها.

#### الخطوة 1: إنشاء providers للـ repository

```dart
// lib/features/auth/data/repositories/auth_repository_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../datasources/auth_remote_ds.dart';
import 'auth_repo_impl.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_repository_provider.g.dart';

@Riverpod(keepAlive: true)
AuthRemoteDataSource authRemoteDataSource(Ref ref) {
  return AuthRemoteDataSource();
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));
}
```

#### الخطوة 2: تعديل AuthProvider

```dart
// lib/features/auth/presentation/providers/auth_provider.dart

@riverpod
class Auth extends _$Auth {
  late AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    Future.microtask(() => _initializeSession());
    return const AuthState.initializing();
  }

  Future<void> login(String email, String password) async {
    state = const AuthState.authenticating();

    try {
      // عبر الـ repository بدل DataSource مباشرة
      final appUser = await _repository.login(email, password);
      final access = await _repository.checkUserAccess();

      if (!_isAccessAllowed(access)) {
        state = AuthState.restricted(access);
        return;
      }

      await _repository.bindDevice(
        DeviceInfoHelper.deviceId,
        DeviceInfoHelper.toJson(),
        Platform.operatingSystem,
      );

      state = AuthState.authenticated(appUser);
    } on AppException catch (e) {
      state = AuthState.unauthenticated(error: e.errorKey);
    } catch (e) {
      state = const AuthState.unauthenticated(error: 'errorGeneric');
    }
  }

  // ... بقية المنطق
}
```

#### الخطوة 3: تشغيل codegen

```bash
dart run build_runner build --delete-conflicting-outputs
```

**معايير القبول**:
- [ ] لا يوجد استيراد مباشر لـ `AuthRemoteDataSource` في `auth_provider.dart`.
- [ ] `flutter analyze` لا يظهر تحذيرًا حول `avoid_dynamic_calls` على مسار المصادقة.
- [ ] اختبار: محاكاة `AuthRepository` بـ mocktail في `auth_provider_test.dart`.

---

### المهمة 2.2 — توحيد مسارات الفيديو وإزالة التكرار

**الملف**: `lib/app/router/app_router.dart`

**المشكلة**: 4 wrappers (`YoutubePlayerWrapper`, `ProxyPlayerWrapper`, `ModernPlayerWrapper`, `Player4Wrapper`) و3 مسارات مكررة (`lesson`, `lesson2`, `lesson3`).

**الحل**: مسار واحد يختار الـ wrapper ديناميكيًا من بيانات الدرس.

#### الخطوة 1: إنشاء factory للمشغّل

```dart
// lib/features/video_player/presentation/widgets/player_factory.dart
import 'package:flutter/material.dart';

enum PlayerType { youtube, proxy, modern, player4 }

class PlayerFactory {
  static Widget build({
    required BuildContext context,
    required String courseId,
    required String lessonId,
    required PlayerType type,
    required bool isFullScreen,
    required VoidCallback onToggleFullScreen,
    required bool isVertical,
  }) {
    switch (type) {
      case PlayerType.youtube:
        return YoutubePlayerWrapper(
          courseId: courseId,
          lessonId: lessonId,
          isFullScreen: isFullScreen,
          onToggleFullScreen: onToggleFullScreen,
          isVertical: isVertical,
        );
      case PlayerType.proxy:
        return ProxyPlayerWrapper(
          courseId: courseId,
          lessonId: lessonId,
          isFullScreen: isFullScreen,
          onToggleFullScreen: onToggleFullScreen,
          isVertical: isVertical,
        );
      case PlayerType.modern:
        return ModernPlayerWrapper(
          courseId: courseId,
          lessonId: lessonId,
          isFullScreen: isFullScreen,
          onToggleFullScreen: onToggleFullScreen,
          isVertical: isVertical,
        );
      case PlayerType.player4:
        return Player4Wrapper(
          courseId: courseId,
          lessonId: lessonId,
          isFullScreen: isFullScreen,
          onToggleFullScreen: onToggleFullScreen,
          isVertical: isVertical,
        );
    }
  }
}
```

#### الخطوة 2: توحيد المسار في الراوتر

```dart
// استبدل lesson/lesson2/lesson3 بمسار واحد
GoRoute(
  path: 'lesson/:lessonId',
  parentNavigatorKey: _rootNavigatorKey,
  pageBuilder: (context, state) {
    final lessonId = state.pathParameters['lessonId']!;
    final courseId = state.pathParameters['courseId']!;
    // نوع المشغّل يُحدّد من بيانات الدرس (مخزّن في DB) بدل المسار
    final playerType = PlayerType.youtube; // يُجلب من ref.watch(lessonProvider)

    return buildTransitionPage(
      state: state,
      child: VideoPlayerScreen(
        courseId: courseId,
        lessonId: lessonId,
        playerType: playerType,
        playerBuilder: (context, isFS, toggleFS, isVertical) =>
            PlayerFactory.build(
          context: context,
          courseId: courseId,
          lessonId: lessonId,
          type: playerType,
          isFullScreen: isFS,
          onToggleFullScreen: toggleFS,
          isVertical: isVertical,
        ),
      ),
    );
  },
),
```

#### الخطوة 3: تقييم إزالة الحزم غير المستخدمة

بعد توحيد المسارات، إن كان `Player4Wrapper`/`ModernPlayerWrapper` غير مستخدم فعليًا، احذف الحزم من `pubspec.yaml` لتقليل حجم APK:
```yaml
# احذف إذا لم يُستخدم:
# media_kit: ^1.2.6
# media_kit_video: ^2.0.1
# media_kit_libs_video: ^1.0.7
# flutter_inappwebview: ^6.1.5  # ثقيل (~3-5MB)
```

**معايير القبول**:
- [ ] مسار واحد `lesson/:lessonId` بدل ثلاثة.
- [ ] حجم APK يقل (قياس قبل/بعد بـ `flutter build apk --analyze-size`).
- [ ] نوع المشغّل يُحدّد من قاعدة البيانات/الإعدادات لا من المسار.

---

### المهمة 2.3 — تقسيم الملفات الضخمة

**الملفات المتأثرة**:
- `lib/features/auth/presentation/screens/splash_screen.dart` (585 سطر)
- `lib/features/auth/presentation/providers/auth_provider.dart` (495 سطر)

**مبدأ التقسيم**: كل مكوّن < 200 سطر. استخرج الأجزاء القابلة لإعادة الاستخدام لـ widgets منفصلة.

#### مثال: تقسيم splash_screen.dart

```
lib/features/auth/presentation/screens/
├── splash_screen.dart              # < 150 سطر — coordinator فقط
└── widgets/
    ├── splash_logo.dart             # الشعار + الأنيميشن
    ├── splash_status_indicator.dart # مؤشر الحالة (loading/error)
    ├── splash_version_footer.dart   # رقم الإصدار
    └── splash_initializer_widget.dart # منطق التهيئة
```

```dart
// splash_screen.dart (بعد التقسيم)
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // المنطق يُفوّض لـ SplashInitializerWidget أو ref.listen
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    return AppScreen(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          SplashLogo(),
          SizedBox(height: AppSpacing.xl2),
          SplashStatusIndicator(),
          Spacer(),
          SplashVersionFooter(),
        ],
      ),
    );
  }
}
```

**معايير القبول**:
- [ ] لا يوجد ملف `.dart` في `lib/` يتجاوز 300 سطر.
- [ ] `dart run import_sorter:main` (إن أُضيف) + `flutter format`.
- [ ] الاختبارات لا تكسر.

---

### المهمة 2.4 — استبدال Singletons الثابتة بـ Providers

**الملفات**: `SecurityService.instance`, `SupabaseService.client`

**المشكلة**: Singleton ثابت يصعّب الاختبار (لا يمكن حقن mock).

**الحل** (للـ Supabase client كمثال):

```dart
// lib/core/network/supabase_providers.dart
@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) {
  // التهيئة تتم في AppInitializer، هنا فقط نوفر مرجعًا قابلاً للاستبدال
  return Supabase.instance.client;
}

// في AuthRemoteDataSource:
@Riverpod(keepAlive: true)
AuthRemoteDataSource authRemoteDataSource(Ref ref) {
  return AuthRemoteDataSource(client: ref.watch(supabaseClientProvider));
}
```

في الاختبارات:
```dart
final container = ProviderContainer(overrides: [
  supabaseClientProvider.overrideWithValue(mockClient),
  authRemoteDataSourceProvider.overrideWithValue(mockDataSource),
]);
```

**معايير القبول**:
- [ ] اختبارات `auth_provider_test.dart` تستخدم `ProviderContainer.overrides`.
- [ ] لا يوجد استدعاء `SupabaseService.client` مباشرة خارج `core/network/`.

---

## 4. المرحلة 3 — جودة الكود والتوثيق

### المهمة 3.1 — تصحيح README.md

**الملف**: `README.md`

**المشكلات**:
1. رابط الاستنساخ `git clone https://github.com/eduzone/app.git` خاطئ.
2. جدول Tech Stack لا يطابق `pubspec.yaml`.
3. عبارة "JWT stored in memory only (no SharedPreferences for tokens)" مضلّلة.

**الحل**:

#### رابط الاستنساخ
```diff
- git clone https://github.com/eduzone/app.git
+ git clone https://github.com/mi9092921-alt/EduZone_App.git
- cd app
+ cd EduZone_App
```

#### جدول Tech Stack (محدّث بـ pubspec.yaml فعلي)

| Layer | Technology | Version (pubspec) | Purpose |
|---|---|---|---|
| Framework | Flutter | 3.x | Core |
| Language | Dart | ^3.11.1 | Programming |
| Design | Material 3 | — | Design system |
| Backend | Supabase | ^2.6.0 | DB · Auth · Realtime |
| State | flutter_riverpod | ^3.3.1 | State management |
| Riverpod annotation | riverpod_annotation | ^4.0.2 | Codegen |
| Navigation | go_router | ^17.2.0 | Routing |
| Video | youtube_player_flutter | ^9.0.1 | Lesson player |
| Media | media_kit | ^1.2.6 | Advanced media |
| Fonts | google_fonts | ^8.0.2 | Fonts |
| Images | cached_network_image | ^3.4.1 | Image caching |
| Secure storage | flutter_secure_storage | ^10.0.0 | Session storage |
| RASP | freerasp | ^8.0.0 | Anti-tampering |
| Testing | flutter_test · mocktail | SDK · ^1.0.5 | Tests |

> ملاحظة: `flutter_animate` كان مذكورًا في README و**غير مثبّت** في pubspec — أزلته.

#### تصحيح تخزين JWT

```diff
### 🔐 Authentication & Security
- - JWT stored in memory only (no `SharedPreferences` for tokens)
+ - Session persisted securely via `flutter_secure_storage` (hardware-backed Keystore/Keychain)
+   — `SecureLocalStorage` implements Supabase's `LocalStorage` interface.
+   No tokens stored in `SharedPreferences`.
```

**معايير القبول**:
- [ ] `git clone` بالرابط الجديد ينجح.
- [ ] كل إصدار في الجدول مطابق لـ `pubspec.yaml`.
- [ ] لا توجد حزم مذكورة غير مثبّتة.

---

### المهمة 3.2 — تفعيل قسم assets في pubspec.yaml

**الملف**: `pubspec.yaml`

**المشكلة**:
```yaml
flutter:
  generate: true
  uses-material-design: true
  # assets:
  # - assets/images/
  # - assets/icons/
```
أي ملفات في `assets/` لن تُحمّل وقت التشغيل.

**الحل**: تفعيله وفق الهيكل الفعلي.

```yaml
flutter:
  generate: true
  uses-material-design: true

  assets:
    - assets/images/
    - assets/icons/
    - assets/lottie/        # إن وُجد

  fonts:
    - family: Cairo
      fonts:
        - asset: assets/fonts/Cairo-Regular.ttf
        - asset: assets/fonts/Cairo-Bold.ttf
          weight: 700
    - family: JetBrainsMono
      fonts:
        - asset: assets/fonts/JetBrainsMono-Regular.ttf
```

ثم في الكود استبدل `google_fonts` (شبكي ثقيل) بالخطوط المحلية إن كان الأداء أولوية:
```dart
// بدل GoogleFonts.cairo()، استخدم:
TextStyle(fontFamily: 'Cairo', ...)
```

**معايير القبول**:
- [ ] `flutter pub get` لا ينتج خطأ asset missing.
- [ ] الصور في `assets/images/` تظهر عند التشغيل.

---

### المهمة 3.3 — إصلاح تسرّب TapGestureRecognizer في LoginScreen

**الملف**: `lib/features/auth/presentation/screens/login_screen.dart` (الأسطر 108–119)

**المشكلة**: `TapGestureRecognizer` يُنشأ داخل `build()` ولا يُعاد تخزينه/إلغاؤه → تسرّب.

**الحل**: احفظه كـ field وألغِه في `dispose()`.

```dart
class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;
  bool _obscurePassword = true;
  String _appVersion = '';
  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => context.push('${AppRoutes.legal}/terms');
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => context.push('${AppRoutes.legal}/privacy');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  // في build():
  // recognizer: _termsRecognizer,  بدل إنشاء جديد
  // recognizer: _privacyRecognizer,
}
```

**معايير القبول**:
- [ ] `flutter analyze` — لا تحذير `cancel_subscriptions`/`close_sinks` على هذا الملف.
- [ ] اختبار: فتح/إغلاق الشاشة 10 مرات → لا يزيد عدد listeners.

---

### المهمة 3.4 — تنظيف مجلدات أدوات AI من المستودع

**الملفات**: `.agents/`, `.amazonq/`, `.devin/`, `AGENTS.md`, `CLAUDE.md`

**المشكلة**: أدوات تطوير داخلية لا داعي لها في مستودع الإنتاج.

**الحل**:

```bash
# أزل من git مع الإبقاء محليًا
git rm -r --cached .agents/ .amazonq/ .devin/ AGENTS.md CLAUDE.md
```

ثم في `.gitignore`:
```
# AI tooling (local only)
.agents/
.amazonq/
.devin/
AGENTS.md
CLAUDE.md
.cursorrules
.continue/
```

**معايير القبول**:
- [ ] `git status` نظيف بعد الإزالة.
- [ ] المجلدات تبقى محليًا لمواصلة استخدام الأدوات.

---

### المهمة 3.5 — توسيع قواعد Lint

**الملف**: `analysis_options.yaml`

**الحل**: أضف قواعد أكثر صرامة.

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    invalid_annotation_target: ignore
    missing_required_param: error
    missing_return: error
    todo: warning
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "lib/generated/"

linter:
  rules:
    # القائمة الحالية +
    - prefer_const_constructors
    - prefer_const_declarations
    - avoid_print
    - avoid_dynamic_calls
    - always_declare_return_types
    - cancel_subscriptions
    - close_sinks
    - prefer_single_quotes
    - avoid_unnecessary_containers
    - sized_box_for_whitespace
    - use_decorated_box
    - use_colored_box
    # إضافات جديدة
    - prefer_const_constructors_in_immutables
    - prefer_const_literals_to_create_immutables
    - prefer_final_locals
    - prefer_final_in_for_each
    - require_trailing_commas
    - unawaited_futures
    - use_key_in_widget_constructors
    - use_build_context_synchronously
    - avoid_unnecessary_containers
    - prefer_interpolation_to_compose_strings
    - directives_ordering
    - sort_child_properties_last
    - public_member_api_docs
    - lines_longer_than_80_chars
    - avoid_redundant_argument_values
```

**معايير القبول**:
- [ ] `flutter analyze` يمرّ بنسبة 0 error قبل الدمج.
- [ ] CI يفشل عند وجود تحذيرات جديدة.

---

## 5. المرحلة 4 — أداء واختبار

### المهمة 4.1 — اختبارات الوحدات الحرجة

**الملفات الجديدة**:
- `test/features/auth/check_user_access_service_test.dart`
- `test/features/auth/logout_orchestrator_test.dart`
- `test/features/auth/auth_provider_test.dart`

#### مثال: اختبار ثغرة token_version

```dart
// test/features/auth/check_user_access_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  group('CheckUserAccessService token_version handling', () {
    test('forces logout when jwtVersion is null but dbTokenVersion exists (release)', () {
      // تعيين kReleaseMode = true عبر testing
      final service = CheckUserAccessService(...);

      service.handleVersionMismatch(
        dbTokenVersion: 2,
        jwtVersion: null,
      );

      verify(() => logoutOrchestrator.forceLocalCleanup()).called(1);
    });

    test('keeps session when jwtVersion matches dbTokenVersion', () {
      service.handleVersionMismatch(
        dbTokenVersion: 2,
        jwtVersion: 2,
      );

      verifyNever(() => logoutOrchestrator.forceLocalCleanup());
    });

    test('forces logout when dbTokenVersion > jwtVersion', () {
      service.handleVersionMismatch(
        dbTokenVersion: 3,
        jwtVersion: 2,
      );

      verify(() => logoutOrchestrator.forceLocalCleanup()).called(1);
    });

    test('does NOT logout in debug when jwtVersion is null', () {
      // kDebugMode = true
      service.handleVersionMismatch(
        dbTokenVersion: 2,
        jwtVersion: null,
      );

      verifyNever(() => logoutOrchestrator.forceLocalCleanup());
    });
  });
}
```

**معايير القبول**:
- [ ] تغطية `check_user_access_service.dart` ≥ 90%.
- [ ] `flutter test --coverage` يولّد تقريرًا.
- [ ] CI يفشل عند انخفاض التغطية.

---

### المهمة 4.2 — تحسين الصور

**الملف**: المكوّنات التي تستخدم `cached_network_image`

**الحل**: أضِف `cacheWidth`/`cacheHeight` لتقليل استهلاك الذاكرة.

```dart
// قبل
CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)

// بعد
CachedNetworkImage(
  imageUrl: url,
  fit: BoxFit.cover,
  cacheWidth: (MediaQuery.of(context).size.width * 2).toInt(), // 2x للـ retina
  cacheHeight: (200 * 2).toInt(), // ارتفاع البطاقة
  placeholder: (context, url) => Skeletonizer(child: Container()),
  errorWidget: (context, url, error) => Icon(Icons.error),
)
```

أو أنشئ wrapper مشترك:
```dart
// lib/shared/widgets/app_network_image.dart
class AppNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      cacheWidth: width != null ? (width! * dpr).round() : null,
      cacheHeight: height != null ? (height! * dpr).round() : null,
      placeholder: (c, u) => const Skeletonizer(child: SizedBox.expand()),
      errorWidget: (c, u, e) => const Icon(Icons.broken_image_outlined),
    );
  }
}
```

**معايير القبول**:
- [ ] استهلاك الذاكرة أقل (قياس بـ DevTools Memory).
- [ ] كل الصور في القوائم تمر عبر `AppNetworkImage`.

---

### المهمة 4.3 — معالجة JWT على Isolate

**الملف**: `lib/features/auth/application/services/check_user_access_service.dart`

**المشكلة**: تحليل JWT على main thread قد يسبب jank.

**الحل**: انقل التحليل لـ isolate.

```dart
// lib/core/utils/jwt_decoder.dart
import 'dart:convert';
import 'dart:isolate';

class JwtDecoder {
  static Future<Map<String, dynamic>?> decode(String? token) async {
    if (token == null || token.isEmpty) return null;

    // للـ tokens القصيرة، احلّل على main؛ للطويلة، استخدم isolate
    if (token.length < 2000) {
      return _decodeSync(token);
    }

    return Isolate.run(() => _decodeSync(token));
  }

  static Map<String, dynamic>? _decodeSync(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
```

**معايير القبول**:
- [ ] لا يحدث jank عند تحليل JWT (قياس بـ DevTools Performance).
- [ ] اختبار: JWT فارغ/معطوب يعيد null دون استثناء.

---

### المهمة 4.4 — توازي مهام الإقلاع

**الملف**: `lib/app/app_initializer.dart`

**المشكلة**: مهام تسلسلية تبطّئ الإقلاع.

**الحل**: وازِن المهام المستقلة.

```dart
static Future<void> init() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // المهام المستقلة (تتوازى):
    // - SharedPreferences (مطلوب لخطوة لاحقة)
    // - Security (مستقل)
    // - DeviceInfo (مستقل)
    final results = await Future.wait([
      SharedPreferences.getInstance(),
      SecurityService.init(),
      DeviceInfoHelper.init(),
    ]);
    prefs = results[0];

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );

    // Supabase (مستقل عن البقية، لكن FCM يعتمد عليه)
    await _initializeWithRetry(SupabaseService.initialize, maxRetries: 3);

    MediaKit.ensureInitialized();

    final pushEnabled = prefs.getBool('push_notifications_enabled') ?? true;
    unawaited(pushEnabled ? FcmService.init() : FcmService.initLocalNotifications());
  } catch (e) {
    debugPrint('CRITICAL INITIALIZATION ERROR: $e');
    rethrow;
  }
}
```

> تنبيه: `SecurityService.init()` قد يعتمد على Supabase (للتسجيل). إن كان كذلك، أبقِه تسلسليًا بعد Supabase. تحقّق قبل التغيير.

**معايير الققبول**:
- [ ] زمن الإقلاع يقل (قياس بـ `flutter run --trace-startup`).
- [ ] لا سباق (race) بين التهيئة و`main_app.dart`.

---

### المهمة 4.5 — Accessibility (Semantics)

**الملف**: المكوّنات المشتركة في `lib/shared/widgets/`

**الحل**: أضِف Semantics للأزرار/الحقول.

```dart
// AppButton
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final AppButtonVariant variant;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !isLoading,
      label: label,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: _styleFor(variant),
        child: isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
            : Text(label),
      ),
    );
  }
}
```

للحقول:
```dart
Semantics(
  textField: true,
  label: l10n.emailHint,
  child: AppTextField(...),
)
```

**معايير القبول**:
- [ ] اختبارTalkBack/VoiceOver يقرأ الأزرار والحقول بشكل صحيح.
- [ ] حجم لمس ≥ 48×48dp على كل العناصر التفاعلية.

---

## 6. مصفوفة التتبع والتقدم

| # | المهمة | الأولوية | المرحلة | الحالة | المسؤول |
|---|---|---|---|---|---|
| 1.1 | تفعيل SecurityService | Critical | 1 | ⬜ TODO | — |
| 1.2 | ملء قيم freeRASP | Critical | 1 | ⬜ TODO | — |
| 1.3 | إصلاح token_version null | Critical | 1 | ⬜ TODO | — |
| 1.4 | إنهاء التطبيق عند التهديدات | High | 1 | ⬜ TODO | — |
| 1.5 | تحسين تسجيل التهديدات | Medium | 1 | ⬜ TODO | — |
| 2.1 | إعادة توجيه AuthProvider | High | 2 | ⬜ TODO | — |
| 2.2 | توحيد مسارات الفيديو | High | 2 | ⬜ TODO | — |
| 2.3 | تقسيم الملفات الضخمة | Medium | 2 | ⬜ TODO | — |
| 2.4 | استبدال Singletons | Medium | 2 | ⬜ TODO | — |
| 3.1 | تصحيح README | High | 3 | ⬜ TODO | — |
| 3.2 | تفعيل assets | High | 3 | ⬜ TODO | — |
| 3.3 | إصلاح تسرّب Recognizer | Medium | 3 | ⬜ TODO | — |
| 3.4 | تنظيف مجلدات AI | Low | 3 | ⬜ TODO | — |
| 3.5 | توسعة Lint Rules | Medium | 3 | ⬜ TODO | — |
| 4.1 | اختبارات الوحدات | High | 4 | ⬜ TODO | — |
| 4.2 | تحسين الصور | Medium | 4 | ⬜ TODO | — |
| 4.3 | JWT على Isolate | Low | 4 | ⬜ TODO | — |
| 4.4 | توازي مهام الإقلاع | Medium | 4 | ⬜ TODO | — |
| 4.5 | Accessibility | Medium | 4 | ⬜ TODO | — |

> الحالات: ⬜ TODO → 🔄 IN PROGRESS → ✅ DONE → ⛔ BLOCKED

---

## 7. معايير القبول النهائية (Definition of Done)

عند اكتمال كل المراحل، يجب تحقيق الآتي:

### 7.1 الأمان
- [ ] `freeRASP` مُفعّل في release مع قيم حقيقية.
- [ ] ثغرة `token_version == null` مغلقة (مع اختبار آلي).
- [ ] لا توجد مفاتيح/أسرار في الكود المصدر.
- [ ] `.env.security` غير ملتزم في git.
- [ ] تقرير فحص أمان (مثلًا بـ `flutter pub run dependency_validator`) نظيف.

### 7.2 المعمارية
- [ ] لا استدعاء مباشر لـ `DataSource` من `Notifier`.
- [ ] لا Singleton ثابت خارج `core/`.
- [ ] كل ملف < 300 سطر.

### 7.3 الجودة
- [ ] `flutter analyze` — 0 error، 0 warning.
- [ ] تغطية الاختبارات ≥ 80% على `auth/`.
- [ ] `README.md` مطابق للواقع 100%.
- [ ] لا مجلدات أدوات AI في المستودع.

### 7.4 الأداء
- [ ] زمن الإقلاع < 1.5 ثانية (release).
- [ ] حجم APK أقل بـ 15% من الحالي (بعد إزالة الحزم غير المستخدمة).
- [ ] لا jank في الـ frames المتعلقة بالصور/JWT.

### 7.5 GitHub/CI
- [ ] CI workflow يفحص: `analyze` + `test` + `build`.
- [ ] PR template يُستخدم في كل PR.
- [ ] Dependabot مفعّل مع `ignore` الصحيح.
- [ ] CODEOWNERS يطالب بمراجعة فريق الأمان على `lib/core/security/`.

---

## 8. المخاطر والاعتبارات

### 8.1 مخاطر المرحلة 1 (الأمن)
- **خطر lockout**: تفعيل `_onAccessDenied('token_version_missing_in_jwt')` في release قد يطرد كل المستخدمين إن كان Auth Hook معطّلًا. **التخفيف**: ابدأ بمرحلة "warn-only" لـ 24 ساعة (سجّل دون إنهاء)، رصد الحوادث، ثم فعّل الإنهاء بعد التأكد من قلة `token_version_missing_in_jwt`.
- **خطر App Store rejection**: `exit(0)` على iOS مرفوض غالبًا. استخدم redirect لشاشة قفل بدل القتل.

### 8.2 مخاطر المرحلة 2 (المعمارية)
- **تغيير واجهة `AuthProvider`**: قد يكسر `splash_screen` وغيره. أبقِ الـ API العام (`login`, `logout`, `checkUserAccess`) كما هو، غيّر فقط التنفيذ الداخلي.
- **حذف الحزم**: تأكد أن `media_kit` غير مستخدم في `video_player` قبل الحذف. ابحث: `grep -r "package:media_kit" lib/`.

### 8.3 مخاطر المرحلة 4 (الأداء)
- **Isolates على الويب**: `Isolate.run` غير مدعوم على Flutter Web. إن كان التطبيق يستهدف الويب، استخدم compute من `flutter/foundation` (يهتم بالـ fallback).
- **Future.wait الفشل**: عجز أي مهمة في `Future.wait` يلغي الكل. استخدم `Future.wait([...], eagerError: false)` إن أردت الاستمرار رغم فشل مهمة غير حرجة.

### 8.4 اعتبارات التراجع (Rollback)
لكل تغيير أمني، جهّز علم ميزة (feature flag):
```dart
const bool _kSecurityHardeningEnabled = bool.fromEnvironment(
  'FEATURE_SECURITY_HARDENING',
  defaultValue: false,
);
```
فعّل تدريجيًا: 5% → 25% → 100% من المستخدمين عبر Remote Config أو إصدار متتابع.

---

## ملاحق

### ملحق أ: أوامر مفيدة

```bash
# تحليل
flutter analyze
dart run import_sorter:main

# codegen
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs

# اختبار
flutter test --coverage
flutter test --update-goldens

# بناء
flutter build apk --release --dart-define-from-file=.env.security --analyze-size
flutter build ipa --release --dart-define-from-file=.env.security

# قياس الإقلاع
flutter run --trace-startup --profile
```

### ملحق ب: قائمة فحص PR

- [ ] `flutter analyze` نظيف
- [ ] `flutter test` يمر
- [ ] لا `print()` جديد (استخدم `debugPrint`)
- [ ] لا استيراد غير مستخدم
- [ ] Semantics مضافة للعناصر التفاعلية الجديدة
- [ ] سلاسل محلية (l10n) للنصوص الجديدة (عربي + إنجليزي)
- [ ] لا حجم لمس < 48dp
- [ ] لا تسرّب controllers/recognizers/subscriptions
- [ ] التغييرات الأمنية مراجَعة من فريق الأمان (CODEOWNERS)

### ملحق ج: مراجع

- freeRASP docs: https://docs.talsec.app/freerasp
- Riverpod 3 migration: https://riverpod.dev/docs/migration
- go_router 17: https://pub.dev/packages/go_router
- Supabase Flutter: https://supabase.com/docs/reference/dart
- Material 3: https://m3.material.io/

---

**نهاية المستند** — لتنفيذ أي مهمة، أنشئ فرعًا: `git checkout -b fix/1.3-token-version-null` واتبع الخطوات أعلاه.