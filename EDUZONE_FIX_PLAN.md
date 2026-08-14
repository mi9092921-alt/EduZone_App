# EduZone — خطة الإصلاح التنفيذية

**المستودع:** mi9092921-alt/EduZone_App
**Commit المرجعي:** `505ae9bf04b4e12c0db767cb36c90a5fa02a3a02`
**تاريخ الإعداد:** 11 أغسطس 2026
**الحالة:** تم التحقق من كل بند أدناه مباشرة من كود المستودع (قراءة ملفات، `openssl`، `grep`)، ما عدا ما ذُكر صراحة أنه غير منفَّذ (تشغيل `flutter test`/بناء APK لعدم توفر Flutter SDK في بيئة المراجعة).

---

## Overall Health (بعد التحقق)

| المحور | التقييم | ملاحظة |
|---|---|---|
| Security (TLS/Pinning) | 4/10 | شهادة تنتهي خلال 59 يومًا وتُسقط ثقة نظام التشغيل بالكامل |
| Core Feature Completeness | 5/10 | التسجيل بالمقرر معطّل بالكامل من الواجهة |
| Notifications | 3/10 | Push غير مُهيأ على أي من المنصتين فعليًا |
| Architecture | 8/10 | فصل طبقات جيد، تكرار طفيف في ownership |
| Testing/CI | 6/10 | فحوصات جيدة لكن بها false positive حقيقي + اختبار غير متزامن مع الكود |
| **Production Ready** | **~55%** | لا يجوز الإصدار قبل إغلاق Critical + High |

---

## Priorities

### Critical (يمنع الإطلاق)
- SEC-001 — تجديد/تصحيح استراتيجية تثبيت شهادة Supabase

### High (يمنع رحلة أساسية أو خاصية معلَنة)
- FEAT-001 — ربط زر التسجيل بالمقرر بالتدفق الفعلي
- NOTIF-001 — إكمال إعداد Firebase/FCM لكلا المنصتين
- NOTIF-002 — حفظ FCM token بعد تسجيل الدخول مباشرة
- NOTIF-003 — تسجيل الـ Router في FcmService لتفعيل التنقل من الإشعار

### Medium (تسريب/سلوك غير سليم)
- DL-001 — توحيد تنظيف ملفات الفيديو/الصوت عند الإلغاء والحذف
- AUTH-001 — معالجة انقطاع الشبكة أثناء `_initializeSession` (لا تجميد بلا مخرج)
- AUTH-002 — توحيد مالك `CheckUserAccessService` (نسخة واحدة فقط لكل جلسة)

### Low (جودة/أدوات لا تحجب الإصدار)
- QA-001 — إصلاح باگ في `tool/check_a11y.py` نفسه (false positive على الأسماء بدون underscore) — **ليس في الواجهة**
- QA-002 — تحديث mocks في `download_repository_impl_test.dart` لتطابق `startEncryptedDownload`
- LAYOUT-001 — تصحيح شرط breakpoint في `AdaptiveLayout` (لا يُستخدم حاليًا، لكن يجب إصلاحه قبل أي اعتماد على iPad)

---

## Detailed Tasks

### SEC-001
**Priority:** Critical | **Difficulty:** Medium | **Est:** 1–2 أيام
**Files:** `assets/certs/supabase.pem`, `assets/certs/backup_ca.pem`, `lib/core/network/certificate_pinning.dart`, `.github/workflows/*`

**Description:** التطبيق يعمل بـ `SecurityContext(withTrustedRoots: false)` ويثق فقط بملفات `assets/certs/`. الشهادة المثبتة هي شهادة Leaf (`CN=supabase.com`) تنتهي في `2026-10-09`، وملف `backup_ca.pem` الاحتياطي فشل فعليًا في بناء سلسلة ثقة صالحة (`unable to get local issuer certificate` عبر `openssl verify`).

**Root Cause:** تثبيت شهادة خادم قصيرة العمر بدل تثبيت مفتاح عام (Public Key Pinning) أو سلسلة CA وسيطة/جذرية طويلة الأمد، دون آلية تجديد آلية أو تنبيه.

**Solution:**
1. الانتقال من Leaf Pinning إلى **Public Key Pinning** (SPKI hash) لمفتاحي أساسي واحتياطي، أو تثبيت CA الوسيط الصادر منه (عمره أطول من عمر شهادة Leaf).
2. توثيق دورة تجديد ربع سنوية مع مسؤول محدد.
3. إضافة Job في CI يتحقق يوميًا من تاريخ انتهاء كل شهادة داخل `assets/certs/` ويطلق فشلًا/تنبيهًا إذا تبقى أقل من 90 يومًا.

**Acceptance Criteria:**
- [ ] اتصال ناجح بـ Supabase مع شهادة تجريبية جديدة قبل الانتهاء الفعلي
- [ ] Job CI يفشل عمدًا عند اختبار بشهادة عمرها المتبقي < 90 يومًا (اختبار سلبي)
- [ ] لا اعتماد على شهادة Leaf وحيدة بلا احتياطي فعّال

**Risks:** إن أُخطئ التطبيق التنفيذ قد يفقد الاتصال بالكامل — يجب اختبار على بناء staging قبل الإنتاج.
**Dependencies:** لا شيء، لكنه يجب أن يُنفَّذ أولًا (يحجب أي اختبار قبول ميداني بعد 9 أكتوبر 2026).

---

### FEAT-001
**Priority:** High | **Difficulty:** Easy–Medium | **Est:** 4–6 ساعات
**Files:** `lib/shared/components/course/enroll_action_button.dart`, `lib/features/courses/presentation/widgets/course_enroll_price_row.dart`, `lib/features/courses/presentation/providers/courses_provider.dart`

**Description:** `EnrollActionButton._onTap` يستدعي `SnackBar` بنص "Coming soon" فقط، بينما `courses_provider.dart` يحتوي `enroll(String courseId)` جاهزة وغير مستخدَمة من أي واجهة.

**Root Cause:** الزر لم يُوصَّل بالـ Provider عند تطوير الواجهة (طبقة العرض متأخرة عن طبقة الـ domain/data).

**Solution:**
- تمرير `courseId` + `VoidCallback onSuccess` إلى `EnrollActionButton`.
- عند الضغط: استدعاء `ref.read(userSubscriptionsProvider.notifier).enroll(courseId)`.
- عند النجاح: تحديث `myCoursesProvider` و`isEnrolledProvider(courseId)`، والانتقال لمحتوى المقرر.
- عند الفشل: عرض رسالة خطأ مفهومة (وليس Snackbar عام).

**Acceptance Criteria:**
- [ ] الضغط على "سجّل الآن" في مقرر مجاني/عام ينشئ اشتراكًا فعليًا في Supabase
- [ ] المقرر يظهر في "مقرراتي" فور النجاح
- [ ] اختبار widget يثبت استدعاء `enroll()` والانتقال بعد النجاح

**Risks:** منخفض — دالة enroll موجودة ومختبرة على مستوى الـ provider غالبًا.
**Dependencies:** لا شيء.

---

### NOTIF-001
**Priority:** High | **Difficulty:** Medium | **Est:** 1 يوم
**Files:** `lib/features/notifications/data/services/fcm_service.dart`, `android/app/build.gradle*`, `ios/Runner/Info.plist`, ملف entitlements جديد، `.gitignore`

**Description:** لا يوجد `firebase_options.dart` ولا `google-services.json` ولا `GoogleService-Info.plist` في المستودع (مستثناة عمدًا بـ `.gitignore` سطر 52–53 بلا آلية حقن بديلة في CI). على iOS: لا ملف entitlements، ولا `remote-notification` ضمن `UIBackgroundModes` (الموجود حاليًا: `fetch`, `processing` فقط).

**Root Cause:** إعداد Firebase غير مكتمل على مستوى المشروع (منصة + CI)، وليس خطأ برمجي في Dart.

**Solution:**
1. تشغيل `flutterfire configure` لإنشاء `lib/firebase_options.dart` وتوثيق حقنه في CI (Secret منفصل لكل بيئة).
2. إضافة `google-services.json` إلى pipeline كـ CI secret يُكتب وقت البناء.
3. تفعيل Push Notifications + Remote notifications في Xcode، إنشاء `Runner.entitlements` مع `aps-environment`، ورفع مفتاح APNs في Firebase Console.
4. إضافة `remote-notification` إلى `UIBackgroundModes`.
5. إزالة `catch (e) { }` الصامت في `FcmService.init()` — تسجيل الخطأ في أداة مراقبة (Sentry/Crashlytics) بدل تجاهله.

**Acceptance Criteria:**
- [ ] إشعار تجريبي يصل فعليًا على جهاز Android حقيقي وجهاز iOS حقيقي
- [ ] فشل تهيئة Firebase (إن حدث) يظهر في نظام المراقبة، لا في console فقط

**Risks:** متوسط — يتطلب وصولًا لحساب Firebase/Apple Developer وقد يحتاج تنسيقًا خارج الكود.
**Dependencies:** يجب أن يسبق NOTIF-002 وNOTIF-003 لتكون قابلة للاختبار فعليًا.

---

### NOTIF-002
**Priority:** High | **Difficulty:** Easy | **Est:** 2–3 ساعات
**Files:** `lib/app/app_initializer.dart`, `lib/features/notifications/data/services/fcm_service.dart`, ملف تسجيل الدخول في Auth

**Description:** تهيئة FCM تحدث مرة واحدة عند إقلاع التطبيق فقط. إن لم يوجد مستخدم Supabase في تلك اللحظة (مستخدم جديد يسجل دخول بعدها)، لا يوجد أي استدعاء لاحق لحفظ الـ token.

**Root Cause:** غياب hook بعد نجاح `login()` يربط الـ token الحالي بالمستخدم الجديد.

**Solution:** دالة idempotent مثل `FcmService.registerCurrentUserToken()` تُستدعى مباشرة بعد نجاح تسجيل الدخول (وبعد التحقق من الصلاحية)، مع إعادة محاولة عند فشل الشبكة.

**Acceptance Criteria:**
- [ ] مستخدم جديد يسجل دخول لأول مرة → صف `push_tokens` يُكتب فورًا بلا حاجة لإعادة فتح التطبيق
- [ ] اختبار تدفق Login → Token persistence

**Dependencies:** NOTIF-001.

---

### NOTIF-003
**Priority:** High | **Difficulty:** Easy | **Est:** 1–2 ساعة
**Files:** `lib/app/main_app.dart`, `lib/features/notifications/data/services/fcm_service.dart`

**Description:** `FcmService.registerRouter(router)` معرَّفة لكن **لا يوجد أي استدعاء لها في كامل `lib/`** (تحقق بـ grep شامل). لذلك `_router` يبقى `null` دائمًا، وكل التنقل من الإشعار (foreground/background/terminated) هو no-op فعلي.

**Root Cause:** خطوة ربط ناقصة عند بناء `EduZoneApp`/الـ `GoRouter`.

**Solution:** استدعاء `FcmService.registerRouter(router)` فور بناء الـ Router في `EduZoneApp`، أو — أفضل معماريًا — نقل معالجة الـ deep link من static mutable state إلى Notifier/Coordinator يُحقن عبر Riverpod بدل متغير static.

**Acceptance Criteria:**
- [ ] اختبار السيناريوهات الثلاثة: local notification في foreground، `onMessageOpenedApp` في background، و`getInitialMessage` عند terminated — والانتقال يحدث فعليًا في الثلاثة

**Dependencies:** NOTIF-001.

---

### DL-001
**Priority:** Medium | **Difficulty:** Easy | **Est:** 2–3 ساعات
**Files:** `lib/features/downloads/data/repositories/download_repository_impl.dart`

**Description:** `deleteDownload` يحذف `encrypted_path`, `encrypted_path.tmp`, `audio_path`, `audio_path.tmp` (4 مسارات). `cancelDownload` يحذف فقط `encrypted_path` و`encrypted_path.tmp` (سطر 365–425) — تحقق سطرًا بسطر مؤكِّد أن `audioPath` غير مُعالَج إطلاقًا في هذه الدالة.

**Root Cause:** منطق التنظيف مكرَّر بدل موحَّد في دالة واحدة، فتم تحديث `deleteDownload` لدعم dual-track دون تحديث `cancelDownload` المقابل.

**Solution:** استخراج دالة خاصة `_cleanupAllFiles(downloadId, {encryptedPath, audioPath})` يستدعيها كلا المسارين.

**Acceptance Criteria:**
- [ ] اختبار: بدء تنزيل ثنائي المسار (فيديو+صوت) ثم إلغاؤه → لا يتبقى أي من الملفات الأربعة على القرص

**Dependencies:** لا شيء.

---

### AUTH-001
**Priority:** Medium | **Difficulty:** Medium | **Est:** 4–6 ساعات
**Files:** `lib/features/auth/presentation/providers/auth_provider.dart`, `lib/features/auth/presentation/screens/splash_screen.dart`

**Description:** عند خطأ شبكة عابر أثناء `_initializeSession()`، الحالة تبقى `AuthInitializing` بلا أي انتقال أو retry (تحقق من الكود: `_safeSetStateIfStillInitializing` لا تُستدعى في مسار الخطأ العابر). شاشة Splash عرض بصري فقط بلا زر إعادة محاولة.

**Solution:** إضافة حالة صريحة (Offline/Retry) بعد مهلة زمنية محددة، أو استخدام `connectivity_plus` لإعادة المحاولة تلقائيًا عند عودة الاتصال. لا تترك `AuthInitializing` مفتوحة بلا حد زمني.

**Acceptance Criteria:**
- [ ] اختبار بدء بارد مع خطأ شبكة محاكى → يظهر عنصر Retry وتنجح الحالة عند تكرار المحاولة

---

### AUTH-002
**Priority:** Medium | **Difficulty:** Easy | **Est:** 2–3 ساعات
**Files:** `lib/app/router/main_shell.dart`, `lib/features/auth/presentation/providers/auth_provider.dart`

**Description:** `CheckUserAccessService` يُنشأ ويُشغَّل مرتين لكل جلسة: مرة في `auth_provider.dart:330` ومرة أخرى في `main_shell.dart:22-29` — تأكدت من كلا الموقعين. كل نسخة تفتح قناة Realtime وتنفذ polling كل 5 دقائق بشكل مستقل.

**Solution:** جعل مراقبة الوصول مملوكة لمصدر واحد (Provider مركزي lifecycle-aware)، وإزالة النسخة المكررة من `MainShell`.

**Acceptance Criteria:**
- [ ] اختبار يثبت اشتراك Realtime واحد فقط لكل جلسة مستخدم

---

### QA-001
**Priority:** Low | **Difficulty:** Easy | **Est:** 30 دقيقة
**Files:** `tool/check_a11y.py`

**Description (تصحيح مهم):** `offline_player_center_button.dart` **يحتوي فعليًا** على `tooltip: tooltip` في `IconButton` — تحققت من الملف كاملًا. الفشل الحقيقي في `check-a11y` سببه باگ داخل السكربت نفسه: الـ regex الخاص بقبول متغير محلي (`L10N_TOOLTIP_RE`) يشترط أن يبدأ اسم المتغير بـ underscore (`_\w+`)، بينما الحقل هنا اسمه `tooltip` (بدون underscore)، فيفشل الفحص زورًا كـ "بلا tooltip".

**Solution:** توسيع الـ regex ليقبل أيضًا معاملات محلية تبدأ بحرف صغير عادي (مثل `tooltip: tooltip`)، مثال:
```python
r'|\w+\b(?!\s*[\'"])'   # plain field/param forwarding, not a string literal
```
مع اختبار وحدة للسكربت نفسه (test fixture) يمنع تكرار false positive مستقبلاً.

**Acceptance Criteria:**
- [ ] `make check-a11y` ينجح دون تعديل أي Widget فعلي
- [ ] اختبار للسكربت يغطي حالة "تمرير متغير محلي بدون underscore"

---

### QA-002
**Priority:** Low | **Difficulty:** Easy | **Est:** 2 ساعة
**Files:** `test/features/downloads/data/repositories/download_repository_impl_test.dart`

**Description:** الاختبار الحالي يهيّئ ويتحقق من `downloadManager.startDownload(...)`، بينما الكود الفعلي انتقل لاستدعاء `DownloadExecutionService` الذي يستدعي `downloadManager.startEncryptedDownload(...)` (مؤكَّد من `download_execution_service.dart:92`). **ملاحظة:** لم أُشغّل `flutter test` فعليًا (لا Flutter SDK في بيئة المراجعة) — هذا الاستنتاج مبني على قراءة الكود ومرجَّح بقوة وليس مؤكدًا بالتنفيذ.

**Solution:** تحديث الـ mocks لتعيد قيمة من `startEncryptedDownload` بدل `startDownload`، وإضافة تغطية صريحة لمسار الـ fallback والتنظيف عند الإلغاء (يغطي DL-001 أيضًا).

**Acceptance Criteria:**
- [ ] `flutter test` ينجح كاملًا في CI بعد التعديل — **يُنفَّذ فعليًا للتأكد قبل الإغلاق**

---

### LAYOUT-001
**Priority:** Low | **Difficulty:** Easy | **Est:** 15 دقيقة
**Files:** `lib/core/layout/adaptive_layout.dart`

**Description:** فرع الـ tablet يقارن `constraints.maxWidth >= Breakpoints.mobile` بدل `Breakpoints.tablet` (مؤكَّد سطر 20). المكوّن غير مُستخدَم حاليًا في أي شاشة (تحقق grep)، فهو خطر كامن لا عطل حالي.

**Solution:** تصحيح المقارنة إلى `Breakpoints.tablet` قبل أي استخدام مستقبلي للمكوّن على iPad/tablet.

**Acceptance Criteria:**
- [ ] اختبار widget يثبت أن نطاق عرض الـ tablet يُعيد `tablet` وليس `mobile`

---

## Roadmap

| المرحلة | المهام | الهدف | النتيجة |
|---|---|---|---|
| **Phase 1 — Security** | SEC-001 | إزالة خطر الانقطاع الكامل يوم 9 أكتوبر 2026 | اتصال Supabase مستقر بعد تجديد الشهادة + إنذار CI مبكر |
| **Phase 2 — Core Feature** | FEAT-001 | تفعيل التسجيل الفعلي بالمقررات | طالب يستطيع الانضمام لمقرر من الواجهة |
| **Phase 3 — Notifications** | NOTIF-001 → 002 → 003 | إعداد Push كامل على المنصتين | إشعار حقيقي يصل ويفتح الشاشة الصحيحة |
| **Phase 4 — Storage/Session Hygiene** | DL-001, AUTH-001, AUTH-002 | إزالة تسرب التخزين وتجميد Splash والازدواج | لا ملفات متروكة، لا شاشة معلّقة، مراقبة وصول واحدة |
| **Phase 5 — QA/CI Hardening** | QA-001, QA-002, LAYOUT-001 | جعل CI مصدر ثقة فعلي | `make check-all` و`flutter test` ينجحان بلا استثناءات مخفية |
| **Phase 6 — Field Acceptance** | — | اختبار قبول ميداني | تشغيل على Android حقيقي وiPhone/iPad حقيقي قبل الإصدار (لم يُنفَّذ بعد لعدم توفر بيئة بناء أصلية) |

---

## Production Checklist

- [ ] SEC-001 مغلقة ومختبرة على بناء staging
- [ ] FEAT-001: التسجيل بالمقرر يعمل فعليًا من الواجهة
- [ ] NOTIF-001/002/003: إشعار تجريبي وصل وفتح الشاشة الصحيحة على جهازين فعليين
- [ ] DL-001: لا ملفات `video/audio/*.tmp` متروكة بعد cancel/delete
- [ ] AUTH-001/002: لا Splash معلّق، مراقب وصول واحد فقط
- [ ] `flutter analyze` بدون تحذيرات (كان ناجحًا وقت المراجعة)
- [ ] `make check-all` ينجح فعليًا (بعد إصلاح QA-001 و QA-002)
- [ ] `flutter test` ينجح بالكامل (يُنفَّذ فعليًا وليس بالقراءة فقط)
- [ ] بناء APK/IPA فعلي واختبار ميداني على جهازين حقيقيين

---

## Final Verdict

🟠 **Needs More Work**

السبب: خطر زمني حرج ومحدد (شهادة TLS تنتهي خلال 59 يومًا وتقطع الاتصال بالكامل)، بالإضافة إلى خاصية أساسية معلَنة (التسجيل بالمقرر) معطّلة كليًا من الواجهة رغم جهوزية الطبقة الخلفية، ونظام Push غير مكتمل الإعداد على أي من المنصتين. هذه ليست تحسينات جودة بل حواجز أمام الاستخدام الفعلي، ويجب إغلاق Phase 1 وPhase 2 وPhase 3 قبل أي نقاش حول جاهزية الإصدار.
