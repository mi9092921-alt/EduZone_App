# EduZone — Download Subsystem Re-Architecture Prompt

## 0. قبل أن تبدأ: افهم لماذا نفعل هذا

أنت تعمل على Repository:

```text
https://github.com/mi9092921-alt/EduZone_App.git
```

المهمة ليست "تحسين كود التنزيل" بشكل تجميلي، وليست إعادة كتابة `DownloadManager` من الصفر.

**الهدف هو حل مشكلة حقيقية في سلوك التنزيل:**

```text
1. التنزيل بطيء أو يتباطأ بشدة.
2. التنزيل قد يعمل فترة طويلة ثم يفشل.
3. عند حدوث failure قد نفقد التقدم الذي تم تنزيله.
4. انتهاء signed CDN URL يمكن أن يحدث أثناء التنزيل.
5. التطبيق قد ينتقل للخلفية أو يتم قتله ثم يعاد فتحه.
6. النظام الحالي لا يملك durable chunk-level recovery حقيقيًا.
```

نحن نريد تحويل النظام الحالي إلى:

```text
Persistent Resumable Encrypted Download Engine
```

بحيث يصبح سلوكه للمستخدم قريبًا وظيفيًا من تنزيل YouTube:

```text
بدء سريع
→ استمرار حتى مع شبكة ضعيفة
→ تحمل التباطؤ
→ retry ذكي
→ استئناف حقيقي
→ استئناف بعد إغلاق التطبيق
→ استئناف بعد انقطاع الشبكة
→ تحديث signed URL بدون فقدان التقدم
→ background download
→ لا تعيد 800MB بسبب فشل حدث في آخر 20MB
```

### لماذا هذا مهم؟

إذا كانت الشبكة:

```text
2 KB/s
```

فنحن لا نستطيع اختراع bandwidth غير موجودة.

لكن نستطيع منع النظام من اعتبار الشبكة البطيئة "failure".

السلوك المطلوب:

```text
2 KB/s
↓
يستمر التنزيل
↓
لا full-file timeout
↓
لا full-file restart
↓
لا فقدان progress
↓
عندما تتحسن الشبكة:
2 KB/s → 20 KB/s → 200 KB/s → 2 MB/s
↓
النظام يستفيد تلقائيًا
```

إذن الهدف الحقيقي هو:

```text
maximize sustained throughput
+
minimize wasted bytes
+
maximize recovery reliability
```

وليس مجرد زيادة عدد workers.

---

# 1. قاعدة أساسية: لا تعيد كتابة النظام

المستودع الحالي لديه بالفعل مكونات مهمة وصحيحة:

```text
DownloadManager
DownloadExecutionService
EncryptionService
PlannedChunk
planChunkLayout()
totalEncryptedSizeForPlan()
SQLite / StorageService
background_downloader
URL refresh
certificate pinning
offline authorization
account binding
device binding
checksum/integrity
```

و`EncryptionService` لديه بالفعل encrypted chunk layout deterministic مناسب للكتابة المتوازية إلى offsets معروفة مسبقًا. 

كما أن `DownloadManager` لديه بالفعل Dio + Range downloads + retry/backoff + URL refresh. 

لذلك استخدم المبدأ:

```text
EXTEND
→ EXTRACT
→ REFACTOR
→ REWRITE only when proven necessary
```

ممنوع:

```text
REWRITE EVERYTHING
```

بدون evidence.

---

# 2. أول مهمة: Audit قبل أي تعديل

لا تبدأ بالبرمجة.

افحص فعليًا:

```text
lib/features/downloads/
lib/core/services/encryption_service.dart
lib/core/services/storage_service.dart
lib/features/downloads/data/services/download_manager.dart
lib/features/downloads/data/repositories/download_execution_service.dart
lib/features/downloads/data/repositories/download_repository_impl.dart
lib/features/downloads/data/datasources/download_local_ds.dart
lib/features/downloads/data/datasources/download_remote_ds.dart
```

وافحص:

```text
tests
integration tests
Supabase download-related functions
```

أخرج actual call graph:

```text
UI
→ Provider
→ Repository
→ DownloadExecutionService
→ DownloadManager
→ Transport
→ Encryption
→ Storage
```

وحدد بدقة:

```text
Who owns runtime state?
Who owns persistent state?
Who owns retry?
Who owns URL refresh?
Who owns encryption?
Who owns filesystem writes?
Who owns background execution?
Who owns authorization?
```

لا تعتمد على أسماء classes فقط.
اتبع actual data/control flow.

---

# 3. المطلوب الرئيسي: Root Cause Analysis

قبل implementation أجب بالأدلة:

## لماذا التنزيل بطيء؟

افحص:

```text
CDN throughput
HTTP Range behavior
connection setup
TTFB
worker count
range size
Dio overhead
background_downloader overhead
disk write throughput
encryption throughput
isolate overhead
SQLite writes
progress callback frequency
UI rebuild frequency
logging
```

## لماذا يفشل بعد مدة؟

افحص:

```text
idle timeout
receive timeout
network disconnect
CDN URL expiry
401 / 403 / 410
429
5xx
partial response
truncated response
worker Future failure
Future.wait failure propagation
process death
background suspension
disk full
file corruption
SQLite state mismatch
```

كل Finding يجب أن يصنف:

```text
CONFIRMED
LIKELY
POSSIBLE
NOT REPRODUCED
```

وإذا كان السبب غير مثبت، لا تدعي أنه مثبت.

---

# 4. أهم finding يجب التحقيق فيه

افحص المسار الحالي:

```text
startEncryptedDownload()
```

ثم:

```text
DownloadExecutionService._downloadTrackEncrypted()
```

المستودع الحالي يملك encrypted fast path، لكن عندما لا يستطيع هذا المسار الإكمال، يوجد fallback إلى:

```text
download plaintext
→ temporary file
→ encryptFile()
```

وهذا لا نريده كنظام production الرئيسي. 

الهدف الجديد:

```text
Network
→ bounded buffer
→ AES-256-GCM
→ encrypted file
```

وليس:

```text
Network
→ plaintext whole file
→ disk
→ encrypt later
```

---

# 5. مشكلة البطء ليست "التشفير" بشكل تلقائي

مهم جدًا:

**لا تفترض أن AES-GCM هو السبب الرئيسي.**

قم بقياس:

```text
network MB/s
encryption MB/s
disk write MB/s
```

ثم قارن:

```text
network only
network + encryption
network + encryption + disk
```

وأظهر أين يوجد bottleneck.

قم بقياس encryption على الأقل لـ:

```text
512 KiB
1 MiB
2 MiB
4 MiB
8 MiB
```

وقِس:

```text
wall-clock time
MB/s
CPU
memory
```

إذا كانت encryption أسرع بكثير من network، فلا تضيّع وقت المشروع في micro-optimizing AES.

إذا كانت encryption هي bottleneck فعلًا، عندها حسّنها.

---

# 6. لا تغير EncryptionService بدون سبب قوي

المشروع لديه بالفعل:

```text
AES-256-GCM
unique key per download
secure key storage
SHA-256 integrity
chunked encrypted format
PlannedChunk
deterministic encrypted offsets
```

لا تلغ أيًا منها.

الهدف:

```text
preserve security
+
improve throughput
+
make recovery durable
```

وليس:

```text
remove encryption for speed
```

---

# 7. التحول الجوهري: Persistent Download Session

أنشئ مفهومًا واضحًا لـ:

```text
DownloadSession
```

يمكن أن تكون class/domain model وليس بالضرورة abstraction عملاقة.

يجب أن تحتوي على الأقل على:

```text
downloadId
lessonId
courseId
contentVersion
quality
trackType
totalBytes
chunkSize
totalChunks
completedBytes
status
createdAt
updatedAt
sourceIdentity
entitlementId
expiresAt
encryptionVersion
containerVersion
```

`downloadId` يجب أن يبقى ثابتًا خلال resume/recovery.

---

# 8. Persistent Chunk Manifest

هذه أهم خطوة في المهمة.

أضف local persistent chunk state باستخدام SQLite الحالي.

لا تستخدم Supabase لتخزين chunk progress.

نحتاج concept مثل:

```text
download_chunks
```

ببيانات مثل:

```text
downloadId
chunkIndex
plaintextStart
plaintextLength
encryptedOffset
encryptedLength
state
downloadedBytes
attempts
checksum
updatedAt
lastError
committedAt
```

الحالات:

```text
pending
fetching
encrypting
persisted
verified
failed
```

---

# 9. لماذا نحتاج Chunk Manifest؟

لأن حاليًا وجود state في memory مثل:

```text
_activeDownloadIds
_progressControllers
_pausedDownloads
_cancelledDownloads
```

لا يكفي للاسترداد بعد:

```text
app restart
process death
background interruption
device/network transition
```

هذه runtime state وليست durable source of truth.

المطلوب:

```text
Memory
=
runtime acceleration

SQLite manifest
=
persistent recovery truth
```

بعد restart:

```text
Memory = empty
SQLite = intact
```

ومن SQLite نعيد بناء الجلسة.

---

# 10. استخدم PlannedChunk الموجود

لا تعيد اختراع chunk planning.

المشروع لديه:

```text
PlannedChunk
planChunkLayout()
totalEncryptedSizeForPlan()
chunkIndexFromPlan()
```

استخدمها كأساس. 

المطلوب:

```text
Planning
→ persistent manifest
→ scheduling
→ download
→ encrypt
→ write
→ verify
→ commit
```

وليس إنشاء encryption format جديد.

---

# 11. Chunk Scheduler

أضف طبقة مسؤولة عن scheduling فقط.

مثل:

```text
ChunkScheduler
```

وظيفتها:

```text
select pending chunks
→ allocate worker
→ execute chunk
→ commit result
→ schedule next chunk
```

ولا تجعل العدد ثابتًا بلا benchmark.

ابدأ بتجربة:

```text
1
2
3
4
```

workers.

ثم قِس throughput.

---

# 12. Adaptive concurrency

لا تقل:

```text
4 workers = better
```

إلا إذا أثبت benchmark ذلك.

اختبر:

```text
single worker
2 workers
3 workers
4 workers
```

وعلى أحجام مختلفة:

```text
100 MB
500 MB
1 GB
```

وقِس:

```text
sustained MB/s
CPU
RAM
battery impact where feasible
failure rate
```

الهدف:

```text
maximum sustained throughput
```

وليس:

```text
maximum number of connections
```

---

# 13. Chunk-level retry

إذا حدث:

```text
chunk 57 failed
```

بينما:

```text
chunk 0..56 verified
chunk 58..120 verified
```

فقط:

```text
retry chunk 57
```

ممنوع:

```text
restart whole download
```

---

# 14. Partial chunk resume

في الإصدار الأول:

```text
verified encrypted chunk
=
durable

partial in-memory chunk
=
not durable
```

إذا فشل chunk أثناء network transfer:

```text
discard incomplete in-memory chunk
→ retry that chunk
```

ولا تدّعي partial-byte resume داخل AES-GCM record إلا إذا تم تصميمه واختباره بشكل آمن.

لا تضف تعقيدًا cryptographic غير ضروري في المرحلة الأولى.

---

# 15. URL expiration

المشروع لديه بالفعل URL refresh mechanism:

```text
fetchFreshTrackUrl()
handleTokenRefresh()
401 / 403 / 410
```

لا تعيد كتابته من الصفر. 

انقل orchestration إلى مستوى chunk/session:

```text
chunk request
→ 401/403/410
→ classify
→ refresh signed URL
→ validate source identity
→ retry same chunk
```

المهم:

```text
URL expiration
≠
download restart
```

---

# 16. Source identity

لا تعتبر الـsigned URL هو هوية المحتوى.

الجلسة يجب أن ترتبط بـ:

```text
lessonId
contentVersion
quality
trackType
entitlementId
```

عند refresh يجب التأكد أن المصدر الجديد يخص نفس:

```text
lesson
contentVersion
quality
track
```

إذا تغير المحتوى:

```text
invalidate affected session
```

ولا تخلط bytes من content version مختلف.

---

# 17. Atomic Chunk Commit

الترتيب الصحيح:

```text
fetch
→ encrypt
→ write
→ verify
→ commit state
```

ولا:

```text
write
→ mark verified
```

قبل التأكد أن الملف والحالة في SQLite متوافقان.

---

# 18. Crash Recovery

عند startup:

```text
RecoveryService
```

أو recovery logic داخل coordinator يقوم بـ:

```text
load active sessions
→ load chunk manifest
→ inspect encrypted file
→ detect inconsistent states
→ invalidate unsafe chunks
→ resume pending/failed work
```

مثال:

```text
SQLite = VERIFIED
File = corrupted/missing
```

النتيجة:

```text
chunk = invalid
→ redownload
```

وليس:

```text
download = completed
```

---

# 19. Pause / Resume

Pause يجب أن يعني:

```text
stop scheduling
+
persist state
+
allow active work to reach safe abort point
```

وليس مجرد:

```text
CancelToken.cancel()
```

Resume يجب أن يعني:

```text
load manifest
→ select non-verified chunks
→ continue
```

---

# 20. App restart

هذا Acceptance Test إجباري:

```text
start 800MB download
→ reach 350MB+
→ kill application
→ reopen application
→ load session
→ recover manifest
→ resume
```

النتيجة المتوقعة:

```text
continue from verified chunks
```

وليس:

```text
0MB
```

---

# 21. Background execution

لا تحذف:

```text
background_downloader
```

بل اجعله infrastructure/adapter للخلفية.

الـsource of truth:

```text
SQLite DownloadSession + Chunk Manifest
```

وليس:

```text
background_downloader task object
```

إذا مات process، يجب أن يبقى session قابلًا للاسترداد.

---

# 22. Android / iOS

## Android

اختبر:

```text
foreground
background
screen off
process recreation
network switch
```

واستفد من background_downloader والـforeground configuration الموجود حاليًا. 

## iOS

لا تعتبر:

```text
Dio socket
```

native background transfer.

افصل:

```text
foreground engine
+
background-capable platform adapter
```

واختبر lifecycle الحقيقي.

---

# 23. Dual-track downloads

المشروع لديه video + audio track support.

لا تكسره.

يجب أن يصبح التصميم منطقيًا مثل:

```text
DownloadSession
├── video track
│   └── chunks
└── audio track
    └── chunks
```

ولا يصبح:

```text
completed
```

حتى تكتمل جميع الـtracks المطلوبة.

---

# 24. Progress

لا تكتب SQLite على كل packet.

استخدم memory-first progress.

Persistence يكون throttled:

```text
250–500ms
```

أو threshold مناسب.

اعرض:

```text
percentage
speed
ETA
downloaded / total
```

واحسب speed من rolling/smoothed window وليس من بداية download فقط.

---

# 25. Disk full

قبل البدء:

```text
requiredSpace
+
safetyMargin
```

ثم تحقق من disk availability.

إذا امتلأ القرص:

```text
WAITING_FOR_STORAGE
```

أو حالة خطأ قابلة للاسترداد.

لا تحول العملية إلى permanent failed بلا recovery.

---

# 26. Retry policy

فرّق بين:

### Transient

```text
408
429
500+
timeout
connection reset
temporary network loss
```

→ retry.

### URL expiration

```text
401
403
410
```

→ refresh source ثم retry.

### Permanent

مثل:

```text
invalid entitlement
revoked access
invalid content identity
```

→ stop.

لا تستخدم infinite retry.

ضع:

```text
per-chunk attempts
URL refresh attempts
global recovery limit
```

مع backoff مناسب.

---

# 27. Integrity

احتفظ بالمستويات الحالية:

```text
AES-GCM authentication
+
chunk verification
+
final checksum
```

ولا تلغِ SHA-256 أو security signature لمجرد السرعة.

---

# 28. Security

لا تكسر:

```text
offline entitlement
account binding
device binding
certificate pinning
secure key storage
content version validation
OfflinePolicyEngine
```

السرعة ليست سببًا لإضعاف security.

---

# 29. أهم شيء: أزل plaintext fallback من المسار الإنتاجي

نريد:

```text
PRIMARY:
network
→ encrypt
→ persist
```

وإذا كان server لا يدعم Range:

```text
stream
→ bounded buffer
→ AES-GCM
→ persist
```

وليس:

```text
stream
→ whole plaintext file
→ encrypt later
```

إذا تعذر تحقيق resumability لسبب source limitation، كن صريحًا:

```text
resume capability = limited
```

ولا تستخدم plaintext staging كحل سهل.

---

# 30. لا تضف Supabase tables لهذا

Supabase يبقى مسؤولًا عن:

```text
authorization
entitlement
source resolution
signed URL
content version
```

SQLite يبقى مسؤولًا عن:

```text
download session
chunk state
progress
recovery
local file state
```

لا تنشئ chunk manifest على server.

ولا تنشئ migrations جديدة.

إذا احتجت schema server-side change، اتبع canonical schema structure الموجود في المشروع.

---

# 31. Benchmarks

بعد correctness، قم بقياس before/after:

```text
100MB
500MB
1GB
```

قارن:

```text
average MB/s
P50 duration
P95 duration
failure rate
resume success rate
URL refresh recovery success
CPU
RAM
encryption time
disk write time
```

وبالتحديد اختبر شبكة ضعيفة أو throttled network:

```text
2 KB/s
10 KB/s
50 KB/s
200 KB/s
1 MB/s
```

المهم ليس أن نجعل 2KB/s أسرع من 2KB/s.

المهم:

```text
2KB/s does not kill the download
```

---

# 32. Failure Injection

ابنِ test transport أو harness يمكنه حقن:

```text
timeout
connection reset
403
410
429
500
502
503
truncated body
slow stream
empty response
network loss
```

ثم اختبر:

```text
verified chunks remain verified
failed chunk is retried
URL refresh preserves session
app restart preserves progress
corrupted chunk is invalidated
```

---

# 33. اختبارات إلزامية

## Unit tests

```text
ChunkPlanner
ChunkScheduler
RetryPolicy
URL refresh policy
Download state machine
Manifest persistence
Chunk encryption
Chunk verification
Recovery
```

## Integration tests

```text
download
pause
resume
network failure
URL expiry
URL refresh
process restart
disk full
entitlement revoked
corrupted chunk
dual-track failure
```

## Analyzer/tests

```text
flutter pub get
flutter analyze
flutter test
```

وأي test commands خاصة بالمشروع.

---

# 34. Acceptance Criteria

لا تعتبر المهمة مكتملة إلا إذا تحقق:

```text
[ ] No whole-file restart for recoverable chunk failures
[ ] Persistent DownloadSession
[ ] Persistent chunk manifest
[ ] Chunk-level retry
[ ] Resume after network loss
[ ] Resume after app restart
[ ] URL refresh without losing verified progress
[ ] AES-256-GCM preserved
[ ] No plaintext whole-file production fallback
[ ] Existing encrypted format preserved or safely migrated
[ ] Existing offline playback still works
[ ] Existing entitlement checks remain enforced
[ ] Account binding remains enforced
[ ] Device binding remains enforced
[ ] Background execution remains supported
[ ] Pause/resume works
[ ] Dual-track downloads remain correct
[ ] Corruption is detected
[ ] Disk-full state is recoverable
[ ] Progress persistence is throttled
[ ] Reliability is covered by failure-injection tests
[ ] Performance is benchmarked
[ ] flutter analyze passes
[ ] flutter tests pass
[ ] Integration tests pass
```

---

# 35. ترتيب التنفيذ الإلزامي

لا تنفذ كل شيء مرة واحدة.

استخدم هذا الترتيب:

```text
P0
Audit + Root Cause

P1
Persistent DownloadSession

P2
Persistent Chunk Manifest

P3
Integrate existing PlannedChunk

P4
Chunk Transport boundary

P5
Chunk Scheduler

P6
Atomic chunk commit

P7
Crash Recovery

P8
URL refresh integrated with chunk recovery

P9
Pause / Resume

P10
Background recovery

P11
Remove plaintext fallback

P12
Dual-track orchestration

P13
Integrity validation

P14
Failure injection

P15
Performance benchmarking

P16
Backward compatibility

P17
Production verification
```

---

# 36. ممنوعات صريحة

ممنوع:

```text
rewrite entire downloads subsystem
remove AES-GCM for speed
store plaintext whole video on disk
retry entire file after every transient failure
use infinite retries
treat signed URL as content identity
store chunk progress only in memory
store local chunk state in Supabase
delete old downloads without migration strategy
invent benchmark numbers
claim "YouTube speed"
claim "2x faster" without measurements
```

---

# 37. ما أريده منك في النهاية

## A. Root Cause Report

أجب بوضوح:

```text
ما سبب البطء؟
ما سبب الفشل؟
ما دور encryption؟
ما دور CDN؟
ما دور Range?
ما دور worker concurrency؟
ما دور disk I/O؟
ما دور background execution؟
```

كل claim يجب أن يكون:

```text
code evidence
or
test evidence
or
benchmark evidence
```

## B. Current vs New Architecture

اعرض:

```text
CURRENT
```

ثم:

```text
NEW
```

مع بيان ما تم الاحتفاظ به وما تم تغييره ولماذا.

## C. Implementation Report

اذكر:

```text
files changed
classes added
classes refactored
database changes
migration changes
security impact
```

## D. Test Report

اذكر:

```text
passed
failed
not reproducible
blocked
```

## E. Benchmark Report

اعرض:

```text
before
after
difference
```

ولا تضع أرقامًا تقديرية.

---

# 38. القاعدة الذهبية

المشكلة الأساسية ليست:

```text
"DownloadManager بطيء"
```

المشكلة الأعمق هي:

```text
network work
+
encryption work
+
filesystem work
+
runtime state
```

ليست مرتبطة حتى الآن بـ**durable chunk state machine**.

لذلك المطلوب النهائي:

```text
                    DownloadSession
                           │
                           ▼
                    Chunk Manifest
                           │
                           ▼
                    Chunk Scheduler
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
           Chunk 0      Chunk 1      Chunk 2
              │            │            │
              ▼            ▼            ▼
           Network      Network      Network
              │            │            │
              ▼            ▼            ▼
          AES-GCM       AES-GCM      AES-GCM
              │            │            │
              ▼            ▼            ▼
           Verify       Verify       Verify
              │            │            │
              ▼            ▼            ▼
          Commit       Commit       Commit
              └────────────┬────────────┘
                           ▼
                    Persistent State
                           │
                           ▼
                         READY
```

وعند الفشل:

```text
failure
   │
   ├── transient
   │      ↓
   │   retry same chunk
   │
   ├── expired URL
   │      ↓
   │   refresh source
   │      ↓
   │   retry same chunk
   │
   ├── network offline
   │      ↓
   │   pause/recover
   │
   ├── app/process death
   │      ↓
   │   restore manifest
   │
   ├── corrupted chunk
   │      ↓
   │   invalidate chunk
   │
   └── revoked entitlement
          ↓
        stop
```

## المبدأ النهائي

لا نريد:

```text
Downloader with retries
```

نريد:

```text
Persistent Resumable Encrypted Download Engine
```

والتغيير الأساسي ليس "كتابة كود أكثر"، بل جعل:

```text
SQLite chunk manifest
```

هو **مصدر الحقيقة الدائم**، بينما:

```text
DownloadManager / background_downloader / Dio
```

هي أدوات لتنفيذ العمل.

**إذا نجحت في هذا التحول، فعندها يصبح البطء مشكلة performance قابلة للقياس، والفشل مشكلة recovery قابلة للاسترداد، بدل أن يكون كل failure سببًا لإعادة التنزيل من البداية.**