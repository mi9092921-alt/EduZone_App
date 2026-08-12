# ملاحظات المراجعة اليدوية — encryption_service.dart و offline_player_wrapper.dart

## 1) تصحيح مهم: وصف مهمة رفع التغطية لا يطابق الكود الفعلي

مهمة رفع التغطية التي أرفقتها تقول إن إصلاح علة الصوت الصامت في التنزيلات ثنائية المسار
استُبدل بـ:
```dart
player.setAudioTrack(AudioTrack.uri(...))
```

**هذا غير صحيح بالنظر إلى الكود الفعلي حاليًا.** ما يوجد فعليًا في
`lib/features/downloads/presentation/widgets/offline_player_wrapper.dart` (دالة
`_initializePlayer`) هو:

```dart
final platform = player.platform;
if (platform is NativePlayer) {
  await platform.setProperty('audio-file', _tempAudioDecryptedFile!.path);
  await platform.setProperty('aid', '1'); // فرض اختيار المسار الصوتي الجديد
}
```

أي أنه يستخدم `NativePlayer.setProperty` (خاصية mpv الأصلية) مباشرة، وليس
`Player.setAudioTrack(AudioTrack.uri(...))`. الكود يحتوي تعليقًا صريحًا يشرح لماذا:
`Media(..., extras: {...})` لا يُمرَّر لمحرك mpv فعليًا، وهذا كان سبب العلة الأصلية —
لكن الحل النهائي المُطبَّق هو `setProperty` وليس `setAudioTrack`. **إذا كتبتَ اختبارًا
يتحقق من استدعاء `setAudioTrack`، فسيفشل دائمًا لأن هذه الدالة لا تُستدعى في الكود
الحالي إطلاقًا.** أي اختبار regression لهذه العلة يجب أن يتحقق من `setProperty('audio-file', ...)`
و`setProperty('aid', '1')` على `NativePlayer`، لا من `setAudioTrack`.

## 2) لماذا لا يوجد اختبار جاهز لمنطق `setProperty` في هذا التسليم

`Player()` من حزمة `media_kit` كائن حقيقي يفتح موارد أصلية (native/platform channel) عند
الإنشاء — وليس واجهة (interface) قابلة للـ mock بسهولة، و`player.platform` لا يُصبح
`NativePlayer` فعليًا إلا بعد تهيئة المحرك الأصلي (libmpv)، وهو غير متاح في بيئة
`flutter test` العادية بدون جهاز/محاكي حقيقي. لذلك **لم أكتب اختبار widget يستدعي
`OfflinePlayerWrapper` فعليًا ويتحقق من نداءات `setProperty`** — لأنه سيفشل بيئيًا
(missing native library) بغض النظر عن صحة منطق الكود، وليس هذا ما طلبتَه (اختبار جاهز
للنسخ ينجح فعليًا).

**الخيار العملي إن أردتَ تغطية حقيقية لهذا المسار مستقبلًا (اقتراح فقط، لم يُطبَّق):**
استخلاص قرار "هل هذا تنزيل ثنائي المسار ومساري الملفات المؤقتة" ومنطق "إرفاق المسار
الصوتي" إلى كائن/دالة صغيرة منفصلة قابلة للحقن (مثل `AudioTrackAttacher` abstract class)،
بحيث يصبح بالإمكان استبدالها بـ fake في الاختبار دون الحاجة لتشغيل `Player` حقيقي. لم
أطبّق هذا التعديل على `lib/` لأنه تغيير معماري (ولو بسيط) وليس إصلاح علة مؤكدة — حسب
قواعدكم الصريحة في مهمة التغطية ("لا تعدّل كود إنتاجي إلا لإصلاح علة حقيقية")، فالأصوب
أن يكون قرارًا واعيًا منكم قبل التنفيذ.

## 3) علة توثيق حقيقية اكتُشفت أثناء الكتابة (وليست في التقرير الأصلي)

`EncryptionService.encryptBytes()` يولّد `IV` عشوائيًا داخليًا لكنه **لا يعيده للمستدعي**
— يُعيد فقط `Encrypted` (النص المشفر). بينما `decryptBytes()` يتطلب نفس الـ `IV` كمعامل.
النتيجة: **لا توجد طريقة صحيحة لإقران استدعاء `encryptBytes()` لاحقًا بـ `decryptBytes()`**
عبر الواجهة العامة لهذه الخدمة فقط — الـ IV يضيع بمجرد عودة `encryptBytes()`.

- **الخطر الفعلي حاليًا: منخفض** — تحققتُ عبر grep أن `encryptBytes`/`decryptBytes` غير
  مستخدمتين في أي مكان بـ `lib/` خارج ملف الخدمة نفسه (الاستخدام الفعلي في
  `edz_local_proxy.dart` يستدعي `encrypter.decryptBytes()` من حزمة `encrypt` مباشرة،
  وليس عبر غلاف الخدمة).
- **لكن يجب معالجتها قبل استخدام هاتين الدالتين في أي ميزة جديدة**، وإلا فستبدو كأنها
  واجهة APl صحيحة بينما هي غير قابلة للاستخدام كزوج متكامل.
- **الإصلاح المقترح:** تغيير توقيع `encryptBytes` ليُعيد `({Encrypted data, IV iv})` بدل
  `Encrypted` فقط، أو جعله يقبل `IV` كمعامل يزوّده المستدعي (بدل توليده داخليًا) — بنفس
  نمط ما تفعله `_encryptFileOnWorker` بالفعل لكل chunk.

ملف الاختبار المرفق (`encryption_service_security_test.dart`) يوثّق هذا السلوك صراحة
باختبار مخصص بدل تجاهله، ويختبر المسار الصحيح فعليًا (`buildEncrypter` + `IV` يتتبعه
المستدعي) بدل الاعتماد على الغلاف المعطوب.

## ملخص الملفات المرفقة

| الملف | الوجهة | يغطي |
|---|---|---|
| `encryption_service_security_test.dart` | `test/core/services/encryption_service_security_test.dart` | إدارة المفاتيح (secure storage mock)، كشف التلاعب/tag GCM، مفتاح خاطئ، buildEncrypter+decryptBytes، أخطاء buildIndexForExistingFile، calculateChecksum، ملف فارغ |
| `offline_playback_service_failure_test.dart` | `test/core/services/offline_playback_service_failure_test.dart` | مسارات الفشل: مفتاح غير موجود (preparePlayableFile/startStreamingProxy)، تنظيف الملف الجزئي عند فشل فك التشفير، cleanupTempFile على ملف غير موجود |

كلا الملفين لا يحتاجان أي تعديل على `lib/` — فقط انسخهما إلى المسارين المذكورين وشغّل:
```bash
flutter test test/core/services/encryption_service_security_test.dart -r compact
flutter test test/core/services/offline_playback_service_failure_test.dart -r compact
```





وجدت الدليل التقني الكامل. المشكلة موجودة بدقة في `lib/features/downloads/presentation/widgets/offline_player_wrapper.dart`، دالة `_initializePlayer`، وهي **ليست علة عشوائية بل خلل في اختيار الـ API نفسه**. إليك التفصيل بالدليل:

## أين المشكلة بالضبط

عند تنزيل فيديو بجودة عالية (مسار فيديو ومسار صوت منفصلَين)، الكود يفعل هذا بعد `player.open()`:

```dart
final platform = player.platform;
if (platform is NativePlayer) {
  try {
    await platform.setProperty('audio-file', _tempAudioDecryptedFile!.path);
    await platform.setProperty('aid', '1');
  } catch (e) {
    // غير قاتل: الفيديو يظل يعمل، لكن بصمت — يطابق (لا يُسوّئ) السلوك السابق
    if (kDebugMode) debugPrint('...failed to attach external audio track — $e');
  }
}
```

## الدليل: هذه ليست الطريقة الرسمية لإرفاق مسار صوتي خارجي في media_kit

رجعت لتوثيق حزمة `media_kit` الرسمية على pub.dev (media_kit 1.2.6، نفس الإصدار المستخدم في `pubspec.yaml`)، ووجدت أن `Player` نفسه يوفّر دالة مخصصة تمامًا لهذا الغرض:

```
setAudioTrack(AudioTrack track) → Future<void>
Sets the current AudioTrack for audio output.
```

والمثال الرسمي في التوثيق **يطابق حرفيًا** الحالة عندك (تحميل مسار صوتي خارجي عبر URI):

```dart
await player.setAudioTrack(
  AudioTrack.uri(
    'https://.../audio-track.mp4',
    title: 'English',
    language: 'en',
  ),
);
```

بمعنى آخر: media_kit **يوفّر API رسمي موثّق ومُخصَّص بالضبط** لحالة "أرفق ملف صوت خارجي بفيديو مفتوح بالفعل" — وهذا هو نفس الوصف الذي جاء في مهمة رفع التغطية التي أرفقتها سابقًا. لكن الكود المُطبَّق فعليًا **لا يستخدم هذا الـ API إطلاقًا**، ويلجأ بدلًا منه إلى تعديل خاصية mpv منخفضة المستوى (`setProperty('audio-file', ...)`) عبر `NativePlayer` مباشرة — وهي خاصية موثّقة في mpv نفسه أساسًا كـ **خيار تحميل عند بدء تشغيل الملف** (`--audio-file=<file>` عبر سطر الأوامر)، وليست مضمونة الاعتماد كخاصية "ساخنة" (hot-set) تُرفِق مسارًا صوتيًا بملف مفتوح ومُشغَّل بالفعل — وهذا بالضبط ما يحدث هنا: `setProperty` يُستدعى **بعد** `player.open()`.

## لماذا لا يظهر أي خطأ للمستخدم رغم فشل الصوت

هنا العلة الثانية الأخطر: الاستدعاء بالكامل ملفوف في `try/catch` يبتلع أي فشل **بصمت تام في نسخة Production**:

```dart
} catch (e) {
  if (kDebugMode) debugPrint('...'); // فقط في وضع debug
}
```

أي أنه حتى لو فشل `setProperty` (لأي سبب — توقيت، عدم دعم المنصة، القيمة غير مقبولة كـ "خاصية ساخنة")، **المستخدم لا يرى أي رسالة خطأ إطلاقًا** — فقط فيديو يعمل بصريًا لكن بدون صوت، وهو **بالضبط** ما وصفته. هذا يفسر لماذا العلة "غير مرئية" في الاختبار السطحي: الفيديو يفتح، يشتغل، الأزرار تعمل، لا يوجد Exception يظهر — فقط صمت.

## الإصلاح المقترح (بنفس نمط الكود الموجود بالفعل في نفس الملف)

استبدال منطق `setProperty` بالـ API الرسمي:

```dart
if (isDualTrack && _tempAudioDecryptedFile != null) {
  try {
    await player.setAudioTrack(
      AudioTrack.uri(_tempAudioDecryptedFile!.path),
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('OfflinePlayerWrapper: failed to attach external audio track — $e');
    }
    // يُستحسن أيضًا: إظهار رسالة/أيقونة "بدون صوت" للمستخدم بدل الصمت الكامل حتى في release
  }
}
```

(لاحظ أن باقي الكود في نفس الملف يمرر المسارات كـ raw path بدون `file://` prefix لـ `Media()`، لذا الأرجح أن `AudioTrack.uri()` يقبل نفس الشكل بلا حاجة لتحويل).

## درجة الثقة

هذا التشخيص مبني على: (1) قراءة الكود الفعلي في المستودع، (2) توثيق media_kit الرسمي الذي يوضح `setAudioTrack(AudioTrack.uri(...))` كطريقة رسمية موثقة لنفس السيناريو تحديدًا، (3) طبيعة mpv المعروفة لخاصية `audio-file` كخيار تحميل وليس إرفاقًا ساخنًا. **لم أستطع تشغيل التطبيق فعليًا على جهاز لتأكيد أن `setAudioTrack` يحل المشكلة 100%** (بيئتي لا تحتوي Flutter SDK)، لذا أنصح بتجربته على جهاز حقيقي مع تنزيل ثنائي المسار قبل الدمج النهائي.

تحب أطبّق هذا التعديل فعليًا في نسخة من الملف وأجهزه لك جاهزًا للنسخ، أو أكتب لك اختبار regression بديل يتحقق من استدعاء `setAudioTrack` بدل `setProperty` (بنفس قيود `NativePlayer` التي شرحتها سابقًا)؟
