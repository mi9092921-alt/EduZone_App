# مهمة الوكيل: إنهاء إصلاح PR #15 — EduZone_App

## الدور
أنت وكيل تنفيذ (coding agent) عندك وصول لجهاز المطوّر (Windows، مسار المشروع تحت
`d:/projects/EduZone/flutter_projects/EduZone_App`)، وعندك صلاحية تشغيل أوامر
Git وFlutter وGitHub CLI (`gh`) مباشرة. نفّذ الخطوات بالترتيب، وتوقف واسأل
المستخدم فقط لو حصل خطأ حقيقي (تعارض merge، فشل اختبار غير متوقع، صلاحيات
ناقصة). لا تفترض نجاح أي خطوة — تحقق من الـ exit code والمخرجات فعليًا قبل
الانتقال للي بعدها.

---

## السياق (خلاصة المراجعة السابقة — لا تكرر الاكتشاف، ابني عليه)

1. **الفرع الأساسي `fix/pr15-clean`** مبني بالفعل من `origin/main` ومحتوي على
   6 إصلاحات مدموجة في commit واحد (`SEC-001` ربط killAppHandler،
   `DOC-001` تصحيح CHANGELOG، `REPO-001` تنظيف ملفات مؤقتة،
   `DEP-001`، `L10N-001` مفتاح searchCourses، `LOG-001` تقييد اللوج
   بـ kDebugMode)، بالإضافة لتعديل `ci.yml` لتفعيل `ENV_STAGING` secret
   تلقائيًا لو موجود.
2. **مشكلة حرجة مكتشفة:** فرع `main` نفسه تاريخه Git مضغوط لكوميت واحد بس
   (منفصل تمامًا عن أي فرع/PR قديم). لا تحاول `git rebase` عادي على أي فرع
   قديم آخر غير `fix/pr15-clean` — هيفشل بتعارضات وهمية. استخدم دايمًا
   الأسلوب: فرع جديد نضيف من `origin/main` + تطبيق diff صافي فوقه.
3. **مشكلة golden tests (السبب الجذري الحقيقي):** اختباري
   `settings_tile_golden_test.dart` (`Basic SettingsTile` و
   `SettingsTile with Subtitle and Trailing`) فاشلين في CI (Ubuntu) لأن
   صور الـ master goldens الحالية (`settings_tile_basic.png`,
   `settings_tile_full.png`) اتولّدت على Windows، بينما الثيم كله يستخدم
   `GoogleFonts.cairoTextTheme()`، ورندرة الخط بتختلف بين الأنظمة. الحل
   الصحيح: توليد الصور فعليًا **على Ubuntu عبر GitHub Actions نفسه** (مش
   على جهاز Windows المحلي)، لأن `test/flutter_test_config.dart` أصلاً
   بيعطّل `GoogleFonts.config.allowRuntimeFetching` (صح ومطلوب) لكن مش كافي
   وحده — لازم التوليد نفسه يحصل على نفس بيئة CI.
4. **قيد GitHub معروف:** أزرار `Run workflow` لـ `workflow_dispatch` ما
   بتظهرش في تبويب Actions إلا لو ملف الـ workflow موجود على الفرع
   الافتراضي (main) أو اتشغّل قبل كده مرة واحدة. الحل: تشغيله عبر
   `gh workflow run ... --ref <branch>` مباشرة بدل الانتظار على ظهوره
   بالواجهة.

---

## الخطوات (نفّذها بالترتيب، وتحقق بعد كل خطوة)

### الخطوة 0 — تأكيد نقطة الانطلاق
```bash
cd "d:/projects/EduZone/flutter_projects/EduZone_App"
git status
git branch --show-current   # يجب أن يكون fix/pr15-clean
git log -1 --oneline
```
لو مش على `fix/pr15-clean`، اعمل `git checkout fix/pr15-clean`. لو الفرع مش
موجود محليًا، ارجع للمستخدم واسأل قبل الاستمرار.

### الخطوة 1 — التأكد من وجود ملف update-goldens.yml
```bash
cat .github/workflows/update-goldens.yml
```
- لو الملف **موجود** وبيه `on: workflow_dispatch:` فقط → كمّل للخطوة 2.
- لو **غير موجود**، أنشئه بالمحتوى ده بالضبط:
```yaml
name: Update Goldens
on:
  workflow_dispatch:
jobs:
  update-goldens:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
      - name: Install dependencies
        run: flutter pub get
      - name: Generate l10n
        run: flutter gen-l10n
      - name: Regenerate golden images
        run: flutter test --update-goldens
      - name: Upload updated goldens
        uses: actions/upload-artifact@v4
        with:
          name: updated-goldens
          path: test/**/goldens/*.png
```
ثم:
```bash
git add .github/workflows/update-goldens.yml
git commit -m "ci: restore update-goldens workflow (needed to regenerate goldens on Ubuntu, matching CI font rendering)"
git push -u origin fix/pr15-clean
```

### الخطوة 2 — تشغيل الـ workflow على الفرع مباشرة (تجاوز قيد الظهور بالواجهة)
```bash
gh auth status || gh auth login
gh workflow run update-goldens.yml --ref fix/pr15-clean
```
انتظر ثانيتين ثم تابع التشغيل:
```bash
gh run list --workflow=update-goldens.yml --branch=fix/pr15-clean --limit 1
gh run watch --exit-status
```
**تحقق:** لازم الأمر الأخير يرجع بـ exit code = 0 (يعني الـ job نجح). لو فشل،
اعرض المستخدم رسالة الخطأ كاملة من `gh run view --log` ولا تكمل.

### الخطوة 3 — تنزيل الصور الجديدة واستبدال القديمة
```bash
RUN_ID=$(gh run list --workflow=update-goldens.yml --branch=fix/pr15-clean --limit 1 --json databaseId --jq '.[0].databaseId')
gh run download "$RUN_ID" -n updated-goldens -D /tmp/updated-goldens
cp /tmp/updated-goldens/test/features/profile/presentation/widgets/goldens/settings_tile_basic.png \
   test/features/profile/presentation/widgets/goldens/settings_tile_basic.png
cp /tmp/updated-goldens/test/features/profile/presentation/widgets/goldens/settings_tile_full.png \
   test/features/profile/presentation/widgets/goldens/settings_tile_full.png
git status --short
```
**تحقق:** لازم تشوف الملفين معدَّلين (`M`) بس، مفيش ملفات تانية اتغيرت.

### الخطوة 4 — إزالة تريجر الـ workflow المؤقت (لو كنت مضطر تضيفه سابقًا)
لو في أي خطوة سابقة اضطريت تضيف `push:` تريجر مؤقت لـ update-goldens.yml
عشان تشغّله، شيله دلوقتي وارجع الملف لـ `workflow_dispatch:` بس.

### الخطوة 5 — Commit للصور الجديدة
```bash
git add test/features/profile/presentation/widgets/goldens/settings_tile_basic.png \
        test/features/profile/presentation/widgets/goldens/settings_tile_full.png
git commit -m "test: regenerate settings_tile goldens on Ubuntu CI runner

Previous master images were generated on Windows; GoogleFonts.cairoTextTheme()
renders differently across OS font stacks even with runtime fetching disabled,
causing consistent CI failures on Ubuntu. Regenerated via the update-goldens
workflow_dispatch job (ubuntu-latest) so goldens now match the actual CI
rendering environment."
```

### الخطوة 6 — تحقق محلي كامل قبل الدفع
```bash
flutter analyze
flutter test 2>&1 | tee /tmp/flutter_test_output.txt
```
**معيار القبول:** `flutter analyze` → `No issues found!`.

**لو `flutter test` فيه أي فشل (حتى لو ظننته "بيئي")، ممنوع تلخّصه أو تتجاوزه.**
اعرض المستخدم **النص الخام الكامل** لأسطر الفشل:
```bash
grep -B2 -A20 -iE "FAILED|Some tests failed" /tmp/flutter_test_output.txt
```
حدد بالاسم كل اختبار فشل. لو كل الفشل محصور في
`settings_tile_golden_test.dart` (متوقع محليًا على Windows بسبب اختلاف
رندرة الخط عن Ubuntu — هذا مقبول والمرجع الحقيقي هو CI مش الجهاز المحلي)،
وضّح ده صراحة بالاسم. لو في أي اختبار تاني فشل، توقف فورًا ولا تكمل لأي
خطوة تالية.

### الخطوة 6.5 — فحص أي commits غير متوقعة على الفرع
قبل الدفع، تأكد إن كل commit على الفرع معروف المصدر:
```bash
git log --oneline origin/fix/pr15-clean..fix/pr15-clean 2>/dev/null
git log --oneline -10
```
لو لقيت أي commit مش من ضمن الخطوات اللي إنت نفذتها بنفسك في هذه المهمة
(مثلاً حاجة زي "update changelog for latest version release")، **توقف**
واعرض للمستخدم:
```bash
git show <hash> --stat
git show <hash>
```
كاملاً، واسأله هل هو متوقع (زي عمل حد تاني في الفريق دفع على نفس الفرع)
قبل ما تدفعه أو تعتبره جزء آمن من التغييرات.

### الخطوة 7 — الدفع النهائي
```bash
git push origin fix/pr15-clean
```

### الخطوة 8 — تأكيد نجاح CI الحقيقي (ci.yml) على آخر commit — مش update-goldens.yml
**تحذير مهم:** نجاح `update-goldens.yml` **لا يعني أبدًا** إن CI الحقيقي
للـ PR نجح. لازم تفحص كل الـ workflows اللي اشتغلت على نفس الـ commit hash
اللي دفعته فعليًا:
```bash
HEAD_SHA=$(git rev-parse HEAD)
echo "HEAD_SHA=$HEAD_SHA"
gh run list --branch=fix/pr15-clean --limit 10 --json databaseId,workflowName,status,conclusion,headSha \
  --jq '.[] | select(.headSha=="'"$HEAD_SHA"'")'
```
**معيار القبول الحقيقي:** لازم تشوف صف بالـ workflow الرئيسي (اسمه غالبًا
`CI` أو زي ما هو مكتوب في `.github/workflows/ci.yml`) بـ
`"conclusion":"success"` **وبنفس** `headSha` بتاع آخر commit دفعته. لو
مفيش صف أصلاً لهذا الـ workflow على هذا الـ commit، معناه CI لسه ما
اشتغلش — انتظر وكرر الأمر، ولا تعتبر الـ PR جاهز.

لو فيه PR مفتوح بالفعل:
```bash
gh pr checks <رقم PR> --watch
```
ولو رجع فاضي أو "no checks"، اعتبرها **علامة تحذير تحتاج تحقيق**، مش
تطمين — افحص بالطريقة اليدوية فوق (`gh run list` بالـ headSha) قبل ما
تقول للمستخدم إن الـ PR جاهز.

### الخطوة 9 — إغلاق PR #15 القديم (لو لسه مفتوح)
```bash
gh pr close 15 --comment "Superseded by #<رقم PR الجديد> — main's git history was squashed to a single unrelated commit, making a clean rebase of this branch impossible. All changes were re-applied on a fresh branch from current main."
```

### الخطوة 10 — الدمج (فقط بعد موافقة صريحة من المستخدم)
لا تدمج تلقائيًا. اعرض على المستخدم ملخص: كل الـ checks خضراء + رقم الـ PR،
واسأله تأكيد قبل:
```bash
gh pr merge <رقم PR> --squash --delete-branch
```

---

## قواعد صارمة أثناء التنفيذ
- ممنوع تتخطى أي خطوة تحقق (verification) حتى لو الخطوة اللي قبلها "غالبًا نجحت".
- ممنوع تعمل `git push --force` على `main` تحت أي ظرف.
- ممنوع تدمج PR بدون تأكيد صريح من المستخدم في نفس المحادثة.
- لو `flutter test` رجع فشل في أي اختبار غير `settings_tile_golden_test`، توقف
  فورًا وأبلغ المستخدم — ده يعني في تريجرات جديدة غير متوقعة مش جزء من هذه
  المهمة.
- لو الصور الجديدة من الـ artifact جت بنفس البايتات القديمة تمامًا (يعني
  التوليد ما اتغيرش)، وقف وأبلغ المستخدم — معناها فيه مشكلة تانية (زي كاش
  خط في الـ CI نفسه) لازم تتفحص قبل الاستمرار.
- ممنوع تقول "CI نجح" أو "PR جاهز" بناءً على نجاح `update-goldens.yml` بس.
  لازم تتأكد من نجاح الـ workflow الرئيسي (`ci.yml`) بالتحديد على نفس
  الـ commit hash المدفوع فعليًا.
- ممنوع تلخّص فشل `flutter test` بعبارة عامة زي "environment-dependent
  issues" بدون ما تعرض أسماء الاختبارات الفاشلة بالنص الخام.
- لو ظهر أي commit على الفرع إنت مش متذكر إنك عملته بنفسك في هذه الجلسة،
  توقف وافحصه (`git show`) قبل ما تدفعه لأي فرع remote.

## تقرير نهائي مطلوب من الوكيل
في آخر رسالة، لخّص:
- كل commit اتعمل (hash + رسالة مختصرة)
- نتيجة `flutter analyze` و`flutter test` النهائية
- رابط الـ PR ورقمه وحالة الـ checks
- هل تم الدمج ولا لسه في انتظار تأكيد المستخدم