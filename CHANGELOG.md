# سجل التغييرات (Changelog)

جميع التغييرات المهمة في هذا المشروع تُوثَّق هنا.

الصيغة مبنية على [Keep a Changelog](https://keepachangelog.com/ar/1.0.0/)،
والمشروع يتّبع [Semantic Versioning](https://semver.org/lang/ar/).

## [Unreleased]

### Added / Fixed
- **Security**: ربط `SecurityService.killAppHandler` بمسار الشاشة المقفلة (`AppRoutes.locked`) عند اكتشاف تهديد أمني.
- **L10n**: إضافة الترجمة العربية لمفتاح `searchCourses` ("ابحث عن الكورسات") في `app_ar.arb`.
- **Logging**: تقييد طباعة أحداث التنقل في `AppNavigatorObserver` على وضع التطوير فقط (`kDebugMode`).
- **Chore**: إضافة ملفات المخرجات المؤقتة لـ `.gitignore` واستبعادها من تتبع Git.

### Security
- ربط معالج إنهاء التطبيق `killAppHandler` لضمان التفاعل الصحيح مع التهديدات الأمنية على iOS وأندرويد.

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
- بناء الإصدار (Release) لأندرويد موقّع بمفتاح Debug مؤقتًا بانتظار keystore إنتاج.
- **CI — خطوة "Build APK (Staging)"**: هذه الخطوة في `.github/workflows/ci.yml` تُتخطّى عمدًا (`exit 0`) إذا لم يكن ملف `.env.staging` متوفرًا في بيئة الـ Runner، وذلك بشكل مقصود لتفادي فشل الـ CI للمساهمين الذين لا يملكون صلاحية الوصول لأسرار المشروع (Fork/Contributor PRs). **الأثر**: نجاح job الـ `quality` في CI **لا يعني** أن بناء الـ APK الفعلي (Staging) قد تم التحقق منه؛ فقط يعني نجاح `flutter analyze` و`flutter test`. للتحقق الفعلي من قابلية البناء، يجب تفعيل GitHub Secret باسم `ENV_STAGING` (محتوى ملف `.env.staging`) في إعدادات المستودع (`Settings → Secrets and variables → Actions`)، ثم تعديل الخطوة لإعادة توليد الملف من السر قبل خطوة البناء.

---

## كيف تضيف إدخالًا جديدًا

عند فتح PR يغيّر سلوكًا ملحوظًا، أضف سطرًا تحت `[Unreleased]` بالقسم المناسب:
`Added` (ميزة جديدة) / `Changed` (تعديل سلوك موجود) / `Fixed` (إصلاح خطأ) /
`Security` (إصلاح أمني) / `Removed` (إزالة ميزة). عند إصدار نسخة جديدة، انقل
محتوى `[Unreleased]` لقسم جديد بترقيم الإصدار وتاريخه، واترك `[Unreleased]`
فارغًا للتغييرات القادمة.
