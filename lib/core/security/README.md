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

### ج. ملء `.env`

أضِف القيم إلى ملف `.env` الوحيد (مُستثنى من Git تلقائيًا عبر `.gitignore` — القالب `.env.example`)：

```
SECURITY_ANDROID_SIGNING_HASH=<القيمة من الخطوة ب>
SECURITY_IOS_TEAM_ID=<Apple Developer Team ID>
```

### د. البناء بالقيم الحقيقية

```bash
flutter build apk --release --dart-define-from-file=.env
flutter build ipa --release --dart-define-from-file=.env
```

بدون تزويد مفاتيح `SECURITY_*` داخل `.env`، البناء في وضع release سيفشل عمدًا (`StateError` عند التشغيل) بدل أن يُشحن بإعدادات فارغة غير فعّالة — راجع `lib/core/security/freerasp_config.dart`.

### هـ. اختبار على جهاز حقيقي

اختبر على جهاز Android حقيقي مُعطَّل جذريًا (rooted) أو عبر محاكي — ظهور السجل `[SECURITY][THREAT DETECTED]` متوقع في الحالتين. أما تفعيل `killAppHandler`/`exit(0)` فيقتصر على بناء release على جهاز حقيقي (بناء debug لا يُنهي التطبيق أبدًا مهما كان إعداد `SECURITY_ENFORCE_THREAT_TERMINATION`، حمايةً من قفل الحساب على المحاكي أثناء التطوير).

## 3. تفعيل إنهاء التطبيق تدريجيًا (Rollout)

الافتراضي في بناء release هو الإنهاء (`true`); بناء debug لا يُنهي أبدًا. لصيغة تسجيل فقط (بدون إنهاء) يجب تعيين `SECURITY_ENFORCE_THREAT_TERMINATION=false` صراحةً في `.env`:

1. لصيغة أول إصدار بتسجيل فقط، عيّن `SECURITY_ENFORCE_THREAT_TERMINATION=false`.
2. راقب جدول `security_incidents` في Supabase لمدة أسبوع على الأقل، تأكد من معدل false-positive منخفض.
3. أزِل التعيين (أو عيّن `true`) في الإصدار التالي لتفعيل الإنهاء.

## 4. iOS — عمل غير مكتمل بعد

`SecurityService.killAppHandler` نقطة حقن اختيارية تسمح بالانتقال لشاشة "الجهاز غير آمن" بدل `exit(0)` (المستخدَم افتراضيًا لأندرويد فقط الآن). **لم يُربط بعد بأي شاشة فعلية** — يحتاج الفريق لربطه بمسار في `AppRouter` (مثال في تعليق الكود داخل `security_service.dart`). حتى ذلك الحين، سيُسجَّل تحذير في السجلات على iOS دون إنهاء فعلي للتطبيق عند اكتشاف تهديد.
