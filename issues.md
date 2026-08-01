# خطة تحسين: سرعة التنزيل + الاستمرار بالخلفية + إصلاح صلاحية الروابط
**المشروع:** EduZone_App (`mi9092921-alt/EduZone_App`)
**النطاق:** `lib/features/downloads/` بالكامل — تحديدًا `download_manager.dart`, `download_repository_impl.dart`, `cleanup_scheduler.dart`
**المنهجية:** كل نقطة أدناه تحققت منها بالكود الفعلي عبر استنساخ مباشر للمستودع، وليست افتراضًا نظريًا.

---

## 1. ملخص تنفيذي

المشروع يحاول تنزيل فيديوهات كبيرة (مع تشفير AES-256-GCM بعد التنزيل) لتشغيلها Offline. أثناء المراجعة ظهرت **مشكلتان مستقلتان لكنهما متشابكتان**:

1. **التنزيل لا يستمر بالخلفية فعليًا** — لا foreground service، لا استخدام حقيقي لآلية خلفية موثوقة لملف التنزيل نفسه.
2. **صلاحية الروابط والمحتوى غير مُدارة بشكل صحيح** — وهذه مشكلة كانت ستبقى كامنة وغير ظاهرة طالما التنزيل قصير المدى، لكنها ستنفجر بمجرد حل المشكلة الأولى (لأن التنزيلات ستستمر لساعات، وهو بالضبط المدى الذي تنكشف فيه مشاكل الصلاحية).

**التوصية الجوهرية:** حل المشكلتين معًا في نفس الدفعة، وليس بالتتابع، لأن حل الأولى بمعزل عن الثانية سينتج ميزة تبدو تعمل في الاختبار القصير لكنها تفشل بصمت في الإنتاج مع أول تنزيل طويل فعليًا.

---

## 2. الوضع الحالي — نتائج التحقق الفعلي من الكود

### ✅ موجود وسليم (لا يحتاج تعديل)

| النقطة | الموقع | الحالة |
|---|---|---|
| `dio.download()` مع `onReceiveProgress` | `download_manager.dart:45,131` | ✅ |
| `receiveTimeout`/`sendTimeout` | `download_manager.dart:57-58` | ✅ 30 دقيقة / 5 دقائق |
| HTTP Range لاستئناف التنزيل | `download_manager.dart:38,127` | ✅ |
| نفس Dio instance (singleton) | `downloads_provider.dart:35` (`@Riverpod(keepAlive: true)`) | ✅ مؤكَّد أقوى مما بدا أول مرة |
| تنزيل متوازٍ فيديو+صوت (dual-track) مع تقدّم مُجمَّع | `download_repository_impl.dart:340-367` | ✅ |
| إشعارات تقدّم/اكتمال/فشل موجودة فعليًا | `download_notification_helper.dart` (قناة `download_channel_id`) | ✅ قابلة لإعادة الاستخدام مع أي حل جديد |
| منطق الحذف الحقيقي للتنزيلات المنتهية | `download_repository_impl.dart:781-798` (`cleanupExpiredDownloads`) | ✅ **مكتمل وصحيح** لكن غير موصول تلقائيًا (انظر البند التالي) |

### ❌ غائب أو معطوب (يحتاج تدخل)

| # | المشكلة | الموقع | الأثر |
|---|---|---|---|
| 1 | لا `<service>` ولا صلاحية `FOREGROUND_SERVICE` في AndroidManifest | `android/app/src/main/AndroidManifest.xml` | التنزيل يموت مع تصغير التطبيق/Doze mode |
| 2 | لا `UIBackgroundModes` في iOS Info.plist | `ios/Runner/Info.plist` | نفس المشكلة على iOS، أسوأ لأن iOS أكثر عدوانية في تعليق العمليات |
| 3 | `workmanager` **موجود فعليًا** كـ dependency لكن غير مستخدم للتنزيلات إطلاقًا | `pubspec.yaml` + `cleanup_scheduler.dart` | يُستخدم فقط لمهمة تنظيف دورية غير فعّالة (انظر #5) |
| 4 | `downloadWithResume()` مكررة وأضعف من `startDownload()` (بلا `CancelToken`) | `download_manager.dart:112-142` | كود ميت/مربك، لا يمكن إيقافه مؤقتًا |
| 5 | `CleanupScheduler.callbackDispatcher()` مجرد `debugPrint`, لا يستدعي أي حذف حقيقي | `cleanup_scheduler.dart:38-47` | لا إنفاذ تلقائي لسياسة الاحتفاظ بالمحتوى |
| 6 | الحذف الحقيقي (`cleanupExpiredDownloads`) موصول فقط بزر يدوي في UI | `downloads_screen.dart:266` | المستخدم لازم يفتح الشاشة ويضغط زر بنفسه |
| 7 | `expiresAt` (صلاحية المحتوى) لها fallback خاطئ لو رجع السيرفر `null` | `download_repository_impl.dart:141-142` | `?? DateTime.now().add(Duration(days: 3650))` — **10 سنين بدل 30 يوم** |
| 8 | لا يوجد تتبّع منفصل لـ"صلاحية رابط الخادم" (< 6 ساعات) عن "صلاحية المحتوى" (30 يوم/الاشتراك) | `CourseAccessResult` (`video_info.dart:244-261`) — حقل واحد فقط `expiresAt` | `resumeDownload()` يعيد استخدام رابط قديم بدون أي تحقق من انتهائه |

---

## 3. تحليل الخيارين لحل الاستمرار بالخلفية

| | **المسار أ — `flutter_foreground_task`** | **المسار ب — `background_downloader`** |
|---|---|---|
| يحل أندرويد | ✅ | ✅ |
| يحل iOS | ❌ | ✅ (native `URLSession` خلفي) |
| يستمر التنزيل حتى لو قُتل التطبيق يدويًا | جزئيًا (يعتمد على العملية نفسها تبقى حية) | ✅ (الإدارة تنتقل لنظام التشغيل: WorkManager/URLSession) |
| تعديل مطلوب على `DownloadManager` | بسيط (لا تغيير في محرك التنزيل، فقط رفع أولوية العملية) | متوسط (استبدال محرك Dio داخليًا، الواجهة العامة تبقى كما هي) |
| دعم استئناف تلقائي عند القطع | يدوي (كما هو حاليًا) | ✅ مدمج (`allowPause`) |
| Reconciliation بعد قتل التطبيق | يحتاج بناء يدوي | ✅ مدمج (`rescheduleMissingTasks`/`rescheduleKilledTasks`) |
| الجهد التقديري | أقل (يوم-يومين) | أكبر لكن يحل المشكلة فعليًا (4-6 أيام) |

**التوصية:** المسار ب، لأن المشروع cross-platform والفصل المعماري الحالي في `DownloadManager` (واجهة نظيفة معزولة) يجعل تكلفة الاستبدال محدودة نسبيًا — وهذا فعليًا يكافئ نقطة القوة المعمارية التي رُصدت في التدقيق الأصلي للمشروع.

---

## 4. تصميم إدارة الصلاحية (Expiry) — النوعان معًا

بناءً على التوضيح: **رابط الخادم < 6 ساعات**، و**صلاحية المحتوى المحلي = 30 يومًا أو حتى انتهاء الاشتراك، أيهما أقرب**.

### 4.1 فصل المفهومين في الموديل

```dart
// حاليًا: CourseAccessResult فيها حقل واحد فقط expiresAt يُستخدم للغرضين بالخطأ
class CourseAccessResult {
  final bool allowed;
  final DateTime? expiresAt; // ← هذا "صلاحية رابط الخادم" (< 6 ساعات) فعليًا
}

// المطلوب: تمييز صريح بين الاثنين عند تخزين التنزيل محليًا
```

### 4.2 حساب صلاحية المحتوى المحلي (إصلاح الـ fallback)

```dart
// بدل (الحالي - خاطئ):
final expiresAt =
    accessResult.expiresAt ?? DateTime.now().add(const Duration(days: 3650));

// المطلوب:
final maxRetention = DateTime.now().add(const Duration(days: 30));
final subscriptionExpiry = accessResult.expiresAt; // انتهاء الاشتراك، إن وُجد
final expiresAt = (subscriptionExpiry == null || subscriptionExpiry.isAfter(maxRetention))
    ? maxRetention
    : subscriptionExpiry;
```

### 4.3 تتبّع صلاحية رابط الخادم (حقل جديد، منفصل عن expiresAt أعلاه)

- إضافة `linkValidatedAt` (وقت آخر تحقق ناجح من `validateCourseAccess`) في قاعدة البيانات المحلية للتنزيل.
- قبل أي `resumeDownload()` **أو** كفحص دوري أثناء أي تنزيل نشط طويل:
```dart
final linkAge = DateTime.now().difference(linkValidatedAt);
if (linkAge > const Duration(hours: 5)) { // هامش أمان ساعة قبل الـ6 الفعلية
  // أعد استدعاء validateCourseAccess()، احصل على رابط جديد،
  // واستبدل الرابط في مهمة التنزيل الجارية/المتوقفة قبل الاستكمال
}
```

### 4.4 نقطة تحتاج بروتوتايب عملي (غير مؤكدة بعد)

هل `background_downloader` يسمح باستبدال رابط مهمة تنزيل قائمة/متوقفة مع الحفاظ على الملف الجزئي (`.tmp`) واستكمال البايتات عبر `Range` header كما هو معمول به حاليًا؟ أم يتطلب إلغاء المهمة القديمة وإنشاء مهمة جديدة (بنفس المسار) والاعتماد على أن الحزمة تكتشف الملف الجزئي الموجود تلقائيًا؟ **يجب التحقق عمليًا قبل الالتزام بالتصميم النهائي.**

---

## 5. ربط الحذف التلقائي الحقيقي (حل البندين #5 و#6)

`CleanupScheduler.callbackDispatcher()` يعمل في isolate منفصل بدون Riverpod container، فلا يمكنه استدعاء الـ usecase المرتبط بالـ UI مباشرة. الحل:

```dart
@pragma('vm:entry-point')
static void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _cleanupTask) {
      // استدعاء مباشر لطبقة البيانات (DataSource) وليس عبر Provider/UseCase:
      final localDs = DownloadLocalDataSource(/* تهيئة مباشرة لقاعدة البيانات */);
      final expired = await localDs.getExpiredDownloads();
      for (final d in expired) {
        await File(d.encryptedPath).delete().catchError((_) {});
        if (d.audioPath != null) {
          await File(d.audioPath!).delete().catchError((_) {});
        }
        await localDs.deleteDownload(d.id);
      }
      return Future.value(true);
    }
    return Future.value(false);
  });
}
```
مع الإبقاء على زر "تنظيف" اليدوي الحالي في `downloads_screen.dart` كخيار إضافي للمستخدم، وليس الاعتماد عليه وحده.

---

## 6. الخطة الكاملة بالترتيب

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Phase 0 — إصلاحات الصلاحية والتنظيف (لا تعتمد على تغيير محرك التنزيل)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  يوم 1:
   0.1 تصحيح fallback الـ30 يوم/الاشتراك في download_repository_impl.dart (قسم 4.2)
   0.2 فصل linkValidatedAt عن expiresAt في نموذج التنزيل المحلي (قسم 4.3)
   0.3 ربط CleanupScheduler بحذف حقيقي (قسم 5)
   0.4 اختبار وحدة: تأكيد أن expiresAt لا يتجاوز 30 يومًا أبدًا حتى لو
       رجع السيرفر null أو تاريخًا بعيدًا

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Phase 1 — إثبات المفهوم لمحرك التنزيل الجديد
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  يوم 2:
   1.1 بروتوتايب background_downloader: تنزيل فيديو، تصغير التطبيق فعليًا
       على جهاز حقيقي لأكثر من 6 ساعات (أو محاكاة الفارق الزمني)، والتأكد
       من أن الرابط يُجدَّد قبل الاستئناف
   1.2 التحقق من سلوك استبدال الرابط لمهمة قائمة (قسم 4.4) — نقطة القرار
       الحاسمة قبل المتابعة

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Phase 2 — استبدال محرك Dio داخل DownloadManager
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  يوم 3-4:
   2.1 تعديل download_manager.dart داخليًا فقط (نفس الواجهة العامة:
       startDownload/pauseDownload/cancelDownload/isDownloadActive)
   2.2 دمج فحص تجديد رابط الخادم (قسم 4.3) داخل startDownload/resumeDownload
   2.3 حذف/دمج downloadWithResume() المكررة أثناء نفس التعديل

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Phase 3 — إعدادات المنصات
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  يوم 5:
   3.1 Android: صلاحيتا FOREGROUND_SERVICE / FOREGROUND_SERVICE_DATA_SYNC
       + تفعيل Config.runInForeground
   3.2 iOS: UIBackgroundModes (fetch/processing) في Info.plist
       + معالج handleEventsForBackgroundURLSession في AppDelegate.swift
   3.3 دمج التقدّم/الإشعارات مع DownloadNotificationHelper الموجود
       (قناة download_channel_id نفسها) بدل نظام إشعارات الحزمة المدمج

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Phase 4 — إعادة التزامن بعد قتل التطبيق + الاختبار
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  يوم 6:
   4.1 استدعاء rescheduleMissingTasks/rescheduleKilledTasks في
       AppInitializer.init() لتصحيح صفوف 'downloading' العالقة
   4.2 اختبار تكامل شامل:
       - تنزيل → تعليق التطبيق > 6 ساعات → تحقق من تجديد الرابط تلقائيًا
       - تنزيل → قتل التطبيق يدويًا → إعادة فتح → تحقق من استئناف/تصحيح الحالة
       - تنزيل فيديو ينتهي اشتراكه أثناء التنزيل → تحقق من توقف/رفض صحيح
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**إجمالي تقديري:** ~6 أيام عمل فعلية (لا تشمل مراجعة الكود/QA)، منها يوم واحد فقط لا يعتمد على قرار المكتبة (Phase 0 يمكن تنفيذه ودمجه فورًا بشكل مستقل).

---

## 7. الأولويات (للتتبع في نظام إدارة المهام)

```
🔴 Critical
  - Phase 0.1: fallback الـ30 يوم (باگ أمني/تجاري فعلي، مستقل تمامًا عن أي شيء آخر)
  - Phase 3.1/3.2: لا استمرار بالخلفية إطلاقًا حاليًا على أي منصة

🟠 High
  - Phase 0.2/0.3: الحذف التلقائي غير مُنفَّذ فعليًا
  - Phase 4: تجديد رابط الخادم — بدونه، الاستمرار بالخلفية سيفشل بصمت بعد 6 ساعات

🟡 Medium
  - Phase 2.3: تنظيف downloadWithResume() المكررة
```

---

## ملاحظة أخيرة

Phase 0 بالكامل **لا يعتمد على قرار background_downloader مقابل flutter_foreground_task** — يمكن تنفيذه ودمجه فورًا بمعزل عن باقي الخطة، وهو يحل باگًا تجاريًا حقيقيًا (صلاحية 10 سنين بدل 30 يومًا) بغض النظر عن أي شيء آخر. أوصي بالبدء فيه بينما يجري البروتوتايب (Phase 1) بالتوازي.