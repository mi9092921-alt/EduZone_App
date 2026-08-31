# الخطة التنفيذية المتكاملة لإصلاح Authentication & Authorization في EduZone

**النطاق:** Flutter client + Supabase Auth + PostgreSQL/RLS/RBAC + RPCs + session/device layer + الاختبارات التشغيلية.

**الهدف النهائي:** تحويل Section 8 من **FAIL** إلى **Production Security Gate = PASS**، مع جعل **PostgreSQL/Supabase هو Security Authority**، وFlutter طبقة presentation/defense-in-depth فقط.

المبدأ الأساسي الذي سأبني عليه التنفيذ هو:

```text
Client Authentication State
        ↓
Supabase JWT
        ↓
Server Session Validation
        ↓
Tenant Validation
        ↓
RBAC / Permissions
        ↓
Resource Authorization
        ↓
ALLOW / DENY
```

وليس:

```text
Flutter says authenticated
        ↓
allow access
```

وهذا متوافق مع نموذج Supabase الذي يجعل RLS والـPostgres authorization طبقة الحماية الأساسية، مع استخدام `auth.uid()` و`auth.jwt()` وSecurity Definer functions بعناية. ([Supabase][1])

---

# Phase 0 — تجميد الوضع الحالي قبل الإصلاح

لا نبدأ بتعديل الدوال الموجودة مباشرة.

أولًا يتم إنشاء baseline واضح.

## 0.1 إنشاء فرع أمني

```text
security/authz-hardening
```

ويجب أن يكون كل الإصلاحات اللاحقة في هذا الفرع.

## 0.2 حفظ baseline

يتم تسجيل:

```text
HEAD commit
Flutter version
Dart version
Supabase CLI version
PostgreSQL major version
schema hash
RLS schema hash
permissions schema hash
```

## 0.3 عدم تعديل الـschema canonical مباشرة

بما أن المشروع يستخدم:

```text
supabase/schema/
```

والـconfig يحمّل هذه الملفات بترتيب محدد، يجب أن تكون التغييرات deterministic:

```text
01_extensions
02_types
03_tables
04_constraints
05_indexes
06_views
07_functions
08_triggers
09_rls
10_permissions
11_seed
```

أي إصلاح يتم في المصدر canonical ثم يعاد توليد/تحديث artifacts التابعة له، وليس patch يدوي منفصل لا يطابق source of truth.

---

# Phase 1 — تعريف Security Invariants

هذه أهم مرحلة؛ قبل كتابة أي SQL يجب تحديد القواعد التي لا يجوز كسرها.

## AUTH-INVARIANT-01 — Session validity

```text
A request is authenticated only if:
auth.uid() IS NOT NULL
AND account is active
AND user is not deleted
AND session is not revoked
```

## AUTH-INVARIANT-02 — Token revocation

إذا:

```text
DB token_version > JWT token_version
```

فإن:

```text
DENY
```

دون استثناء.

## AUTH-INVARIANT-03 — Tenant isolation

لا يجوز لأي authenticated user الوصول إلى tenant آخر.

## AUTH-INVARIANT-04 — Authorization

وجود session لا يعني امتلاك permission.

```text
authenticated != authorized
```

## AUTH-INVARIANT-05 — Resource authorization

الوصول للدرس مثلًا يتطلب:

```text
valid_session
AND valid_tenant
AND course_access
```

أو صلاحية إدارية/تعليمية محددة.

## AUTH-INVARIANT-06 — Admin authorization

صلاحية admin يجب أن تعتمد على current server-side authorization state، وليس claim قديم فقط.

## AUTH-INVARIANT-07 — Client is never trusted

Flutter يمكنه:

```text
hide UI
redirect
show errors
```

لكن لا يستطيع منح access.

---

# Phase 2 — إصلاح Session Validation Core

هذه هي أهم مرحلة في المشروع كله.

## 2.1 استحداث primitive واحدة

بدل وجود عدة implementations متشابهة:

```text
validate_user_session()
get_auth_user_id()
is_admin_with_session_validation()
check_student_app_access()
```

ننشئ طبقة واضحة:

```text
private/auth_session.sql
```

والـAPI العامة:

```text
public.validate_user_session()
public.assert_valid_session()
public.current_user_session()
```

### المطلوب

`validate_user_session()` يجب أن يكون deterministic وserver-authoritative.

المنطق:

```text
1. auth.uid() exists
2. user exists
3. deleted_at IS NULL
4. account_status = active
5. JWT token_version exists
6. DB token_version exists
7. JWT token_version == DB token_version
```

لا يجوز أن يكون fast path:

```text
JWT version == JWT version
```

لأنه لا يثبت أي شيء.

---

## 2.2 لا نعتمد على JWT authorization claim وحده للـrevocation

Supabase documentation تتيح custom access token claims لأدوار وصلاحيات مخصصة، لكن هذه claims جزء من الـtoken الصادر، لذلك لا يجب استخدامها بطريقة تسمح بحالة authorization قديمة بعد تغيير server-side state. ([Supabase][2])

سنحتفظ بالclaims لأغراض:

```text
tenant_id
primary_role
is_admin
token_version
region_id
```

ولكن:

```text
DB = authority for revocation
```

وليس JWT وحده.

---

# Phase 3 — إعادة تصميم `validate_user_session()`

الهدف:

```sql
validate_user_session()
```

يكون لديه مسار واضح مثل:

```text
auth.uid()
  ↓
users lookup
  ↓
active?
  ↓
not deleted?
  ↓
JWT version exists?
  ↓
DB version == JWT version?
  ↓
TRUE
```

## قاعدة مهمة

إذا كانت بيانات session ناقصة:

```text
JWT missing token_version
JWT malformed
DB user missing
DB version NULL unexpectedly
```

فالنتيجة:

```text
FALSE
```

وليس fallback إلى allow.

أي:

> **Fail closed.**

وهذا يتفق مع مبدأ RLS والـauthorization server-side. ([Supabase][1])

---

# Phase 4 — فصل Authentication عن Authorization

حاليًا توجد دوال تحمل أكثر من مسؤولية.

سنقسمها إلى:

```text
Session layer
Tenant layer
Identity layer
Role layer
Permission layer
Resource layer
```

## 4.1 Session

```text
validate_user_session()
assert_valid_session()
```

## 4.2 Identity

```text
current_user_id()
```

## 4.3 Tenant

```text
get_current_tenant_id()
assert_tenant()
```

## 4.4 Role

```text
has_role(role)
```

## 4.5 Permission

```text
has_permission(permission, tenant)
```

## 4.6 Resource

```text
has_course_access(user, course)
can_access_lesson(user, lesson)
```

هذا يقلل خطر أن تقوم دالة واحدة بعمل:

```text
session + tenant + role + resource
```

ثم تصبح صعبة التدقيق.

---

# Phase 5 — إصلاح `check_student_app_access()`

يجب أن تتوقف `check_student_app_access()` عن كونها primitive أمنية مستقلة.

الترتيب:

```text
check_student_app_access()
        ↓
assert_valid_session()
        ↓
get current user
        ↓
account status
        ↓
return business access state
```

الحالات:

```text
unauthenticated
user_not_found
deleted
banned
locked
suspended
app_locked
maintenance
active
```

لكن:

```text
allowed=true
```

لا يخرج إلا بعد valid session.

---

# Phase 6 — إصلاح Admin Authorization

الدالة:

```text
is_admin_with_session_validation()
```

يجب أن تتحول إلى:

```text
assert_valid_session
        ↓
current user
        ↓
current server-side role/permission
        ↓
admin?
```

وليس:

```text
JWT primary_role == admin
```

فقط.

### لماذا؟

لأن تغيير الدور:

```text
admin → student
```

يجب أن يصبح فعالًا server-side حتى لو كان JWT القديم ما زال صالحًا cryptographically.

---

# Phase 7 — RBAC Hardening

المشروع لديه:

```text
roles
permissions
role_permissions
user_roles
user_permission_cache
```

والـ`user_has_permission()` يعتمد على permission cache وRBAC source of truth.

سنثبت التصميم النهائي:

```text
user_roles
      ↓
role_permissions
      ↓
permissions
```

والـcache:

```text
optimization only
```

وليس:

```text
security source of truth
```

أي عند الشك:

```text
RBAC source > cache
```

---

# Phase 8 — Permission Cache Correctness

يجب اختبار كل أحداث invalidation:

```text
role added
role removed
role expired
permission added
permission removed
role permission changed
user suspended
user deleted
tenant changed
```

والـcache يجب أن يبطل عند كل حدث authorization-related.

المشروع يحتوي بالفعل triggers لإبطال cache، مثل role-permission changes.

سنحول ذلك إلى tests وليس مجرد implementation assumption.

---

# Phase 9 — Tenant Isolation Hardening

كل request حساس يجب أن يثبت:

```text
JWT tenant
=
current user tenant
=
resource tenant
```

نراجع:

```text
get_current_tenant_id()
assert_tenant()
tenant_matches_jwt()
```

والقاعدة:

```text
cross tenant = immediate deny
```

ولا نعتمد على:

```text
client supplied tenant_id
```

كمصدر ثقة.

---

# Phase 10 — RPC Security Hardening

هذه مرحلة واسعة جدًا.

يجب عمل inventory لكل:

```text
CREATE FUNCTION ... SECURITY DEFINER
```

ثم تصنيف كل RPC:

### Public

مثل:

```text
get_public_settings()
get_constant()
```

### Authenticated

مثل:

```text
check_student_app_access()
logout_current_user()
```

### Privileged

مثل:

```text
admin operations
settings.write
user management
session management
```

### Internal/service role

مثل:

```text
workers
maintenance
PII decrypt
background jobs
```

ثم يتم تطبيق least privilege.

الـpermissions الحالية بالفعل تطبق revoke/grant واسعًا، لكن يجب جعلها measurable عبر tests.

---

# Phase 11 — Security Definer Audit

كل:

```text
SECURITY DEFINER
```

يجب أن يمر بهذه القائمة:

```text
fixed search_path
explicit schema qualification
no dynamic SQL unless necessary
no user-controlled privilege escalation
explicit execution grants
no unnecessary exposure
explicit tenant constraints
explicit auth.uid validation
```

Supabase توصي بتثبيت `search_path` واستخدام Security Definer بحذر، كما لا يلزم exposing هذه functions للـPostgREST عندما تُستخدم من RLS بشكل مؤهل بالـschema. ([Supabase][1])

---

# Phase 12 — Resource Authorization

نراجع كل resource حساس.

بالنسبة للفيديوهات:

```text
lesson
course
lesson_content
download
progress
video_views
```

يجب أن يكون المسار:

```text
valid session
      ↓
tenant
      ↓
course
      ↓
enrollment/access
      ↓
resource
```

---

# Phase 13 — إصلاح `get_lesson_content()`

قبل:

```text
find lesson
check access
return videoPath
```

بعد:

```text
assert_valid_session()
assert_tenant()

resolve lesson

verify:
published
not deleted
course tenant
course access

audit decision

return content
```

ويجب ألا تكون `videoPath` متاحة بواسطة جدول مباشر إذا كان RPC هو الـintended gate.

---

# Phase 14 — حماية Storage وVideo URLs

هذه نقطة مهمة جدًا في EduZone.

إذا كانت الفيديوهات في Supabase Storage أو private backend:

```text
لا يكفي حماية metadata بالـRLS
```

يجب منع المستخدم من أخذ direct object URL bypassing authorization.

التصميم:

```text
authorized RPC
      ↓
short-lived signed URL / gated stream
```

أو proxy يطبق authorization قبل إصدار الرابط.

---

# Phase 15 — Device Binding

الـdevice binding الحالي جيد كـlogical binding.

لكن سنثبت invariants:

```text
device belongs to user
device belongs to tenant
device active
device not revoked
maximum device count enforced
concurrent binding race safe
```

ونضيف tests:

```text
same device → allow
different device → deny/bind policy
revoked device → deny
two concurrent binds → deterministic
user A device → user B denied
```

---

# Phase 16 — Session Lifecycle

يجب توحيد دورة الحياة:

```text
LOGIN
  ↓
DEVICE VALIDATION
  ↓
ACCESS VALIDATION
  ↓
SESSION RECORD
  ↓
ACTIVE
  ↓
MONITORING
  ↓
REVOCATION
  ↓
FORCED LOGOUT
  ↓
LOCAL CLEANUP
```

وكل transition له test.

المشروع لديه `session_locks` و`active_sessions` وtrigger لتقليل race conditions.

سنثبت correctness بدل الاكتفاء بوجودها.

---

# Phase 17 — Single Active Session

بما أن المشروع لديه:

```text
active_sessions
sessions
session_locks
trg_enforce_single_active_session
```

فهذا يصبح invariant:

```text
user → <= 1 active application session
```

ويجب اختبار:

```text
login device A
login device B
simultaneous login A+B
logout A while B logs in
refresh A during B login
```

مع تحديد policy بوضوح:

```text
new login revokes old
```

أو العكس.

الكود الحالي يميل إلى:

```text
new session → deactivate previous
```

سنثبت ذلك باختبار concurrent transaction فعلي.

---

# Phase 18 — Fix Flutter Authentication State

Flutter لا يجب أن يعتبر:

```text
network failure = unauthenticated
```

نضيف state مثل:

```text
AuthVerificationPending
```

أو:

```text
AuthDegraded
```

### سلوك startup

إذا كان:

```text
session != null
```

ثم حدث network timeout:

```text
لا نمسح session
لا نرسل logout
لا نذهب تلقائيًا إلى login
```

بل:

```text
retain session
retry verification
```

إلا إذا server أكد denial.

---

# Phase 19 — Improve Auth Router Semantics

GoRouter جيد حاليًا.

لكن بعد إضافة degraded state:

```text
Authenticated
AuthVerificationPending
Unauthenticated
Restricted
```

نحتاج routing behavior:

```text
Authenticated → app
VerificationPending → app / blocking overlay حسب operation
Unauthenticated → login
Restricted → restriction page
```

ولا يتم عرض Login بسبب temporary network outage.

---

# Phase 20 — Authentication Error Policy

يجب تقسيم errors إلى:

```text
AUTH_DENIED
AUTH_EXPIRED
AUTH_REVOKED
AUTH_UNAVAILABLE
AUTH_SERVER_ERROR
DEVICE_DENIED
TENANT_DENIED
PERMISSION_DENIED
```

بدل mapping عام جدًا.

هذا سيساعد:

* UI
* logs
* telemetry
* automated tests
* incident response

---

# Phase 21 — Logout Hardening

الـLogoutOrchestrator الحالي قوي.

سنحافظ عليه، مع ضمان:

```text
server revocation
```

قبل إنهاء session إذا كان الاتصال متاحًا.

وعند انقطاع الاتصال:

```text
local logout still succeeds
```

لكن server must mark the next valid request/session appropriately.

---

# Phase 22 — Passive Revocation

Flutter يجب أن يتعامل مع:

```text
SIGNED_OUT
TOKEN_REFRESHED + null session
SERVER ACCESS DENIED
TOKEN_VERSION MISMATCH
ACCOUNT STATUS CHANGE
```

لكن notification من Realtime ليست security authorization decision.

هي فقط:

```text
fast signal
```

والقرار النهائي:

```text
server
```

---

# Phase 23 — Custom Access Token Hook

الكود الحالي يحتوي `custom_access_token` hook لإضافة claims.

سنحافظ عليه، لكن نراجع:

```text
required Supabase claims
role
session_id
aud
iss
sub
exp
iat
aal
```

ولا ينبغي حذف/تشويه claims الأساسية التي يتوقعها Supabase. الوثائق الحالية توضح claims المطلوبة والاختيارية للـCustom Access Token Hook. ([Supabase][2])

ويجب اختبار:

```text
initial login
refresh token
password login
token refresh
role change
token_version change
account status change
```

للتأكد من سلوك hook.

---

# Phase 24 — JWT Claim Freshness

يجب فهم نقطة مهمة:

Custom access token hook يعمل عند إصدار/تحديث access token، وليس magic mechanism لإبطال JWT قديم فورًا. ([Supabase][2])

لذلك:

```text
token_version claim
```

يستخدم كـreference، لكن:

```text
DB session validation
```

هو ما يجب أن يضمن revocation عندما يتطلب النظام ذلك.

---

# Phase 25 — RLS Consolidation

سنقوم بعمل:

```text
RLS inventory
```

لكل جدول:

| Table | Exposed | RLS | FORCE RLS | SELECT | INSERT | UPDATE | DELETE |
| ----- | ------- | --- | --------- | ------ | ------ | ------ | ------ |

ثم نحدد:

```text
owner policy
tenant policy
admin policy
service role access
deny by default
```

---

# Phase 26 — إزالة Policy Duplication

نبحث عن patterns مثل:

```text
DROP POLICY ...
CREATE POLICY ...
DROP POLICY ...
CREATE POLICY ...
```

وننتج final policy set واضح لكل table.

الهدف:

```text
one obvious authorization model per operation
```

وليس مجموعة patches تاريخية.

---

# Phase 27 — Policy Effective-Semantics Tests

هذه مهمة جدًا.

لا نختبر SQL file فقط.

نختبر database behavior:

```text
SELECT
INSERT
UPDATE
DELETE
```

لكل persona.

Supabase يوضح أن RLS policy تعمل كـimplicit `WHERE` لكل access، وبالتالي الاختبار يجب أن يكون على السلوك النهائي للـdatabase. ([Supabase][1])

---

# Phase 28 — RLS Performance Hardening

لا نحذف authorization checks بهدف الأداء.

بدل ذلك:

* indexing على `user_id`
* `tenant_id`
* `course_id`
* `role_id`
* `permission`
* `token/version` حيث يلزم
* استخدام `(select auth.uid())` في policies عندما تكون القيمة ثابتة أثناء statement
* تجنب joins غير الضرورية

Supabase توصي صراحة باستخدام indexes ولف helper calls بـ`select` عندما يكون مناسبًا، لأنها قد تحسن RLS performance بشكل كبير. ([Supabase][1])

---

# Phase 29 — Permission Grants Audit

المطلوب الوصول إلى:

```text
anon:
  minimum possible

authenticated:
  only required DML + SELECT + RPCs

service_role:
  internal privileged access

supabase_auth_admin:
  only auth hook permissions
```

Supabase توضح أن Auth Hooks PostgreSQL functions تحتاج grants مخصصة لـ`supabase_auth_admin` مع ضبط permissions، ويجب ألا تكون متاحة عشوائيًا عبر Data APIs. ([Supabase][3])

---

# Phase 30 — Auth Hook Permission Audit

نتحقق فعليًا من:

```text
EXECUTE custom_access_token
```

وأن:

```text
anon
authenticated
public
```

لا يملكون execution غير المقصود.

---

# Phase 31 — Service Role Audit

أي code يستخدم:

```text
service_role
```

يجب ألا يصل للـFlutter client.

نراجع:

```text
Edge Functions
backend scripts
CI/CD
environment variables
GitHub Actions
.env
build configuration
```

---

# Phase 32 — Secure Logging

يتم حظر تسجيل:

```text
password
access_token
refresh_token
service_role key
JWT full value
PII
signed URLs
```

ويُسمح فقط بـ:

```text
user_id
session_id
tenant_id
event
reason code
timestamp
correlation ID
```

---

# Phase 33 — Audit Trail

كل security event مهم يجب أن يكون قابلًا للتتبع:

```text
login_success
login_failed
logout
forced_logout
token_revoked
device_bound
device_rejected
role_changed
permission_changed
account_locked
account_banned
cross_tenant_denied
resource_denied
```

مع عدم تخزين secrets.

---

# Phase 34 — Automated Test Matrix

ننشيء suite مستقلة:

```text
test/security/auth/
test/security/session/
test/security/rbac/
test/security/rls/
test/security/tenant/
test/security/device/
```

---

# Phase 35 — Server-side Security Tests

أهم tests:

### Test 1

```text
valid JWT + matching DB version
→ ALLOW
```

### Test 2

```text
valid JWT + DB version incremented
→ DENY
```

### Test 3

```text
JWT missing token_version
→ DENY
```

### Test 4

```text
inactive account
→ DENY
```

### Test 5

```text
deleted account
→ DENY
```

### Test 6

```text
wrong tenant
→ DENY
```

### Test 7

```text
student → admin RPC
→ DENY
```

### Test 8

```text
admin → authorized RPC
→ ALLOW
```

### Test 9

```text
student → another user's data
→ DENY
```

### Test 10

```text
old JWT after role revocation
→ DENY
```

---

# Phase 36 — Resource Security Tests

بالنسبة للـlesson:

```text
preview → allow
enrolled → allow
expired enrollment → deny
revoked enrollment → deny
wrong tenant → deny
banned user → deny
old revoked JWT → deny
teacher authorized → allow
admin authorized → allow
```

---

# Phase 37 — Flutter Unit Tests

يجب إضافة tests لـ:

```text
AuthInitializing
AuthAuthenticating
AuthAuthenticated
AuthUnauthenticated
AuthRestricted
AuthLoggingOut
AuthForceUpdate
AuthVerificationPending
```

والـtransitions بينها.

---

# Phase 38 — Flutter Integration Tests

سيناريو:

```text
launch
→ existing session
→ server valid
→ home
```

ثم:

```text
launch
→ existing session
→ server unavailable
→ retain session/degraded
```

ثم:

```text
launch
→ revoked session
→ login
```

ثم:

```text
authenticated
→ admin revokes
→ app detects
→ cleanup
→ login
```

---

# Phase 39 — Concurrent/Race Tests

يجب اختبار:

```text
login + startup simultaneously
logout + token refresh
logout + realtime event
login A + login B
device binding A + B
role change + API request
revocation + API request
```

والهدف:

```text
no stale state
no privilege retention
no data leakage
```

---

# Phase 40 — Abuse Tests

يتم اختبار:

```text
direct PostgREST
direct RPC calls
modified tenant_id
modified user_id
modified course_id
modified role
modified device_id
replayed old JWT
stale JWT after revocation
rapid RPC calls
cross-user enumeration
cross-tenant enumeration
```

هذه الاختبارات مهمة لأن المهاجم لن يستخدم Flutter UI.

---

# Phase 41 — Production-like Supabase Environment

لا نعتمد فقط على local Supabase.

يجب إنشاء:

```text
staging Supabase project
```

بنفس:

* schema
* hooks
* RLS
* grants
* functions
* config
* Edge Functions

ثم تشغيل الاختبارات عليه.

---

# Phase 42 — Migration Safety

كل تغيير في production schema يجب أن يكون migration آمنًا.

ترتيب مثل:

```text
ADD new function
→ test
→ switch callers
→ validate
→ remove old function
```

وليس:

```text
DROP old
→ hope new works
```

خصوصًا `validate_user_session()` لأنها dependency مركزية.

---

# Phase 43 — Compatibility Layer

لمنع breakage، يمكن لفترة قصيرة:

```text
validate_user_session_v2()
```

ثم:

```text
assert_valid_session_v2()
```

وتغيير consumers تدريجيًا:

```text
RLS
RPC
admin functions
access functions
```

بعد نجاح الاختبارات يتم حذف القديمة.

---

# Phase 44 — Deployment Order

الترتيب الذي أوصي به:

```text
1. Add v2 security primitives
2. Add tests
3. Deploy staging
4. Validate
5. Switch check_student_app_access
6. Switch admin authorization
7. Switch resource RPCs
8. Switch RLS
9. Switch Flutter
10. Run integration suite
11. Production deploy
12. Monitor
13. Remove old primitives
```

---

# Phase 45 — Flutter Release Change

بعد إصلاح server:

Flutter يعدل فقط ما يلزم:

### إزالة الاعتماد على:

```text
client-side access = security decision
```

### الإبقاء على:

```text
UI guard
router guard
device validation
Realtime monitoring
session state
logout cleanup
```

---

# Phase 46 — Monitoring بعد الإطلاق

يجب إنشاء alerts لـ:

```text
revoked session accepted
cross-tenant denied
permission denied spike
device-binding failures
token refresh failures
auth failure spike
RPC unauthorized attempts
RLS denied requests
```

---

# Phase 47 — Security Metrics

نراقب:

```text
login success rate
login rejection rate
refresh failures
forced logout count
revoked-session attempts
cross-tenant attempts
device violations
permission denials
RPC access-denied rate
```

---

# Phase 48 — Final Section 8 Gate

لا يتم إعلان:

```text
Section 8 = PASS
```

إلا إذا أصبحت هذه invariants جميعها verified:

```text
[PASS] Authentication
[PASS] Session restoration
[PASS] Refresh
[PASS] Logout
[PASS] Session revocation
[PASS] Token-version enforcement
[PASS] Account deactivation
[PASS] Device binding
[PASS] Tenant isolation
[PASS] RBAC
[PASS] Permissions
[PASS] RLS
[PASS] RPC authorization
[PASS] Resource authorization
[PASS] Navigation guards
[PASS] Race conditions
[PASS] Network resilience
[PASS] Abuse tests
[PASS] Production-like integration
```

---

# 49. Definition of Done

الـimplementation لا يعتبر مكتملًا بمجرد أن:

```text
flutter test
```

ينجح.

Definition of Done الحقيقي:

```text
Code
+
SQL
+
RLS
+
RPC
+
Auth Hook
+
Flutter
+
Integration Tests
+
Security Abuse Tests
+
Staging Verification
+
Production Verification
```

---

# 50. الترتيب العملي الذي أنصح بتنفيذه في EduZone

بدل تنفيذ عشرات التعديلات بالتوازي، ننفذها بهذا الترتيب:

### Milestone A — Session Core

```text
AUTH-FIX-01
AUTH-FIX-02
AUTH-FIX-03
AUTH-FIX-04
```

أي:

```text
validate_user_session
assert_valid_session
check_student_app_access
admin session validation
```

### Milestone B — Authorization Core

```text
tenant
RBAC
permissions
course access
lesson access
```

### Milestone C — RLS

```text
users
roles
user_roles
enrollments
progress
courses
lessons
devices
sessions
notifications
```

### Milestone D — RPC/Grants

```text
SECURITY DEFINER
EXECUTE
anon
authenticated
service_role
supabase_auth_admin
```

### Milestone E — Session/Device

```text
single session
device binding
revocation
logout
```

### Milestone F — Flutter

```text
auth state
transient failures
router
passive revocation
cleanup
```

### Milestone G — Security Testing

```text
unit
integration
RLS
RPC
abuse
concurrency
staging
```

### Milestone H — Production Gate

```text
security checklist
evidence
deployment
monitoring
rollback
```

---

# 51. نقطة مهمة جدًا في تنفيذ الإصلاح

لا أوصي بإصلاح `validate_user_session()` فقط ثم اعتبار المشكلة انتهت.

لأن المشكلة الحالية **structural dependency problem**:

```text
validate_user_session()
        ↓
RLS
        ↓
admin helpers
        ↓
RPCs
        ↓
resource access
        ↓
Flutter monitoring
```

لذلك يجب أن يكون الإصلاح **Security Dependency Graph** وليس patch واحد.

والنتيجة النهائية التي نريدها:

```text
                     ┌──────────────────────┐
                     │     Supabase Auth     │
                     └──────────┬───────────┘
                                │
                                ▼
                     ┌──────────────────────┐
                     │ Valid Session        │
                     │ DB-backed revocation │
                     └──────────┬───────────┘
                                │
                ┌───────────────┼───────────────┐
                ▼               ▼               ▼
             Tenant           RBAC          Device
                │               │               │
                └───────────────┼───────────────┘
                                ▼
                     ┌──────────────────────┐
                     │ Resource Permission │
                     └──────────┬───────────┘
                                ▼
                         RLS / RPC Gate
                                ▼
                             ALLOW
```

بهذا الشكل، حتى لو تم تجاوز Flutter بالكامل، أو تم استدعاء PostgREST/RPC مباشرة، أو تم استخدام JWT قديم، يبقى القرار النهائي في PostgreSQL/Supabase.

وهذا هو الهدف الحقيقي من إصلاح Section 8.

Supabase نفسها تعتبر RLS primitive أساسية لحماية البيانات عند الوصول عبر الـAPI، وتوصي باستخدام `auth.uid()`/`auth.jwt()` مع سياسات محكمة وindexes وSecurity Definer functions عند الحاجة، بينما Custom Access Token Hook مناسب لإضافة claims لكنه لا يلغي الحاجة إلى تصميم server-side authorization صحيح. ([Supabase][2])

**أولوية التنفيذ الآن واضحة: ابدأ بـ Milestone A، وبالأخص إعادة بناء `validate_user_session()` كـsingle server-side security primitive، ثم لا تسمح لأي RLS/RPC/resource authorization بالالتفاف عليها.**

[1]: https://supabase.com/docs/guides/database/postgres/row-level-security?utm_source=chatgpt.com "Row Level Security | Supabase Docs"
[2]: https://supabase.com/docs/guides/auth/auth-hooks/custom-access-token-hook?utm_source=chatgpt.com "Custom Access Token Hook | Supabase Docs"
[3]: https://supabase.com/docs/guides/auth/auth-hooks?utm_source=chatgpt.com "Auth Hooks | Supabase Docs"
