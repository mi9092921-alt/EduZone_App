بعد إعادة المراجعة وربط الخطة بالوثائق الرسمية الحالية لـFirebase وSupabase، أعدت ترتيبها وتصحيح عدة نقاط كانت في الخطة السابقة تحتاج ضبطًا. الخطة التالية أعتبرها **المرجع التنفيذي المعتمد للمرحلة**.

راجعت أيضًا الحالة الفعلية في مستودع EduZone: لديك بالفعل طبقة Notifications كاملة نسبيًا، و`firebase_messaging` و`flutter_local_notifications` و`FcmService`، وجدول `push_tokens`، وRealtime، وGoRouter، وnotification fanout؛ لذلك لا نعيد تصميم النظام من الصفر.

# EduZone Push Notification Architecture

## المرجع التنفيذي المعتمد — v1.0

### 1. الهدف الحقيقي للمرحلة

الهدف ليس "إضافة FCM".

الهدف هو تحويل النظام الحالي إلى:

**Reliable Push Notification Delivery System**

بحيث يصبح لدينا:

```text
Notification Business Record
        ↓
Supabase
        ↓
Audience / User Fanout
        ↓
Push Delivery Queue
        ↓
FCM
        ↓
Android / iOS
        ↓
Notification Tap
        ↓
EduZone Notification Router
        ↓
Exact Destination
```

مع الحفاظ على:

```text
Supabase = Source of Truth
FCM      = Delivery Channel
Realtime = In-App Real-Time Channel
```

هذا الفصل هو القرار المعماري الأساسي.

---

# 2. ما الموجود بالفعل في المشروع

الحالة الحالية مهمة لأنها تحدد ما يجب تطويره بدل إعادة بنائه.

لديك:

```text
Flutter
 ├─ firebase_core
 ├─ firebase_messaging
 ├─ flutter_local_notifications
 └─ FcmService
```

و`FcmService` حاليًا يقوم بالحصول على token، والاستماع إلى token refresh، والاستماع إلى foreground messages، و`onMessageOpenedApp`، و`getInitialMessage()`.

ولديك:

```text
Supabase
 ├─ notifications
 ├─ notification_targets
 ├─ user_notifications
 ├─ push_tokens
 └─ notification fanout worker
```

والـdatabase لديها بالفعل `notifications` مع `target_audience`، والـfanout worker يوزع الإشعارات إلى `user_notifications`.

ولديك كذلك RLS على `push_tokens`، لكن mutation client-side ممنوعة، والكود الحالي يحاول تنفيذ `upsert` مباشرة من Flutter. هذه فجوة حقيقية يجب إغلاقها.

---

# 3. القرار الأول: لا نستخدم FCM كقاعدة بيانات للإشعارات

الـFCM لا يجب أن يكون مكانًا نحتفظ فيه بالـnotification history.

لدينا:

```text
notifications
user_notifications
```

وتظل هذه هي البيانات الرسمية.

FCM وظيفته:

```text
"أيها الجهاز، هناك إشعار جديد"
```

أما:

```text
ما هو الإشعار؟
هل يحق لهذا الطالب رؤيته؟
هل قرأه؟
متى أنشئ؟
لأي course؟
```

فكل هذا يبقى في Supabase.

---

# 4. القرار الثاني: Realtime + FCM معًا

ليس لدينا:

```text
Realtime OR FCM
```

بل:

```text
Realtime + FCM
```

الوظيفة:

```text
App Foreground
    ↓
Realtime
```

و:

```text
App Background/Terminated
    ↓
FCM
```

ويظل الاثنان يشيران إلى نفس `notification_id`.

هذا يمنع ازدواجية البيانات ويحافظ على Inbox الحالية.

---

# 5. القرار الثالث: إصلاح Token Architecture قبل Server Push

هذه أولوية P0.

المشكلة الحالية:

```text
FcmService
   ↓
push_tokens.upsert()
```

بينما RLS عندك مصمم على أن mutation يتم عبر RPC وليس direct client writes.

إذن لا نغير RLS ليصبح أضعف.

بل نغير Flutter:

```text
Flutter
   ↓
RPC register_push_token()
   ↓
PostgreSQL validates
   ↓
UPSERT
```

نفس الشيء لـdeactivation.

---

# 6. الـRPCs المطلوبة

أوصي بوجود واجهات واضحة:

```text
register_push_token()
deactivate_push_token()
remove_push_token()
```

ويمكن لاحقًا:

```text
touch_push_token()
```

لكن غالبًا `register_push_token()` يكفي إذا كان idempotent.

### `register_push_token()`

يستقبل:

```text
token
device_id
platform
device_info
app_version
```

ويتحقق من:

```text
authenticated user
correct tenant
device belongs to user
device is active
token not empty
platform valid
```

ثم:

```text
UPSERT
```

---

# 7. Push Token Schema

الجدول الحالي جيد كبداية، لكنه يحتاج `device_id` وfreshness metadata.

المرشح النهائي:

```text
push_tokens

id
user_id
tenant_id
device_id
token
platform
device_info
app_version
is_active
last_seen_at
created_at
updated_at
```

وجود `device_id` مهم جدًا في EduZone لأن النظام أصلًا يعتمد على device binding.

أما `last_seen_at` فمهم لإدارة stale registrations. Firebase نفسها توصي بأن يحدّث الخادم timestamp للتسجيل مع كل upload، وتذكر أن التسجيلات التي لم تتصل لأكثر من شهر تصبح مرشحة للاعتبار stale بحسب use case. ([Firebase][1])

---

# 8. لا نضع "Token واحد لكل مستخدم"

هذه نقطة أعدلها عن أي تصميم مبسط سابق.

الصحيح:

```text
User
 ├─ Device A → Token A
 └─ Device B → Token B
```

حتى لو كانت سياسة EduZone الحالية "جهاز واحد لكل مستخدم"، لا تجعل database contract يعتمد على هذا الافتراض.

لأن token lifecycle نفسه قد يتغير.

---

# 9. Auth Lifecycle

التنفيذ المعتمد:

```text
App Start
   ↓
Firebase initialized
   ↓
FCM token exists
   ↓
Is authenticated?
   ├─ No → hold/pending
   └─ Yes → register_push_token()
```

وعندما يتغير Auth state إلى authenticated:

```text
registerCurrentUserToken()
```

وعند `onTokenRefresh`:

```text
register_push_token()
```

وهذا يتوافق مع lifecycle الذي توثقه Firebase لاستقبال الرسائل وإدارة registration tokens. ([Firebase][2])

---

# 10. Logout

المسار الصحيح:

```text
logout requested
       ↓
deactivate_push_token()
       ↓
Firebase deleteToken()
       ↓
Supabase logout
       ↓
local cleanup
```

ليس العكس.

الـrepository الحالي بالفعل ينفذ `getToken → update push_tokens → deleteToken` في logout، لكن update المباشر يحتاج نقله إلى RPC.

---

# 11. Firebase Initialization

الـAndroid side في مشروعك تمت تهيئته بحيث يتم تطبيق `com.google.gms.google-services` عندما يكون `google-services.json` موجودًا، والـCI قادر بالفعل على إنشاء الملف من `GOOGLE_SERVICES_JSON`.

لكن هذا يجب أن يتحول إلى:

```text
Development build:
optional

Production release:
mandatory
```

لأن release ناجح مع FCM disabled لا يمثل الحالة التي نريد شحنها.

---

# 12. Production Firebase Gate

في `deploy.yml` عندك حاليًا فحص اختياري.

يجب أن تصبح قاعدة الإصدار:

```text
if APP_ENV == production
    GOOGLE_SERVICES_JSON is required
```

و:

```text
if missing
    FAIL RELEASE
```

وليس warning.

أما debug/local development فيستطيع البقاء flexible.

---

# 13. نقطة حساسة: Android Permission

لـAndroid 13+، تحتاج POST_NOTIFICATIONS runtime permission، وهو موجود عندك في Manifest.

لكن لا أنصح أن يكون:

```text
App startup
→ permission popup
```

بل:

```text
Login / Home
→ Explain benefit
→ Request OS permission
```

Firebase توضح أن permission مطلوبة على Android 13+ وعلى iOS قبل أن يتمكن التطبيق من استقبال notification payloads. ([Firebase][3])

---

# 14. المرحلة التالية: FCM Server Sender

هذه أكبر قطعة ناقصة.

يجب إنشاء:

```text
supabase/functions/send-push-notification/
    index.ts
```

وظيفتها:

```text
receive internal push request
       ↓
load validated recipient token(s)
       ↓
construct FCM message
       ↓
obtain OAuth access token
       ↓
POST FCM HTTP v1
       ↓
record result
```

Supabase Edge Functions مناسبة لهذه الوظيفة لأنها server-side TypeScript وتتعامل مع third-party integrations، ويمكن تخزين credentials في secrets. ([Supabase][4])

---

# 15. FCM HTTP v1 وليس Legacy API

نستخدم:

```text
FCM HTTP v1 API
```

والإرسال يكون إلى:

```text
POST
https://fcm.googleapis.com/v1/projects/{projectId}/messages:send
```

مع OAuth/service-account authentication. Firebase توثق هذا المسار رسميًا. ([Firebase][5])

لن نعتمد على legacy server key.

---

# 16. Credentials

الأفضل:

```text
Supabase Edge Function
       ↓
Supabase Secrets
       ↓
FCM service credentials
```

وليس:

```text
Flutter
```

ولا:

```text
GitHub repository
```

Supabase توضح أن secret keys يجب ألا تكون داخل client code، وأن secrets الخاصة بالـEdge Functions يمكن قراءتها عبر environment variables. ([Supabase][6])

---

# 17. أي credentials تحديدًا؟

نحتاج credentials تتيح للـserver الحصول على OAuth access token وإرسال الرسائل إلى Firebase project.

يمكن تمثيلها secret-wise مثل:

```text
FCM_PROJECT_ID
FCM_CLIENT_EMAIL
FCM_PRIVATE_KEY
```

أو تخزين service-account JSON كـsecret واحد ثم parsing داخليًا.

أنا أفضل **عدم حفظ service-account JSON داخل GitHub** حتى لو كان repository private.

---

# 18. أهم تصحيح على الخطة السابقة: لا تجعل Edge Function نفسها Queue

هذا مهم.

الـEdge Function ليست بديلًا عن Job Queue.

الأفضل:

```text
Database
   ↓
Job Queue
   ↓
Worker
   ↓
send-push-notification
   ↓
FCM
```

خصوصًا أن Supabase تصف Edge Functions بأنها مناسبة للأعمال القصيرة/idempotent، بينما الأعمال الثقيلة أو الطويلة يجب أن تذهب إلى background workers. ([Supabase][4])

---

# 19. نستخدم الـJob Queue الموجودة عندك

عندك بالفعل `internal.job_queue`.

والـnotification fanout worker موجود بالفعل.

إذن نضيف نوع Job جديد:

```text
notification_push
```

مثلاً:

```text
notification_push
{
   notification_id,
   user_id
}
```

أو أفضل:

```text
notification_push
{
   notification_id,
   user_notification_id,
   push_token_id
}
```

والأخير أفضل للتتبع.

---

# 20. Pipeline النهائي

```text
Admin
 ↓
create notification
 ↓
notifications
 ↓
fanout
 ↓
user_notifications
 ↓
enqueue notification_push
 ↓
worker
 ↓
send-push-notification
 ↓
FCM
 ↓
device
```

هذا يجعل فشل FCM لا يفشل إنشاء notification نفسه.

---

# 21. نقطة مهمة: هل نرسل Push داخل DB Trigger؟

لا.

لا نريد:

```text
INSERT notifications
 ↓
trigger
 ↓
HTTP request
 ↓
FCM
```

هذا coupling سيئ.

الأفضل:

```text
INSERT
 ↓
enqueue job
```

ثم إرسال غير متزامن.

---

# 22. Push Delivery Tracking

هذه إضافة Production-critical.

أوصي:

```text
push_deliveries

id
notification_id
user_id
push_token_id
status
attempt_count
provider_message_id
provider_error_code
provider_error_message
created_at
sent_at
failed_at
```

الحالات:

```text
pending
sending
sent
failed
invalid_token
```

الهدف:

```text
Notification created?
YES

Inbox created?
YES

Push attempted?
YES

FCM accepted?
YES

Token valid?
YES
```

---

# 23. Idempotency

ضرورية.

مثلاً:

```text
worker
   ↓
FCM returns success
   ↓
worker crashes before DB update
```

ثم retry.

بدون idempotency:

```text
same push × 2
```

لذلك نحتاج unique logical delivery:

```text
notification_id
+
push_token_id
```

ويجب أن تكون العملية idempotent قدر الإمكان.

---

# 24. Retry Policy

ليست كل failures تستحق retry.

نقسمها:

```text
Transient
→ retry

Permanent
→ mark failed

Invalid token
→ deactivate token
```

مثال:

```text
network timeout
500
503
429
```

→ retry with bounded exponential backoff.

أما:

```text
UNREGISTERED
```

→ لا retry.

Firebase توصي بإزالة registrations غير الصالحة عند `UNREGISTERED`، وتوضح أن `INVALID_ARGUMENT` لا يعني دائمًا invalid token إذا كان payload نفسه خاطئًا؛ لذلك لا نستخدمه بهذه الصورة إلا بعد التأكد من صحة payload. ([Firebase][1])

---

# 25. Stale Token Cleanup

لا نحذف كل token لمجرد أنه قديم.

نستخدم:

```text
last_seen_at
```

ثم سياسة مثل:

```text
active
stale
inactive
```

والـthreshold نحددها بناءً على استخدام EduZone.

Firebase نفسها تشير إلى أن التطبيق/الخادم يجب أن يتعامل مع freshness وفق use case، مع اعتبار نحو شهر مؤشرًا عمليًا على staleness. ([Firebase][1])

---

# 26. Notification Contract

النظام الحالي يحتاج توحيدًا.

`AppNotification` عندك حاليًا يحتوي title/body بالإضافة إلى IDs الأساسية، لكن تفاصيل notification الحالية لا تشمل نوع الإشعار/الـdestination metadata.

نريد:

```text
Notification
├─ id
├─ type
├─ title
├─ body
├─ payload
└─ audience
```

مثلاً:

```json
{
  "type": "new_video",
  "payload": {
    "course_id": "...",
    "lesson_id": "..."
  }
}
```

---

# 27. Notification Types

نثبت contract ولا نتركه text حر:

```text
new_course
new_video
course_subscription
subscription_expired
download_completed
download_failed
course_expiring
warning
announcement
system
```

ليس شرطًا أن ننفذ كل الأنواع الآن.

لكن الـcontract يجب أن يسمح بها.

---

# 28. نقطة مهمة جدًا: نفس Router لكل شيء

حاليًا FCM tap يذهب إلى:

```text
/home/notifications
```

ولا يفتح destination الحقيقي.

بينما GoRouter لديك بالفعل routes تفصيلية للكورسات والدروس والتنزيلات.

إذن ننشئ:

```text
NotificationRouter
```

ولا نضع navigation logic داخل `FcmService`.

---

# 29. البنية المقترحة

```text
FcmService
   ↓
NotificationIntentParser
   ↓
NotificationRouter
   ↓
GoRouter
```

وفي Notification Center:

```text
NotificationTile
   ↓
NotificationRouter
```

وفي Realtime:

```text
Realtime event
   ↓
NotificationRouter
```

أي أن كل الطرق تستخدم نفس الـdestination resolver.

---

# 30. Pending Notification Intent

لديك حاليًا فكرة `_pendingDeepLinkPath` بالفعل، وهي فكرة صحيحة، لكنها بسيطة جدًا.

نحوّلها إلى:

```text
PendingNotificationIntent

notificationId
type
payload
receivedAt
```

ثم:

```text
Router ready?
   ├─ yes → navigate
   └─ no  → queue
```

ولو المستخدم غير authenticated:

```text
Push tap
 ↓
Login
 ↓
restore pending intent
 ↓
validate access
 ↓
navigate
```

---

# 31. Authorization بعد Push Tap

الـFCM payload لا يمنح صلاحية.

مثلاً:

```text
new_video
course_id = X
lesson_id = Y
```

لكن الطالب أُلغي اشتراكه بعد إرسال الإشعار.

عند tap:

```text
NotificationRouter
 ↓
check access
 ↓
denied
 ↓
fallback destination
```

ولا نفتح الفيديو مباشرة.

هذا فصل مهم بين:

```text
Navigation
```

و:

```text
Authorization
```

---

# 32. Foreground Duplicate Suppression

هذه مشكلة مؤكدة يجب تصميمها من البداية.

في foreground قد يصل:

```text
Realtime
```

وفي نفس الوقت:

```text
FCM
```

فنحتاج:

```text
notification_id dedupe
```

مثلاً:

```text
Realtime receives N1
→ mark N1 seen

FCM receives N1
→ already seen
→ don't display duplicate local alert
```

---

# 33. Foreground Policy

أوصي:

```text
Foreground:
Realtime → update Inbox
          + optional in-app banner

FCM:
do not create second visual alert
```

أما background:

```text
FCM
→ OS notification
```

وهذا يعطي UX أنظف.

---

# 34. FCM Message Design

بالنسبة لـEduZone، نرسل:

```text
notification
+
data
```

مثلًا:

```json
{
  "message": {
    "token": "...",
    "notification": {
      "title": "فيديو جديد",
      "body": "تم إضافة فيديو جديد للكورس"
    },
    "data": {
      "notification_id": "...",
      "type": "new_video",
      "course_id": "...",
      "lesson_id": "..."
    }
  }
}
```

FCM HTTP v1 يدعم هذا النمط من `notification` و`data`. ([Firebase][5])

---

# 35. لا نستخدم Data-only إلا لحاجة حقيقية

التصميم الأساسي:

```text
notification + data
```

وليس:

```text
data-only
```

في كل شيء.

هذا يقلل التعقيد والاختلافات بين platform states.

---

# 36. Background / Terminated

يجب دعم:

```text
Foreground
Background
Terminated
```

Firebase تفرق صراحة بين الحالات الثلاث وتوضح lifecycle المطلوب في Flutter، ومن ضمنه `onMessageOpenedApp` و`getInitialMessage()`. ([Firebase][2])

والمشروع عندك يستخدم الاثنين بالفعل.

---

# 37. Background Handler

لو احتجنا Data processing حقيقي في الخلفية، سنضيف `onBackgroundMessage` مع top-level handler وفق متطلبات Flutter/FCM.

لكن:

**لا نضيفه فقط لأن "FCM يحتاجه".**

الـnotification tap flow الحالي يمكنه الاعتماد على المسارات الموثقة لـbackground/terminated reception ما لم يوجد business logic يحتاج background execution. Firebase توثق هذه الحالات منفصلة. ([Firebase][2])

---

# 38. Android Notification Channel

لديك local notification channel حاليًا:

```text
eduzone_high_importance
```

في `FcmService`.

هذا جيد.

نحتاج تثبيت:

```text
channel ID
channel name
importance
sound
vibration
icon
```

ولا نغير channel ID بعد الإصدار بدون سبب، لأن Android يتعامل مع القنوات ككيانات مستقلة.

---

# 39. Notification Icon

الـcurrent code يستخدم:

```text
@mipmap/ic_launcher
```

وهذا ليس ما أفضله للإنتاج.

نضيف:

```text
ic_stat_eduzone
```

كـnotification small icon مناسب لـAndroid.

---

# 40. iOS

إذا كان iOS ضمن release scope، لا نعتبر المرحلة مكتملة قبل:

```text
Push Notifications capability
Background Modes
APNs
APNs key uploaded to Firebase
FCM testing on physical iPhone
```

Firebase توثق أن إعداد iOS يتطلب تمكين Push Notifications وBackground modes ورفع APNs authentication key إلى Firebase. ([Firebase][7])

والـ`AppDelegate.swift` الحالي لا يحتوي إعدادًا خاصًا بـFirebase/APNs beyond Flutter registration.

---

# 41. Supabase Security

الـsender الداخلي يجب ألا يكون endpoint عامًا للطلاب.

أفضل أحد مسارين:

```text
DB/worker
  ↓
internal invocation
```

أو:

```text
Edge Function
auth: secret
```

Supabase توثق حاليًا `auth: 'secret'` و`secret:<name>` لوظائف server-to-server، مع إمكانية استخدام privileged Supabase client. ([Supabase][8])

---

# 42. أسرار Supabase

الـFCM credentials:

```text
Supabase Dashboard
→ Edge Function Secrets
```

وليس Git.

Supabase توضح أن secrets متاحة للوظائف عبر environment variables، ويمكن إدارتها من Dashboard أو CLI. ([Supabase][6])

---

# 43. Cron

هنا أيضًا توجد نقطة تحتاج تصحيحًا.

لا نحتاج خادم cron خارجي لمجرد تشغيل queue worker.

Supabase Cron يستطيع تشغيل database functions أو HTTP requests إلى Edge Functions، ويسجل job runs. ([Supabase][9])

بالتالي يمكن أن يكون:

```text
Supabase Cron
   ↓
process_notification_push_jobs()
```

أو:

```text
Supabase Cron
   ↓
Edge Function worker
```

والاختيار النهائي يعتمد على حجم الـqueue وطبيعة التنفيذ.

---

# 44. Worker Recommendation لـEduZone

نظرًا لحجم الاستخدام المتوقع عندك، أفضل بداية:

```text
Supabase Cron
    ↓
DB worker function
    ↓
dequeue jobs
    ↓
HTTP call to send-push Edge Function
```

لكن إذا وصلنا إلى حجم كبير جدًا، يمكن نقل processing إلى dedicated worker.

Edge Functions نفسها يجب أن تظل عمليات قصيرة وidempotent. ([Supabase][4])

---

# 45. Notification Fanout لا يُعاد بناؤه

الـfanout عندك موجود بالفعل.

الـworker الحالي يتعامل مع:

```text
all
students
teachers
admins
```

ويضع النتائج في `user_notifications`.

هذا ممتاز.

نضيف فوقه فقط:

```text
Push delivery
```

---

# 46. Explicit Targets

عندك أيضًا handling للإشعارات المستهدفة بشكل مباشر، والـschema/worker architecture عندك تعالج `notification_targets` و`user_notifications`.

هذا يجب أن يظل.

وبالتالي:

```text
Audience Target
```

و:

```text
Explicit User Target
```

كلاهما يخرجان إلى:

```text
user_notifications
```

ثم:

```text
push_deliveries
```

---

# 47. المصدر الحقيقي للـPush Recipient

لا ينبغي لـEdge Function أن تقول:

```text
send to every token for user
```

دون منطق.

يجب تحديد:

```text
eligible active tokens
```

مع:

```text
user_id
tenant_id
is_active
```

ومراعاة device/account state.

---

# 48. Delivery Security

لا ترسل Push لمستخدم لم يعد مؤهلًا.

التحقق النهائي يجب أن يكون قبل إنشاء delivery أو على الأقل قبل send:

```text
user active?
tenant correct?
notification still valid?
user_notification exists?
token active?
```

هذا يمنع stale jobs من إرسال إشعارات بعد تغير الحالة.

---

# 49. Deletion / Cancellation

إذا تم حذف notification قبل إرسالها:

```text
pending push job
```

يجب أن يعرف worker أنها لم تعد صالحة، فلا يرسلها.

إذن:

```text
notification.deleted_at
```

جزء من قرار send.

---

# 50. Observability

عندك Sentry أصلًا، وFCM initialization errors تُرسل إلى `GlobalErrorHandler`.

نحتاج إضافة tags:

```text
notification_type
notification_id
push_delivery_status
fcm_error_code
platform
```

لكن:

**لا نسجل FCM token في Sentry.**

لأنه identifier حساس.

---

# 51. ماذا نسجل؟

مسموح:

```text
notification_id
user_id
platform
error_code
attempt
status
```

بحذر.

لا نسجل:

```text
full FCM token
private key
service account
access token
```

---

# 52. Testing — الحد الأدنى الإلزامي

## Unit

```text
FCM payload parser
NotificationType parser
NotificationRouter
pending intent
deduplication
token lifecycle
```

## Integration

```text
create notification
→ fanout
→ push job
→ sender
→ delivery record
```

## Device E2E

```text
Foreground
Background
Terminated
```

مع:

```text
permission granted
permission denied
logout
login
token refresh
invalid token
network failure
retry
```

---

# 53. اختبار Firebase الرسمي

Firebase توفر طريقة اختبار مباشرة بإرسال test notification إلى registration token والتحقق من استقبالها، وهذا سيكون baseline verification قبل اختبار EduZone الكامل. ([Firebase][5])

لكن test notification في Firebase لا تكفي لإثبات أن architecture الخاصة بنا صحيحة.

نحتاج:

```text
Admin → EduZone → Supabase → Worker → FCM → Device
```

---

# 54. Release Acceptance Criteria

لا تعتبر المرحلة مكتملة إلا إذا تحققت كل هذه:

```text
[ ] Firebase Android app configured
[ ] google-services.json valid
[ ] Production secret configured
[ ] release CI fails when Firebase missing
[ ] token registration works
[ ] token refresh works
[ ] logout deactivates token
[ ] FCM send works
[ ] invalid token is deactivated
[ ] retry works
[ ] delivery is idempotent
[ ] Realtime works
[ ] foreground duplicate avoided
[ ] background push works
[ ] terminated push works
[ ] notification tap routing works
[ ] access revalidated
[ ] push delivery observable
[ ] Android verified
[ ] iOS verified if in scope
```

---

# 55. ترتيب التنفيذ المعتمد

هذه هي النسخة التي أنصح أن تُعطى للـAgent حرفيًا كمراحل تنفيذ.

## Phase P0 — Audit & Baseline

```text
1. Freeze current notification architecture.
2. Trace all notification creation paths.
3. Trace all push token paths.
4. Verify RLS.
5. Verify current FCM initialization.
6. Identify every notification-triggering feature.
```

الهدف: عدم تغيير behavior عشوائيًا.

---

## Phase P1 — Push Token Infrastructure

```text
1. Add device_id to push_tokens.
2. Add last_seen_at.
3. Create register_push_token RPC.
4. Create deactivate_push_token RPC.
5. Move Flutter registration to RPC.
6. Move logout deactivation to RPC.
7. Handle auth-state registration.
8. Handle onTokenRefresh.
9. Add retry/backoff.
10. Add tests.
```

هذه أهم مرحلة.

---

## Phase P2 — Firebase Production Configuration

```text
1. Firebase project.
2. Android app.
3. package verification.
4. google-services.json.
5. local configuration.
6. CI secret.
7. release gate.
8. test notification.
```

---

## Phase P3 — FCM Server Sender

```text
1. Create send-push-notification Edge Function.
2. Store FCM credentials as Supabase secrets.
3. Implement OAuth access token creation.
4. Implement HTTP v1 sending.
5. Validate payload.
6. Validate recipients.
7. Parse FCM responses.
8. Deactivate invalid tokens.
```

---

## Phase P4 — Push Queue

```text
1. Create push_deliveries.
2. Add notification_push job.
3. Connect existing fanout → push job.
4. Implement worker.
5. Add idempotency.
6. Add retries.
7. Add failure states.
```

---

## Phase P5 — Notification Contract

```text
1. Add notification type.
2. Add payload.
3. Add entity metadata.
4. Define canonical event types.
5. Update AppNotification.
6. Update notification creation APIs.
```

---

## Phase P6 — Notification Router

```text
1. Create NotificationIntent.
2. Create NotificationRouter.
3. Route FCM tap.
4. Route Notification Center tap.
5. Route Realtime events.
6. Add pending-intent mechanism.
7. Add access validation.
8. Add fallback destination.
```

---

## Phase P7 — UX

```text
1. Permission rationale.
2. Android notification icon.
3. Channel verification.
4. Foreground banner policy.
5. Duplicate suppression.
6. Notification center interaction.
```

---

## Phase P8 — Reliability & Observability

```text
1. Sentry instrumentation.
2. delivery metrics.
3. retry metrics.
4. invalid-token metrics.
5. queue depth.
6. stale-token cleanup.
7. failed-job recovery.
```

---

## Phase P9 — Device E2E

```text
Android
  ├─ foreground
  ├─ background
  ├─ terminated
  ├─ denied permission
  ├─ granted permission
  ├─ logout
  ├─ login
  ├─ token rotation
  └─ invalid token
```

ثم iOS إذا كان داخل release scope.

---

# 56. ما الذي لا نفعله

هذه قائمة مهمة جدًا للـAgent:

```text
❌ لا نحذف Supabase Notifications
❌ لا نحذف Supabase Realtime
❌ لا نجعل FCM مصدر الحقيقة
❌ لا نضع Firebase credentials في Flutter
❌ لا نضع Service Role Key في Flutter
❌ لا نسمح لـFlutter بالـpush_tokens direct mutation
❌ لا نرسل FCM من database trigger مباشرة
❌ لا نربط navigation بـFcmService مباشرة
❌ لا نرسل Data-only لكل شيء
❌ لا نعتبر build ناجحًا دليلًا أن FCM يعمل
❌ لا نحذف stale tokens عشوائيًا
❌ لا نعتبر HTTP 400 = invalid token دائمًا
```

---

# 57. ما الذي اعتبرته "مصدرًا موثوقًا" في هذه الخطة

الخطة مبنية على ثلاثة مستويات من الأدلة:

**المستوى الأول: الكود الفعلي لـEduZone.**

مثل `FcmService` و`push_tokens` و`notifications` وfanout وRouter وCI.

**المستوى الثاني: Firebase الرسمي الحالي.**

خصوصًا FCM Flutter receive lifecycle، HTTP v1 sending، وإدارة registration tokens. ([Firebase][2])

**المستوى الثالث: Supabase الرسمي الحالي.**

خصوصًا Edge Functions، secrets، authentication، وCron. ([Supabase][4])

---

# القرار النهائي

أعتمد هذه البنية:

```text
                  EDUZONE NOTIFICATION SYSTEM

                         ┌───────────────┐
                         │    Admin      │
                         └───────┬───────┘
                                 ↓
                         ┌───────────────┐
                         │ notifications │
                         └───────┬───────┘
                                 ↓
                          Fanout / Queue
                                 ↓
                      ┌──────────┴──────────┐
                      ↓                     ↓
               user_notifications      push_deliveries
                      ↓                     ↓
                 Realtime              Push Worker
                      ↓                     ↓
                EduZone App       send-push Edge Function
                                            ↓
                                         FCM
                                            ↓
                                      Android/iOS
                                            ↓
                                      User Tap
                                            ↓
                                  NotificationRouter
                                            ↓
                                  Access Validation
                                            ↓
                                  Exact Destination
```

وبالمراجعة الثانية، أهم تغييرين عن الخطة السابقة هما:

**أولًا:** لا نعتمد على direct mutation لـ`push_tokens`؛ يجب احترام الـRLS الحالي وإنشاء RPCs. هذا ليس تحسينًا اختياريًا، بل إصلاح بنيوي مطلوب.

**ثانيًا:** لا نضع الإرسال كطلب مباشر متزامن داخل إنشاء notification. نستخدم الـjob queue الموجودة عندك، ثم sender idempotent، لأن هذا أكثر اتساقًا مع طبيعة Edge Functions والـbackground processing. ([Supabase][4])

هذه هي النسخة التي أنصح بأن تصبح **الـSource of Truth التنفيذي للمرحلة**، وليس الخطة السابقة.

[1]: https://firebase.google.com/docs/cloud-messaging/manage-tokens?hl=en&utm_source=chatgpt.com "Best practices for FCM registration management  |  Firebase Cloud Messaging"
[2]: https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages?authuser=0&utm_source=chatgpt.com "Receive messages in Flutter apps  |  Firebase Cloud Messaging"
[3]: https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages?hl=he&utm_source=chatgpt.com "קבלת הודעות באפליקציות Flutter  |  Firebase Cloud Messaging"
[4]: https://supabase.com/docs/guides/functions?utm_source=chatgpt.com "Edge Functions | Supabase Docs"
[5]: https://firebase.google.com/docs/cloud-messaging/send/v1-api?utm_source=chatgpt.com "Send a message using FCM HTTP v1 API  |  Firebase Cloud Messaging"
[6]: https://supabase.com/docs/guides/functions/secrets?utm_source=chatgpt.com "Environment Variables | Supabase Docs"
[7]: https://firebase.google.com/docs/cloud-messaging/flutter/get-started?utm_source=chatgpt.com "Get started with Firebase Cloud Messaging in Flutter apps"
[8]: https://supabase.com/docs/guides/functions/auth?utm_source=chatgpt.com "Securing Edge Functions | Supabase Docs"
[9]: https://supabase.com/docs/guides/cron?utm_source=chatgpt.com "Cron | Supabase Docs"
