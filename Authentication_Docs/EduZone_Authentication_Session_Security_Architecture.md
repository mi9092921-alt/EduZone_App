 بالنسبة إلى `lib/features/auth` لا يكفي أن يكون تسجيل الدخول يعمل؛ يجب أن تصبح authentication subsystem ذات **security boundary واضحة، session lifecycle deterministic، failure-safe، وقابلة للإثبات بالاختبارات**. وهذا يتوافق مباشرة مع متطلبات المشروع الخاصة بـ login/logout/session restoration/token expiration/refresh/invalidation/device binding/revoked sessions/navigation races، ومع قاعدة أن authorization الحقيقي يجب أن يكون server-side. 

سأتعامل مع الهدف على أنه:

> **Authentication subsystem جاهز للإطلاق ضمن حدود ما يمكن إثباته، وليس مجرد “لا توجد أخطاء analyzer”.**

وأيضًا لن أستخدم عبارة “بلا ثغرات” كحقيقة مطلقة؛ لا يمكن إثبات انعدام كل vulnerabilities، لكن يمكن بناء subsystem يقلل attack surface ويجتاز security gates محددة.

# Auth Production Architecture

أقترح أن تصبح `lib/features/auth` بهذا الشكل:

```text
lib/features/auth/
├── data/
│   ├── datasources/
│   │   ├── auth_remote_data_source.dart
│   │   └── auth_local_data_source.dart
│   │
│   ├── models/
│   │   ├── auth_session_model.dart
│   │   ├── auth_user_model.dart
│   │   └── auth_state_model.dart
│   │
│   └── repositories/
│       └── auth_repository_impl.dart
│
├── domain/
│   ├── entities/
│   │   ├── auth_session.dart
│   │   └── authenticated_user.dart
│   │
│   ├── repositories/
│   │   └── auth_repository.dart
│   │
│   └── usecases/
│       ├── sign_in.dart
│       ├── sign_out.dart
│       ├── restore_session.dart
│       ├── refresh_session.dart
│       ├── verify_session.dart
│       └── invalidate_session.dart
│
├── application/
│   ├── providers/
│   │   ├── auth_state_provider.dart
│   │   ├── session_provider.dart
│   │   └── auth_controller.dart
│   │
│   └── auth_state_machine.dart
│
└── presentation/
    ├── pages/
    ├── widgets/
    └── states/
```

لكن لن ننشئ كل هذه الملفات لمجرد اتباع Clean Architecture. تعليمات المشروع نفسها تمنع abstraction غير الضروري. 

---

# المرحلة 1 — Auth Audit قبل أي تعديل

نبدأ بتحديد المسار الفعلي:

```text
main()
 ↓
AppInitializer
 ↓
Supabase initialization
 ↓
Auth state listener
 ↓
Session restoration
 ↓
Riverpod state
 ↓
GoRouter
 ↓
Login
 ↓
Session
 ↓
Protected features
```

نحدد بالضبط:

```text
Who creates session?
Who stores session?
Who refreshes token?
Who listens to auth changes?
Who logs out?
Who redirects?
Who validates device?
Who handles revoked account?
Who handles expired token?
```

الهدف هو التخلص من duplicate auth authorities.

---

# المرحلة 2 — Authentication State Machine

لا نريد:

```dart
bool isLoggedIn;
bool isLoading;
bool hasError;
User? user;
```

منتشرة في أماكن مختلفة.

نريد state machine واضحة:

```text
UNKNOWN
   ↓
INITIALIZING
   ↓
UNAUTHENTICATED
   ↓
AUTHENTICATING
   ↓
AUTHENTICATED
   ↓
REFRESHING
   ↓
AUTHENTICATED
```

وحالات الفشل:

```text
AUTH_ERROR
SESSION_EXPIRED
SESSION_REVOKED
ACCOUNT_DISABLED
DEVICE_REJECTED
NETWORK_UNAVAILABLE
```

مع transition rules محددة.

---

# المرحلة 3 — Startup Race Elimination

أحد أخطر الأماكن في Flutter authentication هو startup race:

```text
App starts
↓
Router checks auth
↓
Auth restoration has not finished
↓
Router assumes logged out
↓
redirect login
↓
session restored
↓
redirect back
```

أو العكس.

الحل:

```text
App bootstrap
↓
Auth initialization complete
↓
Auth state becomes authoritative
↓
Router starts making protected-route decisions
```

ولا يسمح للـ router باستنتاج auth state من null مؤقت.

---

# المرحلة 4 — Session Authority

يجب أن تكون هناك **جهة واحدة** مسؤولة عن session state.

مثلاً:

```text
AuthSessionManager
```

وظيفتها:

```text
restore
observe
refresh
invalidate
clear
```

ولا نريد أن يقوم:

```text
UI
Repository
Router
Service
Provider
```

كل واحد بإدارة session بشكل جزئي.

---

# المرحلة 5 — Secure Session Storage

نراجع مكان حفظ:

```text
access token
refresh token
session metadata
user identity
device binding data
```

القاعدة:

```text
Never SharedPreferences for secrets
Never SQLite plaintext for secrets
Never logs
Never URL/query parameters
```

ويجب أن يكون secure storage هو المسار الأساسي للبيانات السرية.

تعليمات المشروع نفسها تطلب عدم كشف tokens أو privileged credentials. 

---

# المرحلة 6 — Token Lifecycle

نحتاج lifecycle صريح:

```text
ACCESS TOKEN
    ↓
near expiry
    ↓
REFRESH
    ↓
new ACCESS TOKEN
```

وعند refresh failure:

```text
refresh failed
    ↓
classify
    ├── transient network error → preserve session state safely
    ├── invalid refresh token → invalidate session
    └── account/session revoked → force logout
```

لا يجوز أن يؤدي transient network failure مباشرة إلى logout.

---

# المرحلة 7 — Refresh Race Protection

مشكلة شائعة جدًا:

```text
Request A → token expired
Request B → token expired
Request C → token expired

A refreshes
B refreshes
C refreshes
```

قد يؤدي ذلك إلى inconsistent session state.

نحتاج single-flight refresh:

```text
Refresh request
      ↓
existing refresh in progress?
      ↓
YES → await same Future
NO  → start refresh
```

ويجب اختبار هذا تحت concurrency.

---

# المرحلة 8 — Unauthorized Request Handling

كل HTTP/Supabase request محمي يجب أن يفرق بين:

```text
401 unauthenticated
403 unauthorized
network failure
server failure
revoked session
```

ولا نريد:

```text
any error → logout
```

بل:

```text
401 + valid refresh path
    → refresh

401 + invalid refresh
    → logout

403
    → authorization failure

network
    → retain session where safe
```

---

# المرحلة 9 — Server-Side Authorization Boundary

هذه نقطة أساسية:

```text
UI says user is teacher
```

ليست security boundary.

كذلك:

```dart
if (role == admin) ...
```

لا يكفي.

الـ backend/Supabase يجب أن يفرض:

```text
RLS
policies
RPC authorization
Edge Function authorization
```

والتطبيق يكتفي بإظهار/إخفاء UI بناءً على state المعتمد.

هذا منصوص عليه صراحة في تعليمات المشروع. 

---

# المرحلة 10 — User Object Minimization

لا نحتاج الاحتفاظ بكل ما يأتي من backend.

نحدد:

```text
AuthenticatedUser
```

ويحتوي فقط على data المطلوبة:

```text
id
email
status
roles/claims required by client
device binding state
```

مع تجنب نسخ raw Supabase user metadata في عدة layers.

---

# المرحلة 11 — Account State

Authentication لا يعني فقط:

```text
logged in
```

نحتاج أيضًا:

```text
ACTIVE
DISABLED
SUSPENDED
REVOKED
DELETED
PENDING
```

إذا أصبح الحساب disabled بعد login، يجب أن يكون هناك path واضح:

```text
server detects
↓
auth state invalidates
↓
local session cleared
↓
protected resources inaccessible
```

---

# المرحلة 12 — Device Binding

بما أن EduZone لديه device binding، لا نجعل login مجرد username/password + session.

نحتاج:

```text
Authenticate user
+
identify device
+
validate device authorization
+
establish session
```

لكن لا نسمح للـ client بتقرير:

```text
device is trusted
```

بمفرده.

Server يجب أن يكون authoritative.

---

# المرحلة 13 — Device Change Handling

حالات مهمة:

```text
new device
app reinstall
OS upgrade
identifier change
device fingerprint change
```

لا يجب أن يؤدي تغير non-security-critical identifier تلقائيًا إلى account loss.

نحتاج policy:

```text
known device
new device
rebind required
admin approval required
revoked device
```

---

# المرحلة 14 — Logout يجب أن يكون Transaction

Logout ليس:

```dart
signOut();
```

فقط.

نريد:

```text
stop auth observers
↓
cancel auth-sensitive requests
↓
invalidate local auth state
↓
clear secure session data
↓
clear user-sensitive caches
↓
clear device/session bindings according to policy
↓
notify router
↓
navigate to login
```

والعملية يجب أن تكون idempotent.

---

# المرحلة 15 — Logout During Request

نختبر:

```text
Request started
↓
user logout
↓
response returns
```

ولا نسمح للـ response بإعادة user state بعد logout.

هذا مهم جدًا مع async/Riverpod.

---

# المرحلة 16 — Session Restoration

عند startup:

```text
load stored session
↓
validate expiration
↓
attempt safe refresh if appropriate
↓
verify account status when necessary
↓
publish authenticated state
```

مع distinction بين:

```text
No session
Expired session
Refreshable session
Invalid session
Revoked session
Offline session
```

---

# المرحلة 17 — Offline Authentication Policy

يجب الفصل بين:

```text
authenticated account
```

و

```text
offline content entitlement
```

لأن offline playback له security model منفصل.

يجب ألا يصبح:

```text
No internet
→ blindly trust old auth forever
```

ولا:

```text
No internet
→ delete legitimate offline data
```

هذه policy يجب أن تتفق مع P6 Offline Security.

---

# المرحلة 18 — Login Security

نفحص:

```text
credential transport
TLS
input validation
rate limiting
error messages
account enumeration
brute-force behavior
retry behavior
credential logging
```

رسالة مثل:

```text
Email exists but password incorrect
```

قد تساعد account enumeration.

الأفضل:

```text
Authentication failed
```

مع UX مناسب.

---

# المرحلة 19 — Password Handling

إذا كانت Supabase Auth هي المسؤولة عن password authentication:

لا نخزن password محليًا.

ولا:

```text
password in logs
password in analytics
password in Sentry
password in crash payload
```

ولا نكتب custom password hashing داخل Flutter إذا كان authentication provider مسؤولًا عنها.

---

# المرحلة 20 — Session Event Stream

نحتاج auth event stream موحد:

```text
signedIn
signedOut
tokenRefreshed
sessionExpired
sessionRevoked
accountDisabled
deviceRejected
```

والـ Router وfeatures تتعامل مع هذه الأحداث بطريقة deterministic.

---

# المرحلة 21 — Navigation Guard

GoRouter يجب أن يأخذ:

```text
AuthState
```

ولا يقوم بنفسه بعمل network refresh في redirect.

القاعدة:

```text
Router observes auth state
```

وليس:

```text
Router becomes auth service
```

ونمنع redirect loops.

تعليمات المشروع تطلب صراحة اختبار redirects وsession changes أثناء navigation. 

---

# المرحلة 22 — Deep Link Security

أي deep link مثل:

```text
/course/123
/video/456
/profile
```

يجب أن يعمل:

```text
parse
↓
authenticate if required
↓
authorize resource
↓
open
```

لا:

```text
deep link
→ bypass normal auth flow
```

---

# المرحلة 23 — Error Taxonomy

ننشئ auth errors واضحة:

```text
InvalidCredentials
SessionExpired
RefreshFailed
SessionRevoked
AccountDisabled
DeviceNotAuthorized
NetworkUnavailable
ServerUnavailable
RateLimited
UnknownAuthFailure
```

بدل:

```text
Exception('something went wrong')
```

والـ UI يحولها إلى localized safe messages.

---

# المرحلة 24 — No Error Leakage

ممنوع إظهار:

```text
PostgrestException(...)
JWT details
Supabase endpoint
SQL errors
stack trace
HTTP headers
refresh token errors
```

للمستخدم.

تعليمات المشروع تشترط عدم كشف backend internals أو credentials. 

---

# المرحلة 25 — Auth Logging

نريد observability:

```text
auth.login.started
auth.login.success
auth.login.failure
auth.refresh.success
auth.refresh.failure
auth.logout
auth.session.expired
auth.session.revoked
auth.device.rejected
```

لكن بدون:

```text
password
access token
refresh token
authorization header
sensitive user payload
```

وهذا يتوافق مع logging requirements للمشروع. 

---

# المرحلة 26 — Sentry Privacy

نراجع Sentry تحديدًا حول auth.

ممنوع إرسال:

```text
refresh token
access token
password
raw auth response
session object
```

ويكون user identification:

```text
opaque user ID
```

وفق سياسة privacy، وليس البريد أو بيانات حساسة بلا ضرورة.

---

# المرحلة 27 — Auth Cache Isolation

بعد logout:

```text
User A private cache
```

لا يجوز أن يظهر لـ:

```text
User B
```

لذلك auth invalidation يجب أن يرتبط بـ cache invalidation.

---

# المرحلة 28 — Testing Pyramid

نحتاج:

### Unit

```text
token expiry
session parsing
state transitions
error mapping
refresh coordination
device matching
logout transaction
```

### Widget

```text
login form
validation
loading
error
retry
disabled controls
password visibility
accessibility
```

### Integration

```text
fresh install
login
session restoration
token refresh
logout
revoked session
disabled account
device rejection
deep link
network interruption
```

وهذه متطابقة مع critical auth flows المحددة في تعليمات المشروع. 

---

# المرحلة 29 — Security Test Matrix

نحتاج اختبار:

```text
Wrong password
Wrong email
Empty credentials
Expired access token
Expired refresh token
Invalid refresh token
Revoked session
Disabled account
Network timeout
DNS failure
Server 500
401
403
Concurrent refresh
Logout during request
App kill during refresh
App restart
Device mismatch
Clock manipulation
Deep link while logged out
Deep link after logout
Account switch
```

---

# المرحلة 30 — Fuzz/Abuse Testing

نختبر:

```text
malformed auth response
missing fields
unexpected JSON
null user
invalid timestamps
oversized metadata
malformed JWT
corrupt persisted session
```

خصوصًا parser/model layers.

---

# المرحلة 31 — Persistence Corruption

إذا كانت session metadata أو local auth state تالفة:

```text
load
↓
parse failure
```

لا يحدث:

```text
app crash
```

ولا:

```text
undefined auth state
```

بل:

```text
delete invalid local state
↓
return unauthenticated
↓
safe recovery
```

---

# المرحلة 32 — Concurrency Tests

نحتاج تحديد invariants:

```text
At most one active refresh operation
```

و:

```text
logout always wins over late auth response
```

و:

```text
session cannot move from SIGNED_OUT → AUTHENTICATED
because of stale response
```

---

# المرحلة 33 — Auth Security Guard

نضيف static checks تمنع:

```text
print(token)
print(session)
SharedPreferences for tokens
raw JWT logging
hardcoded credentials
auth logic in widgets
Supabase direct access from presentation
router performing auth mutations
```

---

# المرحلة 34 — Dependency Audit

نراجع dependencies المستخدمة في `auth` فقط:

```text
supabase_flutter
flutter_secure_storage
riverpod
go_router
device_info_plus
crypto if actually required
```

ونسأل لكل dependency:

```text
actually needed?
maintained?
security risk?
platform issue?
duplicate?
```

وهو نفس مبدأ dependency audit المحدد للمشروع. 

---

# المرحلة 35 — Backend Contract

لا نعتبر `lib/features/auth` مكتملة من دون مراجعة backend contract.

يجب مطابقة:

```text
client claims
JWT expectations
RLS
session invalidation
account status
device authorization
Edge Functions
RPCs
```

لأن auth client وحده لا يستطيع إثبات authorization.

---

# المرحلة 36 — Production Kill Switch

يجب وجود mechanism يسمح server-side بإيقاف الدخول/التطبيق في الحالات الطارئة:

```text
maintenance
security incident
forced session invalidation
mandatory upgrade
```

والـ client يتعامل مع ذلك safely.

---

# المرحلة 37 — Session Versioning

يمكن ربط session/account state بـ:

```text
session_version
security_version
device_version
```

بحيث يستطيع server invalidating all previous sessions without الاعتماد فقط على expiry.

---

# المرحلة 38 — Forced Re-authentication

بعض العمليات الحساسة قد تتطلب:

```text
recent authentication
```

مثل:

```text
device rebind
account security changes
sensitive settings
```

ولا نستخدم session قديمة بلا حدود.

---

# المرحلة 39 — Release Gate

لا نعتبر Auth Ready حتى:

```text
[✓] Login verified
[✓] Logout verified
[✓] Session restoration verified
[✓] Refresh verified
[✓] Refresh race tested
[✓] Session revocation verified
[✓] Account deactivation verified
[✓] Device binding verified
[✓] Device mismatch verified
[✓] Navigation guards verified
[✓] Deep links verified
[✓] Secure storage verified
[✓] No secret logging
[✓] Error leakage reviewed
[✓] RLS/server authorization verified
[✓] Auth integration tests passing
[✓] Corrupt session recovery tested
[✓] Offline policy verified
[✓] Sentry privacy reviewed
[✓] CI auth security checks passing
```

---

# ترتيب التنفيذ العملي

أرى أن ترتيب العمل الأفضل على EduZone هو:

```text
AUTH-00
Audit current auth implementation

AUTH-01
Define AuthState machine

AUTH-02
Centralize Session Authority

AUTH-03
Secure Session Persistence

AUTH-04
Token Refresh + single-flight coordination

AUTH-05
Logout/invalidation transaction

AUTH-06
Startup/session restoration

AUTH-07
Device binding + device authorization

AUTH-08
GoRouter guard hardening

AUTH-09
Error taxonomy + safe UX

AUTH-10
Auth cache isolation

AUTH-11
Sentry/logging privacy

AUTH-12
Backend/RLS authorization verification

AUTH-13
Unit tests

AUTH-14
Widget tests

AUTH-15
Integration/security tests

AUTH-16
Concurrency/race tests

AUTH-17
Abuse/fuzz tests

AUTH-18
Auth security static guard

AUTH-19
CI production gate

AUTH-20
Final authentication release audit
```

## أهم قاعدة

لا أنصح بإعادة كتابة `lib/features/auth` من الصفر.

الأفضل:

```text
Current Auth
    ↓
Audit
    ↓
Identify actual security gaps
    ↓
Small safe changes
    ↓
Tests
    ↓
Verify
    ↓
Next gap
```

وهذا متوافق مباشرة مع قاعدة المشروع: **incremental hardening، root-cause analysis، وأصغر diff آمن**. 

وبالنسبة إلى EduZone تحديدًا، **أول خطوة فعلية هي AUTH-00**: تفكيك `lib/features/auth` بالكامل وربط كل ملف بالـ callers والـ providers والـ Supabase calls والـ router والـ secure storage، ثم استخراج جدول `attack surface → current implementation → vulnerability → severity → test → fix`. هذا سيعطينا baseline حقيقي قبل أي إعادة تصميم.
