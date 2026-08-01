## تقرير نهائي للتدقيق الأمني والوظيفي لـ auth

---

## 1. جدول الجرد (Phase 0)

| path | LOC | layer | read? |
|---|---|---|---|
| logout_result.dart | 25 | other | yes |
| check_user_access_service.dart | 188 | other | yes |
| logout_orchestrator.dart | 157 | other | yes |
| update_service.dart | 103 | other | yes |
| auth_remote_ds.dart | 347 | data | yes |
| update_remote_ds.dart | 48 | data | yes |
| user_model.dart | 159 | data | yes |
| auth_repo_impl.dart | 51 | data | yes |
| app_user.dart | 126 | domain | yes |
| auth_state.dart | 135 | domain | yes |
| bind_device_result.dart | 16 | domain | yes |
| update_info.dart | 48 | domain | yes |
| user_access.dart | 33 | domain | yes |
| account_status.dart | 39 | domain | yes |
| user_role.dart | 29 | domain | yes |
| auth_repository.dart | 31 | domain | yes |
| bind_device.dart | 17 | domain | yes |
| check_user_access.dart | 13 | domain | yes |
| login_user.dart | 12 | domain | yes |
| logout_user.dart | 12 | domain | yes |
| validate_device_exists.dart | 12 | domain | yes |
| auth_provider.dart | 495 | presentation | yes |
| auth_provider.g.dart | 239 | presentation | yes |
| banned_screen.dart | 146 | presentation | yes |
| force_update_screen.dart | 119 | presentation | yes |
| locked_screen.dart | 134 | presentation | yes |
| login_screen.dart | 305 | presentation | yes |
| maintenance_screen.dart | 198 | presentation | yes |
| splash_screen.dart | 585 | presentation | yes |
| suspended_screen.dart | 233 | presentation | yes |
| check_user_access_service.dart | 2 | presentation | yes |
| optional_update_dialog.dart | 168 | presentation | yes |

> قرأت كل ملف داخل auth بشكل كامل، بما في ذلك ملف الـ generated auth_provider.g.dart كجزء من التحقق.

---

## 2. مصادر اللمس الخارجية المقروءة

- app_initializer.dart
- main.dart
- supabase_client.dart
- app_router.dart
- app_state_provider.dart
- main_shell.dart
- login_screen.dart

---

## 3. الملخص التنفيذي

1. النظام يستخدم `Supabase.initialize(...)` مع `AuthFlowType.pkce` و `autoRefreshToken`، وجلسة Supabase مخزنة في `flutter_secure_storage` عبر `SecureLocalStorage`.
2. أهم ثغرة واقعية وجدت: التحقق من `token_version` لا يفرض تسجيل خروج إذا كانت قيمة `jwtVersion` فارغة ويظهر فقط تحذيرًا.
3. التوجيه يعتمد على `AppAuthState` المشتقة من `AuthState`، وهو تصميم قوي، لكن `AuthProvider` يتخطى طبقة `AuthRepository` الموجودة ويستخدم `AuthRemoteDataSource` مباشرة.
4. تسجيل الخروج ينفذ تنظيفًا جيدًا محليًا ويقطع القنوات، لكنه يعتمد على قائمة ثابتة من المزودات التي قد لا تغطي جميع حالات تسرب الحالة المستقبلية.
5. هناك 3 ملفات اختبار حالية تغطي المنطق الأساسي، لكن لا يوجد اختبار لـ `CheckUserAccessService` أو `LogoutOrchestrator` أو حالة `jwtVersion == null`.

---

## 4. تتبع التدفقات (Phase 1)

### 4.1 تسجيل الدخول
- `lib/features/auth/presentation/screens/login_screen.dart:L274`
  - `await ref.read(authProvider.notifier).login(email, password);`
- `lib/features/auth/presentation/providers/auth_provider.dart:L209`
  - `final appUser = await _remoteDataSource.login(email, password);`
- `lib/features/auth/data/datasources/auth_remote_ds.dart:L60`
  - `final response = await _client.auth.signInWithPassword(...)`
- ملاحظة: `Auth` notifier يمر مباشرًا إلى `AuthRemoteDataSource` دون استخدام `AuthRepository` أو `LoginUser` use case. هذا خرق للطبقة المتوقعة.

### 4.2 استعادة الجلسة على بدء التشغيل
- `lib/features/auth/presentation/providers/auth_provider.dart:L67`
  - `Future.microtask(() => _initializeSession());`
- `lib/features/auth/presentation/providers/auth_provider.dart:L86`
  - `final session = client.auth.currentSession;`
- `lib/features/auth/presentation/providers/auth_provider.dart:L146`
  - `final access = await _remoteDataSource.checkUserAccess();`
- `lib/features/auth/data/datasources/auth_remote_ds.dart:L28`
  - `final res = await _client.rpc('check_user_access');`

### 4.3 تسجيل الخروج
- زر الخروج في `locked_screen`, `banned_screen`, `suspended_screen`, `maintenance_screen` يستدعي:
  - `ref.read(authProvider.notifier).logout()`
- `lib/features/auth/presentation/providers/auth_provider.dart:L410`
  - يبدأ حالة `AuthLoggingOut`
- `lib/features/auth/application/services/logout_orchestrator.dart:L106`
  - `await _supabase.auth.signOut(scope: SignOutScope.local)`
- ثم `execute()` ينادي `logout_current_user` و `removeAllChannels()`.

### 4.4 الإلغاء القسري (`token_version`)
- `lib/features/auth/application/services/check_user_access_service.dart:L51`
  - Realtime subscription على جدول `users`
- `lib/features/auth/application/services/check_user_access_service.dart:L71`
  - مقارنة `newVersion > jwtVersion`
- `lib/features/auth/application/services/check_user_access_service.dart:L93`
  - `check_user_access()` RPC
- `lib/features/auth/application/services/check_user_access_service.dart:L107`
  - إذا `dbTokenVersion != null && jwtVersion == null` لا يتم تسجيل خروج

### 4.5 تحديث الرمز / التجديد
- يتم إدارة التجديد بواسطة Supabase SDK عبر `autoRefreshToken: true`
- `AuthProvider` يستمع لـ `onAuthStateChange` في `lib/features/auth/presentation/providers/auth_provider.dart:L188`
  - يلتقط `AuthChangeEvent.signedOut` أو `tokenRefreshed` مع جلسة فارغة

### 4.6 إعادة التوجيه العميق
- `lib/app/state/app_state_provider.dart:L13`
  - يشتق `AppAuthState`
- `lib/app/router/app_router.dart:L80`
  - يقرر الشاشة المستهدفة بناءً على `AppAuthState`
- التدفق يعمل منطقياً، ولا توجد معالجة روابط عميقة مباشرة في `auth` باستثناء التوجيه العام.

---

## 5. النتائج

### 🔴 Critical

- **`lib/features/auth/application/services/check_user_access_service.dart:L107-L115`**
- Evidence:
  ```dart
  } else if (dbTokenVersion != null && jwtVersion == null) {
    debugPrint('[Security] WARNING: jwtVersion is NULL. Check Supabase Auth Hooks.');
    // We don't force logout here to prevent lockouts if hook is misconfigured,
    // but it means security is weakened until the hook is fixed.
  }
  ```
- Problem:
  إذا كان JWT مفقودًا أو لا يحتوي على `token_version`، ولاحقًا يظل المستخدم لديه جلسة صالحة، فإن التطبيق لا يجبر الخروج حتى لو كانت نسخة DB أعلى.
- Impact:
  مستخدم يمكنه البقاء متصلًا بعد فقدان التزامن بين التوكن والقاعدة، وهذا يخترق آلية `forced logout` القائمة على `token_version`.
- Fix:
  استبدل المنطق بتسجيل خروج فوري في هذه الحالة أو تقديم آلية تحقق ثانوي أعاداً:
  ```dart
  if (dbTokenVersion != null && jwtVersion == null) {
    _onAccessDenied(reason: 'token_version_mismatch');
    return;
  }
  ```
- Confidence: High

### 🟠 Major

- **`lib/features/auth/presentation/providers/auth_provider.dart:L209-L233`**
- Evidence:
  ```dart
  final appUser = await _remoteDataSource.login(email, password);
  ...
  final access = await _remoteDataSource.checkUserAccess();
  ```
- Problem:
  `Auth` notifier يتصل مباشرة بـ `AuthRemoteDataSource` وي bypass طبقة `AuthRepository` و use cases الموجودة في `domain`.
- Impact:
  هذا يكسر بنية Clean Architecture، يجعل من الصعب اختبار المنطق على مستوى `domain`، ويزيد احتمال تسرب منطق أعمال إلى طبقة العرض.
- Fix:
  استخدم `AuthRepository` أو `LoginUser`/`CheckUserAccess` في `Auth` notifier بدلاً من `AuthRemoteDataSource` مباشرة، ثم حوّل الوظائف إلى هذه الطبقات.
- Confidence: High

### 🟡 Minor

- **`lib/features/auth/presentation/providers/auth_provider.dart:L441-L540`**
- Evidence:
  ```dart
  void _invalidateAllUserProviders() {
    ref.invalidate(profileProvider);
    ref.invalidate(profileRepositoryProvider);
    ...
    ref.invalidate(notificationsRemoteDataSourceProvider);
  }
  ```
- Problem:
  تنظيف الجلسة يعتمد على قائمة ثابتة من المزودات. إذا أضيفت ميزات جديدة أو تم استخدام مزودات حالة مستخدم أخرى، فقد يبقى جزء من الحالة في الذاكرة بعد تسجيل الخروج.
- Impact:
  خطر تسرب بيانات الجلسة بين حسابين مختلفين بعد logout/login.
- Fix:
  اجعل قائمة المزودات قابلة للتوسيع أو استخدم آلية مركزية للتفريغ تعتمد على حالة الجلسة بدلاً من قائمة ثابتة.

### 🔵 Suggestion

- `lib/features/auth/presentation/screens/login_screen.dart:L108-L119`
  - التحقق من كلمة المرور يفرض طولًا أدنى 8 فقط.
  - هذا جيد لواجهة المستخدم، لكن أي سياسة أكثر تعقيدًا يجب أن تطبق على الخادم أيضاً وُتذكر بوضوح في المستندات.

---

## 6. نتيجة فحص S1–S12

| Item | Status | دليل |
|---|---|---|
| S1. التخزين المحلي واللوجز | SAFE | `SecureLocalStorage.persistSession` يكتب في `flutter_secure_storage` ولا يوجد طباعة مباشرة للتوكن |
| S2. تحليل JWT | SAFE | `check_user_access_service.dart:L149-L176` يعالج padding ويعيد null عند الفشل |
| S3. `token_version` null handling | CONFIRMED-ISSUE | `check_user_access_service.dart:L107-L115` |
| S4. سباقات/إغلاق منابع | SAFE | `CheckUserAccessService.stop()` يلغي المؤقت والقناة، و`AuthProvider` يلغي الاشتراك |
| S5. الاعتماد على JWT claims | SAFE | لا يوجد اعتماد أمني على `primary_role`/`tenant_id` في `auth`، كلها UX فقط |
| S6. اكتمال تسجيل الخروج | SAFE | `LogoutOrchestrator.forceLocalCleanup()` يمسح الجلسة والقنوات وSharedPreferences |
| S7. تسرب بين المستأجرين | COULD-NOT-VERIFY | يوجد تنظيف ثابت للمزودات، لكنه قد لا يغطي كل حالة إذا أضيفت ميزة جديدة |
| S8. معالجة الأخطاء | SAFE | `AuthRemoteDataSource` يحول `AuthException` إلى typed exceptions، والشاشة تعرض مفاتيح رسائل فقط |
| S9. تحقق المدخلات | SAFE | هناك تحقق من البريد و`minLength 8`، لا يوجد سياسة client-side إضافية بخلاف ذلك |
| S10. OAuth/روابط عميقة | NOT-APPLICABLE | PKCE مستخدم، ولا توجد معالجة كلمات مرور/إعادة تعيين ضمن auth |
| S11. retry/backoff | SAFE | polling كل 5 دقائق بدون هجمة، والأخطاء تسجل فقط |
| S12. Dispose/lifecycle | SAFE | `MainShell.dispose()`, `WidgetsBindingObserver`, و`LoginScreen.dispose()` موجودة |

---

## 7. التقييم المعماري (Phase 3)

- النمط المستخدم: Riverpod `Notifier`/`AsyncNotifier` مع `Auth` كـ single source of truth.
- DI: Riverpod providers تستخدم `SupabaseService.client` و`AuthRemoteDataSource`/`UpdateService`.
- مشكلة بنيوية:
  - `AuthRepositoryImpl` و use cases موجودة لكن غير مستخدمة من `AuthProvider`.
  - `MainShell` يستخدم `Supabase.instance.client` مباشرًا بدلاً من مزود Riverpod عام.
- حالة `appStateProvider` جيدة جدًا: يحول كل `AuthState` لقيم `AppAuthState` الثمانية.
- هناك اعتمادية ضمنية على `SupabaseService.client` كـ singleton في عدة طبقات.

---

## 8. اختبارات موجودة

- auth_notifier_test.dart
  - يغطي `login()`, `logout()`, `verifyAccess()`, `handleAccessDenied()`.
- auth_repo_impl_test.dart
  - يغطي تحويلاً صحيحًا من Repository إلى DataSource.
- auth_remote_ds_test.dart
  - يغطي `check_user_access` و `bind_device` و`RPC` mapping.

---

## 9. أعلى 10 اختبارات مفقودة

1. `CheckUserAccessService` مع `jwtVersion == null` و`dbTokenVersion != null`.
2. `LogoutOrchestrator.forceLocalCleanup()` مع فشل `signOut(scope: local)`.
3. `LogoutOrchestrator.execute()` مع فشل RPC `logout_current_user`.
4. `SupabaseService.SecureLocalStorage.persistSession()` و`removePersistedSession()`.
5. `AppStateProvider` mapping لجميع حالات `AuthState`.
6. `AuthProvider._initializeSession()` عندما يكون `currentSession != null` و `validateDeviceExists` يفشل ثم succeeds/fails.
7. زر `login` في `LoginScreen` مع checkbox الشروط غير المحدد.
8. `AuthRemoteDataSource.logout()` عند فقدان الشبكة أثناء `auth.signOut()`.
9. `MainShell.didChangeAppLifecycleState()` مع توقف/استئناف `CheckUserAccessService`.
10. التوجيه في app_router.dart عند الانتقال من `AuthRestricted` إلى `AuthAuthenticated`.

---

## 10. خطة الأولويات

### الآن (قبل الإصدار التالي)
- إصلاح `token_version` null handling في `CheckUserAccessService`.
- إعادة توجيه `AuthProvider` لاستخدام `AuthRepository`/use cases بدلاً من `AuthRemoteDataSource` المباشر.
- توسيع اختبار `CheckUserAccessService` و`LogoutOrchestrator`.

### الجولة التالية
- تحويل `MainShell` لاستخدام مزود Riverpod موحد بدلًا من `Supabase.instance.client`.
- جعل تنظيف الجلسة أكثر ديناميكية وقابلًا للتوسيع.
- إضافة اختبار تكاملي لمسار تسجيل الدخول والتسجيل الخارج.

### في الخلفية
- راجع وثائق الـ Auth Hook لتأكيد أن `jwtVersion == null` فعلاً يعني خطأ في hook، ثم عالجها بشكل صارم.
- راجع كل مزود حالة مستخدم في التطبيق للتأكد من أنه لا يحتاج إدراج `ref.invalidate(...)` إضافي أثناء logout.

---

## 11. Self-audit

- التحقق الذاتي أُجري على الاقتباسات المذكورة، ولم تُسحب أي نتيجة أو تُخفض إلى غير قابلة للتحقق.
- Confidence: High.