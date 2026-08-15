# سجل التغييرات (Changelog)

جميع التغييرات المهمة في هذا المشروع تُوثَّق هنا.

الصيغة مبنية على [Keep a Changelog](https://keepachangelog.com/ar/1.0.0/)،
والمشروع يتّبع [Semantic Versioning](https://semver.org/lang/ar/).

## [Unreleased]

### Added / Fixed
- **Security (Offline Download — P6.16 Offline Clock Security)**:
  `OfflinePolicyEngine.authorize` previously trusted `DateTime.now()`
  directly for its offline-expiry check, with no defense against a user
  disconnecting from the network and winding the device clock backward
  before every playback attempt to defeat expiry indefinitely (T5 in the
  offline threat model). Added `OfflineClockGuard`
  (`lib/features/downloads/application/services/offline_clock_guard.dart`),
  which persists — in `flutter_secure_storage`, not SQLite — the highest
  device time this app instance has ever observed, and denies playback
  (`OfflinePlaybackDenialReason.clockRollbackSuspected`) if the current
  device time falls more than 6 hours behind that watermark. Wired into
  `OfflinePolicyEngine.authorize` immediately before the expiry check, and
  into the real playback call site
  (`offline_player_wrapper.dart`) with a real
  `FlutterSecureStorage`-backed instance. Unit tests added for both the
  new guard (`offline_clock_guard_test.dart`) and its integration into the
  policy engine (`offline_policy_engine_test.dart`). Honest boundary
  documented in `SECURITY.md` and in the class doc comments: this is a
  local, device-held heuristic, not a server-issued trusted-time
  guarantee — it does not detect a device that never advanced its clock
  while online, or one whose secure storage is itself compromised
  (root/jailbreak). Not yet independently re-verified with
  `flutter analyze`/`flutter test` in this session (no Flutter/Dart
  toolchain available in this environment) — statically inspected only.

- **Security (WebView/JS injection)**: `extractModernPlayerVideoId` (Modern
  Player, `youtube-nocookie.com` WebView) previously fell through to
  returning the raw, unrecognized `content.videoUrl` value unchanged when it
  didn't match a known YouTube URL shape. That value is interpolated
  unescaped into an executing JS context (`buildModernPlayerHtml`'s
  `videoId: "$videoId"`, and `ModernPlayerWrapper._switchVideo`'s
  `evaluateJavascript("loadVideo('$videoId')")`) — a value containing `'`,
  `"`, or `</script>` could break out of the string literal and execute
  arbitrary JS inside the player's WebView. Extraction now returns `null`
  for anything that doesn't strictly match YouTube's id shape
  (`^[A-Za-z0-9_-]{11}$` or a recognized URL pattern), and two additional
  fail-safe layers were added at the actual interpolation sites
  (`buildModernPlayerHtml`, `_switchVideo`) so a future call site that
  skips this validation degrades to an inert player instead of executing
  injected script. `shouldOverrideUrlLoading` was also changed from
  allow-by-default to deny-by-default — the WebView may now only navigate
  within its own `youtube-nocookie.com` origin; everything else is
  canceled. Regression tests added covering explicit string-literal
  breakout payloads. Not yet independently re-verified with
  `flutter analyze`/`flutter test` in this session (no Flutter/Dart
  toolchain available) — statically inspected only.
- **Security (URL handling)**: `AppConfig.buildVideoUrl` (proxy video
  player) now percent-encodes `videoId` via `Uri.encodeQueryComponent`
  before placing it in the query string, preventing a value containing
  `&`/`#`/other URL-structural characters from injecting additional query
  parameters or altering the target URL.
- **Docs**: corrected a `SECURITY.md` claim that `network_security_config.xml`
  allows cleartext traffic for `127.0.0.1`/`localhost` — the actual file has
  no such domain exception; cleartext is blocked unconditionally. The
  documented policy was less strict than the real one; no code change
  required, doc corrected to match implementation.
- **Security**: ربط `SecurityService.killAppHandler` بمسار الشاشة المقفلة (`AppRoutes.locked`) عند اكتشاف تهديد أمني.
- **L10n**: إضافة الترجمة العربية لمفتاح `searchCourses` ("ابحث عن الكورسات") في `app_ar.arb`.
- **Logging**: تقييد طباعة أحداث التنقل في `AppNavigatorObserver` على وضع التطوير فقط (`kDebugMode`).
- **Chore**: إضافة ملفات المخرجات المؤقتة لـ `.gitignore` واستبعادها من تتبع Git.

 ### Security
 - ربط معالج إنهاء التطبيق `killAppHandler` لضمان التفاعل الصحيح مع التهديدات الأمنية على iOS وأندرويد.
- **`create-user` (Edge Function)**: إصلاح ثغرة orphaned-account — إنشاء `auth.users`
  و`public.users` كانا خطوتين منفصلتين بدون rollback؛ فشل الخطوة الثانية كان
  يترك حساب auth صالح بلا profile (`ServerException('User profile not found')`
  عند تسجيل الدخول لاحقًا، بلا أي مسار تعافي). أُضيف retry محدود (3 محاولات)
  + compensating rollback (`auth.admin.deleteUser`) عند الفشل النهائي، بحيث
  تصبح العملية all-or-nothing. منشور: v18.
- **`validate-course-access` + `log-download-attempt` (Edge Functions)**: إصلاح
  فلتر `tenant_id` معطّل — كان يعتمد على `user.user_metadata.tenant_id`، وهو
  حقل غير مُعبّأ إطلاقًا في هذا النظام (الـ Auth Hook `custom_access_token`
  يحقن `tenant_id` كـ top-level JWT claim، ليس داخل `user_metadata`)، مما كان
  يرفض وصول كل مستخدم مسجّل ومشترك فعلًا لبوابة الـ download authorization.
  أُزيل الفلتر المكسور والاعتماد كليًا على عزل RLS الموثوق
  (`public.get_current_tenant_id()`)، بلا أي إضعاف أمني. منشور: v17.
- **`video-info` (Edge Function)**: كانت الدالة بلا أي مصادقة إطلاقًا (CORS
  مفتوح للجميع)، فيستطيع أي مستخدم غير مسجّل على الإنترنت استدعاءها بأي رابط
  يوتيوب واستهلاك الـ Replit API الخارجي المدفوع بلا حدود. أُضيفت بوابة
  مصادقة (`auth.getUser()`) بنفس نمط `get-lesson-content`. **لم تُغلق بعد**:
  التحقق من كون المستخدم المسجّل يملك حق فعلي على الفيديو المحدد تحديدًا
  (الدالة لا تستقبل `lesson_id`) — يحتاج تغيير API contract مستقبلًا. منشور: v20.

### Automation
- **Chore**: إضافة سير عمل GitHub Actions جديد `update-goldens.yml` لتسهيل تحديث الـ Goldens.

---

## [1.0.0+1] — نقطة البداية (Baseline)

> هذا الإصدار هو نقطة الانطلاق لهذا الـ Changelog. التغييرات السابقة لهذا
> التاريخ غير موثّقة هنا لأن تاريخ Git الفعلي للمشروع بدأ بـ commit واحد
> مجمّع ("initial project structure 2") بدون سجل تدريجي.

### Added
- بنية Clean Architecture كاملة (Feature-first) عبر الميزات: `auth`,
  `courses`, `downloads`, `video_player`, `notifications`, `profile`, `todo`.
- تشفير AES-256-GCM للفيديوهات المحمّلة (offline) مع مفاتيح فريدة لكل
  تحميل عبر `flutter_secure_storage`.
- جلسة Supabase عبر PKCE flow + Secure Storage.
- نظام Design Tokens كامل (`lib/design_system/tokens/`).
- دعم RTL (عربي أولاً) + Dark Mode + Localization (عربي/إنجليزي).
- تكامل freeRASP لكشف الأجهزة المروّطة/المحاكيات (مستند لإعدادات البيئة — راجع التوثيق في `lib/core/security/README.md`).
- CI عبر GitHub Actions: `flutter analyze`, `flutter test --coverage`, `flutter pub audit`.

### Known Issues (وقت كتابة هذا السجل)
- فحص freeRASP يتطلب تزويد المفاتيح (`SECURITY_ANDROID_SIGNING_HASH`, `SECURITY_IOS_TEAM_ID`) عبر `--dart-define-from-file=.env.security` في بناء الإنتاج.
- ~~بناء الإصدار (Release) لأندرويد موقّع بمفتاح Debug مؤقتًا بانتظار keystore إنتاج.~~
+  **محدّث (تدقيق الإنتاج):** لم يعد هذا صحيحًا. `android/app/build.gradle.kts`
+  يرفض الآن بناء أي `release` بدون `android/key.properties` صالح
+  (`GradleException: "Production release builds require android/key.properties..."`),
+  أي أن fallback إلى مفتاح Debug لم يعد ممكنًا فعليًا — تحقّق ثابت `verified`
+  من قراءة الكود، وليس افتراضًا (`assumed`). ما لم يُتحقق منه بعد فعليًا هو
+  تنفيذ بناء `release` كامل موقّع بـ keystore إنتاج حقيقي على بيئة CI/CD
+  (`blocked by environment`: لا يوجد keystore إنتاج/رنر متاح في جلسة هذا التدقيق).

- **CI — خطوة "Build APK (Staging)"**: هذه الخطوة في `.github/workflows/ci.yml` تُتخطّى عمدًا (`exit 0`) إذا لم يكن ملف `.env.staging` متوفرًا في بيئة الـ Runner، وذلك بشكل مقصود لتفادي فشل الـ CI للمساهمين الذين لا يملكون صلاحية الوصول لأسرار المشروع (Fork/Contributor PRs). **الأثر**: نجاح job الـ `quality` في CI **لا يعني** أن بناء الـ APK الفعلي (Staging) قد تم التحقق منه؛ فقط يعني نجاح `flutter analyze` و`flutter test`. للتحقق الفعلي من قابلية البناء، يجب تفعيل GitHub Secret باسم `ENV_STAGING` (محتوى ملف `.env.staging`) في إعدادات المستودع (`Settings → Secrets and variables → Actions`)، ثم تعديل الخطوة لإعادة توليد الملف من السر قبل خطوة البناء.

---

## كيف تضيف إدخالًا جديدًا

عند فتح PR يغيّر سلوكًا ملحوظًا، أضف سطرًا تحت `[Unreleased]` بالقسم المناسب:
`Added` (ميزة جديدة) / `Changed` (تعديل سلوك موجود) / `Fixed` (إصلاح خطأ) /
`Security` (إصلاح أمني) / `Removed` (إزالة ميزة). عند إصدار نسخة جديدة، انقل
محتوى `[Unreleased]` لقسم جديد بترقيم الإصدار وتاريخه، واترك `[Unreleased]`
فارغًا للتغييرات القادمة.
