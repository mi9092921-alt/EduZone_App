# تفعيل نظام الحماية (SecurityService / freeRASP) للإنتاج

هذا الملف يوثّق خطوات تفعيل `SecurityService.init()` بشكل صحيح في بيئة الإنتاج، بعد أن كان معطّلًا سابقًا.

## 1. لماذا كان معطّلًا؟

`SecurityService.init()` يشغّل `Talsec.instance.start(...)` (freeRASP)، والذي يتطلب قيمًا حقيقية خاصة بشهادة توقيع الإصدار (Android) وTeam ID (iOS) لكي يعمل الكشف عن التلاعب (repackaging) بشكل صحيح. قبل توفر هذه القيم، تفعيل الخدمة كان سيُنتج سلوكًا غير موثوق (false positives أو false negatives).

## 2. الخطوات

### أ. إنشاء keystore إنتاج (إن لم يكن موجودًا)

راجع أولًا إصلاح توقيع الإصدار (Critical #2 في تقرير التدقيق) — يجب أن يكون لديك keystore إنتاج حقيقي قبل حساب SHA-256.

### ب. استخراج SHA-256 hash للتوقيع

```bash
keytool -list -v -keystore <path-to-release>.keystore -alias <alias> | grep SHA256
```
انسخ القيمة بصيغة hex، ثم حوّلها لـ Base64 (الصيغة التي يتوقعها freeRASP):
```bash
echo -n "<HEX_WITHOUT_COLONS>" | xxd -r -p | base64
```

### ج. ملء `.env.security`

انسخ `.env.security.example` إلى `.env.security` (هذا الملف الأخير مُستثنى من Git تلقائيًا عبر `.gitignore`) واملأ القيم الحقيقية:

```
SECURITY_ANDROID_SIGNING_HASH=<القيمة من الخطوة ب>
SECURITY_IOS_TEAM_ID=<Apple Developer Team ID>
```

### د. البناء بالقيم الحقيقية

```bash
flutter build apk --release --dart-define-from-file=.env.security
flutter build ipa --release --dart-define-from-file=.env.security
```

بدون `--dart-define-from-file=.env.security`، البناء في وضع release سيفشل عمدًا (`StateError`) بدل أن يُشحن بإعدادات فارغة غير فعّالة — راجع `lib/core/security/freerasp_config.dart`.

### هـ. اختبار على جهاز حقيقي

اختبر على جهاز Android حقيقي مُعطَّل جذريًا (rooted) أو عبر محاكي — تحقق من ظهور السجل `[SECURITY][THREAT DETECTED]` أو تفعيل `killAppHandler`/`exit(0)` حسب إعداد `SECURITY_ENFORCE_THREAT_TERMINATION`.

## 3. تفعيل إنهاء التطبيق تدريجيًا (Rollout)

لا تُفعّل `SECURITY_ENFORCE_THREAT_TERMINATION=true` من أول إصدار. الخطوات الموصى بها:

1. أصدر نسخة بـ `SECURITY_ENFORCE_THREAT_TERMINATION=false` (تسجيل فقط، بدون إنهاء).
2. راقب جدول `security_incidents` في Supabase لمدة أسبوع على الأقل، تأكد من معدل false-positive منخفض.
3. فعّل `SECURITY_ENFORCE_THREAT_TERMINATION=true` في الإصدار التالي.

## 4. iOS — عمل غير مكتمل بعد

`SecurityService.killAppHandler` نقطة حقن اختيارية تسمح بالانتقال لشاشة "الجهاز غير آمن" بدل `exit(0)` (المستخدَم افتراضيًا لأندرويد فقط الآن). **لم يُربط بعد بأي شاشة فعلية** — يحتاج الفريق لربطه بمسار في `AppRouter` (مثال في تعليق الكود داخل `security_service.dart`). حتى ذلك الحين، سيُسجَّل تحذير في السجلات على iOS دون إنهاء فعلي للتطبيق عند اكتشاف تهديد.
