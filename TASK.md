# مهام للوكيل — تنظيف Dependabot PRs (EduZone_App)

## قواعد صارمة (تنطبق على كل مهمة تحت، اقرأها قبل أي حاجة)

1. **لا تلخّص أي ناتج أمر.** الصق الـ output الخام كامل.
2. **لا تفترض النجاح أبدًا.** المهمة "تمت" فقط لو تحقق شرط "Verify" المكتوب حرفيًا تحته — مش لو "غالبًا نجح".
3. **لو الناتج الفعلي مختلف عن المتوقع، توقف فورًا.** لا تحاول تصلّح المشكلة بنفسك، ولا تكمل للمهمة اللي بعدها، ولا تخمن السبب. اعرض الـ output الخام واسأل.
4. **PR واحد في كل مرة.** ممنوع تدمج PR جديد قبل ما تتأكد إن اللي قبله اتدمج فعليًا (`merged` status)، مش بس إنك بعتت الأمر.
5. **ممنوع تعمل أي `git push` مباشر على `main`.** كل تعديل هنا هو دمج PR موجود بالفعل عبر `gh pr merge` فقط — مفيش فروع جديدة مطلوبة في المهام دي.
6. **قبل ما تبدأ أي مهمة، ارجع لجدول "الحالة المتوقعة" تحت وتأكد إن رقم الـ PR وعنوانه متطابقين.** لو مش متطابقين، توقف واعرض الفرق — متكملش بتخمين إن الأرقام "غالبًا لسه صحيحة".
7. **كل الـ 12 PR اتفتحوا بين 12:17 و12:33Z يوم 2026-08-01 — يعني قبل ما PR #13 يتدمج (13:05:07Z)، اللي أضاف `tool/check_a11y.py`.** ده معناه فرع كل PR منهم مبني على نسخة قديمة من `main` مفيهاش الملف ده، فخطوة `Accessibility Guard` في CI هتفشل لأي واحد فيهم — مش بسبب التحديث نفسه اللي الـ PR بيعمله. **لازم تعمل `gh pr update-branch <N>` قبل أي `gh pr checks <N>` لأي PR في الملف ده، من غير استثناء، ولا تشخّص فشل `Accessibility Guard` كمشكلة حقيقية في الحزمة.**

---

## الخطوة صفر — تحقق من الحالة الحالية قبل أي تعديل

```bash
gh pr list --label dependencies --json number,title,mergeable
```

**Verify:** لازم يظهر بالظبط الـ 12 PR دول (رقم وعنوان متطابقين حرفيًا):

| # | Title |
|---|---|
| 12 | chore(deps): bump flutter_local_notifications from 21.0.0 to 22.2.0 |
| 11 | chore(deps): bump youtube_player_flutter from 9.1.3 to 10.0.1 |
| 10 | chore(deps): bump geolocator from 13.0.4 to 14.0.2 |
| 9 | chore(deps): bump device_info_plus and package_info_plus |
| 8 | chore(deps): bump the minor-and-patch group with 21 updates |
| 7 | chore(android): bump com.android.application from 8.11.1 to 9.3.1 in /android |
| 6 | chore(android): bump gradle-wrapper from 8.14 to 9.6.1 in /android |
| 5 | chore(android): bump com.android.tools:desugar_jdk_libs from 2.1.4 to 2.1.5 in /android |
| 4 | chore(android): bump org.jetbrains.kotlin.android from 2.2.20 to 2.4.10 in /android |
| 3 | chore(ci): bump actions/upload-artifact from 4 to 7 |
| 2 | chore(ci): bump actions/checkout from 4 to 7 |
| 1 | chore(ci): bump codecov/codecov-action from 4 to 7 |

**لو القائمة فيها PR إضافي، أو رقم ناقص، أو عنوان مختلف: توقف. اعرض القائمة الفعلية كاملة واسأل قبل أي خطوة تانية.**

---

## المرحلة 1 — CI Actions bumps (#1, #2, #3) — لا تحتاج flutter build إطلاقًا

هذه الثلاثة بتعدّل `.github/workflows/*.yml` بس، مش كود التطبيق. الاختبار الوحيد المطلوب هو نجاح الـ CI checks على نفس الـ PR (لأن الـ run بتاعه بيستخدم فعليًا نسخة الـ workflow المعدّلة). **رقم واحد بالمرة، بنفس ترتيب الاعتماد المنطقي: ابدأ بالأقدم رقمًا (#1) ثم #2 ثم #3.**

### قالب المهمة (استبدل `<N>` بـ 1 ثم 2 ثم 3، بالترتيب، ومتبدأش رقم قبل ما اللي قبله يبقى `MERGED`)

```bash
gh pr update-branch <N>
```
**Verify:** الناتج يحتوي على تأكيد إن الفرع اتحدّث (أو رسالة إنه محدّث بالفعل). لو ظهر تعارض (merge conflict)، توقف واعرضه.

```bash
gh pr checks <N> --watch
```
**Verify:** كل الـ checks ✔، مفيش ولا ❌ واحد.

```bash
gh pr merge <N> --squash --delete-branch
gh pr view <N> --json state --jq '.state'
```
**Verify:** يطبع `MERGED` بالظبط.

---

## المرحلة 2 — دمج مباشر (patch/minor فقط، مخاطرة منخفضة)

### TASK — PR #5 (desugar_jdk_libs، patch bump)
```bash
gh pr update-branch 5
gh pr checks 5 --watch
```
**Verify:** كل الـ checks لازم تظهر ✔ (مفيش ولا ❌ واحد). لو ظهر ❌ توقف.

```bash
gh pr merge 5 --squash --delete-branch
```
**Verify:** الناتج لازم يحتوي على الكلمة `Merged`. تأكد بأمر إضافي:
```bash
gh pr view 5 --json state --jq '.state'
```
**Verify:** لازم يطبع `MERGED` بالظبط.

### TASK — PR #8 (مجموعة minor-and-patch، ~22 حزمة)
نفس خطوات مهمة PR #5 فوق بالظبط لكن برقم `8` بدل `5`.

⚠️ لاحظ إن المجموعة دي فيها `supabase_flutter` و`flutter_secure_storage` — دول حزم حساسة أمنيًا، لكن التغيير هنا minor/patch مش major، فمسموح حسب `CONTRIBUTING.md` §7. **لا تفترض إنه آمن بس عشان اسم المجموعة "minor-and-patch" — تأكد فعليًا إن كل الـ checks خضراء زي مهمة PR #5 فوق قبل الدمج، بلا استثناء.**

---

## المرحلة 3 — اختبار بناء فردي قبل الدمج (major bumps)

كرر المهمة دي **بالكامل ومنفصلة** لكل رقم من: `4`, `9`, `10`, `11`, `12` — **رقم واحد بالمرة**، وممنوع تبدأ الرقم اللي بعده قبل ما تخلّص الرقم الحالي دمجًا أو توقفًا.

### قالب المهمة (استبدل `<N>` بالرقم الحالي)

```bash
gh pr checkout <N>
```
**Verify:** الأمر `git branch --show-current` لازم يطبع اسم فرع الـ dependabot بتاع الـ PR دا مش `main`.

```bash
flutter pub get
```
**Verify:** لازم ينتهي بدون أي سطر يبدأ بـ `Error` أو `FAILED`.

```bash
flutter build apk --debug
```
**Verify الوحيد المقبول:** آخر سطر في الـ output يحتوي على `Built build/app/outputs/flutter-apk/app-debug.apk` **و** الأمر `echo $?` بعده يطبع `0`.

**لو أي جزء من البناء فشل:**
- توقف فورًا. لا تحاول `flutter clean` أو أي إصلاح تلقائي.
- ارجع لـ main: `git checkout main`
- اعرض الـ error الخام كامل (مش ملخص) واسأل قبل أي حاجة تانية بخصوص الـ PR دا.
- **لا تدمج الـ PR دا.** انتقل لتوثيق إنه متوقف واطلب توجيه، ثم لو موافق عليه المستخدم انتقل للرقم اللي بعده في القائمة.

**لو البناء نجح:**
```bash
git checkout main
gh pr update-branch <N>
gh pr checks <N> --watch
```
**Verify:** كل الـ checks ✔.
```bash
gh pr merge <N> --squash --delete-branch
gh pr view <N> --json state --jq '.state'
```
**Verify:** يطبع `MERGED`.

---

## المرحلة 4 — PR #6 و#7 مع بعض إلزاميًا (مترابطين، ممنوع فصلهم)

**السبب:** `com.android.application` (AGP) و`gradle-wrapper` مرتبطين — AGP 9.3.1 محتاج إصدار Gradle أحدث من 8.14. دمج واحد بدون التاني هيكسر بناء Android. **ممنوع تدمج #6 لوحده أو #7 لوحده تحت أي ظرف.**

### TASK — دمج #6 و#7 مع بعض

```bash
git checkout -b test/agp-gradle-combined main
gh pr diff 6 | git apply
gh pr diff 7 | git apply
```
**Verify:** الأمر `git status --short` لازم يطبع تعديلات في ملفات `android/` بس (زي `gradle-wrapper.properties`, `build.gradle`). لو ظهر تعارض (conflict) أثناء `git apply`، توقف فورًا واعرض رسالة الخطأ الخام.

```bash
flutter build apk --debug
```
**Verify الوحيد المقبول:** نفس معيار المرحلة 3 بالظبط — `Built build/app/outputs/flutter-apk/app-debug.apk` و`echo $?` = `0`.

**لو فشل البناء:** توقف. `git checkout main && git branch -D test/agp-gradle-combined`. اعرض الخطأ الخام. **لا تدمج لا #6 ولا #7.**

**لو نجح البناء:**
```bash
git checkout main
git branch -D test/agp-gradle-combined
gh pr update-branch 6
gh pr checks 6 --watch
```
**Verify:** ✔ كلها.
```bash
gh pr merge 6 --squash --delete-branch
gh pr view 6 --json state --jq '.state'
```
**Verify:** `MERGED`.

**بعد ما #6 يتأكد إنه `MERGED` بالظبط (مش قبل)، كمّل لـ #7:**
```bash
gh pr update-branch 7
gh pr checks 7 --watch
```
**Verify:** ✔ كلها.
```bash
gh pr merge 7 --squash --delete-branch
gh pr view 7 --json state --jq '.state'
```
**Verify:** `MERGED`.

---

## التحقق النهائي (بعد كل المراحل)

```bash
gh pr list --label dependencies --json number,title
```
**Verify:** لازم القائمة تكون فاضية، أو فيها بس الأرقام اللي اتوقفت عمدًا (مع سبب موثّق لكل واحد منها).

```bash
git checkout main
flutter build apk --debug
```
**Verify:** نفس معيار البناء بالظبط.

**آخر خطوة إلزامية:** اكتب جدول ملخص نهائي بالشكل ده بالظبط — رقم PR، اسم الحزمة، النتيجة (Merged / Stopped-with-reason)، مفيش صياغة تانية:

| PR | الحزمة | النتيجة |
|---|---|---|
| 1 | codecov-action | ... |
| 2 | actions/checkout | ... |
| 3 | actions/upload-artifact | ... |
| 5 | desugar_jdk_libs | ... |
| 8 | minor-and-patch group | ... |
| 4 | kotlin.android | ... |
| 9 | device_info_plus/package_info_plus | ... |
| 10 | geolocator | ... |
| 11 | youtube_player_flutter | ... |
| 12 | flutter_local_notifications | ... |
| 6 | gradle-wrapper | ... |
| 7 | com.android.application | ... |

 