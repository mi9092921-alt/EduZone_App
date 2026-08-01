# دليل المساهمة — EduZone Student App

هذا الملف يوثّق القرارات المعمارية والقواعد اللي لازم تُتّبع عند التعديل على
المشروع، عشان نتجنّب تكرار مشاكل رُصدت أثناء المراجعات التقنية السابقة.

## 1. البنية المعمارية (Clean Architecture / Feature-first)

كل ميزة داخل `lib/features/<feature_name>/` لازم تتبع الطبقات الأربع:

```
feature_name/
├── domain/          # Entities, Repository interfaces (abstract), UseCases
├── data/            # DataSources, Models, Repository implementations
├── application/      # خدمات تنسيقية (orchestration) بين عدة use cases
└── presentation/     # Providers (Riverpod), Screens, Widgets
```

### ✅ القاعدة الذهبية
**طبقة الـ `presentation` (الـ Notifiers/Providers) لا يجوز أن تستدعي
`DataSource` مباشرة.** يجب أن تمر عبر `Repository` (الواجهة المجرّدة في
`domain/repositories/`) أو عبر `UseCase` مخصص.

```dart
// ❌ خطأ — تجاوز طبقة الـ Repository
final appUser = await _remoteDataSource.login(email, password);

// ✅ صحيح
final appUser = await ref.read(loginUserUseCaseProvider).call(email, password);
// أو على الأقل عبر الـ repository مباشرة
final appUser = await ref.read(authRepositoryProvider).login(email, password);
```

إذا أضفت دالة جديدة في `DataSource` (مثل عملية telemetry بسيطة)، أضفها أولاً
لواجهة `Repository` المقابلة — حتى لو كان التنفيذ في `RepositoryImpl` مجرد
تفويض مباشر (pass-through) للـ DataSource. هذا يحافظ على قابلية اختبار
الـ `domain` بمعزل عن Supabase/الشبكة.

## 2. تنظيف الحالة عند تسجيل الخروج

أي provider جديد يحمل بيانات خاصة بالمستخدم الحالي (وليس بيانات عامة/ثابتة)
**يجب** إضافته إلى `_invalidateAllUserProviders()` في
`lib/features/auth/presentation/providers/auth_provider.dart`. تجاهل هذه
الخطوة يسبب تسرّب بيانات جلسة سابقة عند تبديل المستخدمين على نفس الجهاز.

## 3. الصور من الشبكة

استخدم دائمًا `AppNetworkImage` (في `lib/shared/widgets/app_network_image.dart`)
لعرض أي صورة من الشبكة. **لا تستخدم `Image.network()` أو `CachedNetworkImage`
مباشرة** في شاشات جديدة — `AppNetworkImage` يضمن سياسة كاش موحّدة عبر التطبيق.

## 4. الأمان — تعديلات حساسة

أي تعديل على الملفات التالية يتطلب مراجعة من مالك الأمان (راجع
`.github/CODEOWNERS`) قبل الدمج:
- `lib/core/security/**`
- `lib/core/network/supabase_client.dart`
- `lib/core/services/encryption_service.dart`
- `android/app/build.gradle.kts` (خصوصًا `signingConfig` و `buildTypes`)

لا تُعطّل خطوات `SecurityService.init()` (freeRASP، منع screenshot، منع
مشاركة الشاشة) بدون توثيق السبب في الـ PR description، ولا تترك القيم
الإعدادية (`kExpectedSignatureHash`, `kIosTeamId` في `freerasp_config.dart`)
كـ placeholders في أي فرع يُدمج بـ `main`.

## 5. Linting والتنسيق

المشروع يستخدم `flutter_lints` + قواعد إضافية في `analysis_options.yaml`
(`avoid_print`, `cancel_subscriptions`, `close_sinks`, إلخ). قبل فتح PR:

```bash
flutter analyze
flutter test
```

يجب أن يمرّ الاثنان بدون أخطاء. الـ CI (`ci.yml`) سيرفض الدمج تلقائيًا إن لم يمرّا.

## 6. نمط تسمية الفروع

```
feature/<وصف-مختصر>     # ميزة جديدة
fix/<وصف-مختصر>          # إصلاح خطأ
security/<وصف-مختصر>     # تعديل أمني (يتطلب مراجعة CODEOWNERS)
chore/<وصف-مختصر>        # صيانة، ترقية حزم، إلخ
```

## 7. الترقيات (Dependency Upgrades)

راجع `.github/dependabot.yml` — الحزم المستبعدة من الترقية التلقائية
(`freerasp`, `encrypt`, `flutter_secure_storage`, `supabase_flutter`) تتطلب
ترقية يدوية مدروسة مع اختبار كامل، لأنها ترتبط مباشرة بالأمان أو الجلسات.

عند ترقية أي حزمة بإصدار رئيسي (major)، افتح PR منفصل لكل حزمة أو مجموعة
حزم مترابطة — لا تجمع عدة ترقيات غير مرتبطة في PR واحد.

## 8. الاختبارات

كل ميزة جديدة أو إصلاح خطأ يجب أن يُرفق باختبار مقابل في `test/` بنفس بنية
`lib/`. الأولوية القصوى للاختبارات في `lib/core/security/` و
`lib/features/auth/` نظرًا لحساسيتهما.
