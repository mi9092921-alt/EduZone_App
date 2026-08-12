# Downloads Feature

Video streaming and offline download system for the learning platform.  
Built on **Flutter → Supabase Edge Functions → Replit (yt-dlp API) → YouTube**.

---

## Table of Contents

- [Architecture](#architecture)
- [File Structure](#file-structure)
- [Design Decisions](#design-decisions)
- [Schema](#schema)
- [Edge Functions API](#edge-functions-api)
- [Offline Access Model](#offline-access-model)
- [Replit Resilience](#replit-resilience)
- [Flutter Integration](#flutter-integration)
- [Deployment](#deployment)
- [Maintenance](#maintenance)

---

## Architecture

```
Flutter App
    │
    ├─[1]─ validate-course-access   (Supabase Edge Function)
    │           │
    │           └── enrollments table  (Supabase DB)
    │
    ├─[2]─ video-info               (Supabase Edge Function)
    │           │
    │           ├── video_cache table  (cache hit → return immediately)
    │           │
    │           └── Replit API         (cache miss → fetch from yt-dlp)
    │                   │
    │                   └── YouTube
    │
    └─[3]─ log-download-attempt     (Supabase Edge Function)
                │
                └── download_logs table
```

### Why the API key never touches Flutter

```
❌  Flutter → YouTube / Replit directly   (API key exposed in APK)
✅  Flutter → Supabase Edge Function      (key stored as Supabase Secret)
```

---

## File Structure

```
downloads/
│
├── schema/
│   ├── 01_tables.sql          Tables: video_cache, download_logs
│   └── 02_functions.sql       Empty — all logic lives in Edge Functions
│
├── functions/
│   ├── validate-course-access/
│   │   └── index.ts           Access check — course OR lesson level
│   ├── video-info/
│   │   └── index.ts           Fetch formats + audio from Replit / cache
│   └── log-download-attempt/
│       └── index.ts           Analytics insert after successful download
│
├── AGENT_PROMPT.md            Flutter agent system prompt
└── README.md
```

### Removed files (and why)

| Removed | Reason |
|---|---|
| `get-available-qualities.ts` | Qualities already returned inside `video-info` → `formats[]` |
| `validate-offline-access.ts` | Merged into `validate-course-access` via `lesson_id` param |
| `get-subscription-expiry.ts` | `expires_at` now returned by `validate-course-access` |
| `get-download-url.ts` | No Supabase Storage; video URLs come from Replit via `video-info` |
| `rate_limit_logs` table | Removed — unnecessary DB writes on free plan |
| All SQL RPC functions | Removed — logic moved entirely to Edge Functions |

**Result: 7 functions → 3 functions. No functionality lost.**

---

## Design Decisions

### 1. Audio extracted from formats — no repetition

**Before:** every format repeated `audio_url` + `audio_size` (6× redundancy).  
**After:** shared audio at top level; each format has `has_audio` + `requires_merge`.

```jsonc
{
  "audio": { "itag": 140, "url": "...", "size_bytes": 12888092, "ext": "m4a" },
  "formats": [
    { "quality": "144p", "has_audio": false, "requires_merge": true,  "video_url": "..." },
    { "quality": "360p", "has_audio": true,  "requires_merge": false, "video_url": "..." },
    { "quality": "720p", "has_audio": false, "requires_merge": true,  "video_url": "..." }
  ]
}
```

`requires_merge: false` → download `video_url` only (muxed stream).  
`requires_merge: true` → download `video_url` + `audio.url`, then merge with FFmpeg.

### 2. video-info returns JSON directly — no wrapper

**Before:**
```json
{ "success": true, "source": "fresh", "video": { ... } }
```

**After — Flutter receives the data directly:**
```json
{ "title": "...", "formats": [...], "source": "fresh", ... }
```

`source`, `cache_expires_at`, `platform`, `time_ms` are top-level fields.

### 3. size_bytes replaces size string

**Before:** `"size": "12.3 MB"` (string, not sortable).  
**After:** `"size_bytes": 12888092` (integer). Flutter formats it locally:

```dart
String formatSize(int? bytes) {
  if (bytes == null) return '';
  return '${(bytes / 1048576).toStringAsFixed(1)} MB';
}
```

### 4. No extra encryption on top of HTTPS

YouTube URLs expire (contain `expire=` timestamp — typically 6 hours).  
HTTPS already encrypts data in transit. No additional encryption needed.

### 5. Offline access — local validation, no server call (Udemy-style)

| | Netflix-style | Udemy-style ✅ |
|---|---|---|
| Validate on every play | Server call required | Local check only |
| Works offline | ❌ | ✅ |
| Instant revocation | ✅ | ❌ (waits for expiry) |
| Weak network friendly | ❌ | ✅ |

`access_expires_at` is saved to `download_logs` at download time, copied from  
`enrollments.expires_at`. Flutter stores it locally; `null` = lifetime access.

### 6. validate-course-access accepts course_id OR lesson_id

One function handles three cases:

```
{ lesson_id } + is_preview: true  →  allowed: true, no enrollment check
{ lesson_id } + is_preview: false →  resolve course → enrollment check
{ course_id }                     →  enrollment check directly
```

### 7. Rate limiting removed

Dropped `rate_limit_logs` table and all related logic from `video-info`.  
Reason: unnecessary DB writes on Supabase free plan. The 24h cache naturally  
reduces Replit calls; free plan limits are not at risk for normal usage.

### 8. No SQL RPC functions

`02_functions.sql` contains only a comment. All logic lives in Edge Functions  
where it is easier to iterate, test, and deploy without database migrations.

### 9. log-download-attempt stays separate from video-info

A download can take several minutes. Logging happens **after** completion.  
Merging it into `video-info` would log attempts that never finished.

---

## Schema

### video_cache

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `url` | text | Original YouTube URL |
| `url_hash` | text | SHA-256 of URL — unique, indexed |
| `data` | jsonb | Full normalized response (output.json shape) |
| `created_at` | timestamptz | |
| `expires_at` | timestamptz | Default TTL: 24 hours |

### download_logs

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `user_id` | uuid | FK → auth.users |
| `lesson_id` | uuid | |
| `course_id` | uuid | |
| `quality` | text | e.g. `360p`, `720p` |
| `downloaded_at` | timestamptz | |
| `access_expires_at` | timestamptz | `null` = lifetime. Flutter validates locally. |

Removed from original: `tenant_id`, `file_size`, `status` — not needed for the free plan scope.

---

## Edge Functions API

All functions require `Authorization: Bearer <access_token>` (Supabase Flutter SDK sends this automatically).

---

### `validate-course-access`

Checks enrollment and returns the access expiry date.  
Merged from three old functions: `validate-course-access`, `validate-offline-access`, `get-subscription-expiry`.

**Input** (provide at least one):
```json
{ "lesson_id": "uuid" }
{ "course_id": "uuid" }
```

**Output:**
```jsonc
{ "allowed": true,  "expires_at": "2026-12-01T00:00:00Z" }
{ "allowed": true,  "expires_at": null }    // null = lifetime access
{ "allowed": false, "expires_at": null }
```

**Logic:**
```
lesson_id provided?
  └── not found or not published  →  { allowed: false }
  └── is_preview: true            →  { allowed: true, expires_at: null }
  └── resolve course_id           →  enrollment check ↓

enrollment check:
  status = active AND (expires_at IS NULL OR expires_at > now())
  not found  →  { allowed: false }
  found      →  { allowed: true, expires_at: enrollment.expires_at }
```

**Bug fixed vs original:**
```typescript
// ❌ Before — incorrect Supabase v2 chaining
.gte('expires_at', now).or('expires_at.is.null')

// ✅ After — single combined OR condition
.or(`expires_at.is.null,expires_at.gte.${now}`)
```

---

### `video-info`

Fetches video metadata and all format URLs from Replit / cache.  
Returns data directly — no `success`/`video` wrapper.

**Input:**
```json
{ "url": "https://youtu.be/VIDEO_ID" }
```

**Output:**
```jsonc
{
  "title": "Lesson Title",
  "thumbnail": "https://i.ytimg.com/vi/.../maxresdefault.jpg",
  "duration": 796,
  "channel": "Channel Name",
  "view_count": 44402,

  "audio": {
    "itag": 140,
    "url": "https://rr1---sn-...googlevideo.com/...",
    "size_bytes": 12888092,
    "ext": "m4a"
  },

  "formats": [
    {
      "itag": 394,
      "quality": "144p",
      "height": 144,
      "fps": 30,
      "ext": "mp4",
      "size_bytes": 5117609,
      "has_audio": false,
      "requires_merge": true,
      "video_url": "https://rr1---sn-...googlevideo.com/..."
    },
    {
      "itag": 18,
      "quality": "360p",
      "height": 360,
      "fps": 30,
      "ext": "mp4",
      "size_bytes": 37685341,
      "has_audio": true,
      "requires_merge": false,
      "video_url": "https://rr1---sn-...googlevideo.com/..."
    }
  ],

  "default_download_quality": "360p",
  "cache_expires_at": "2026-07-01T12:00:00Z",
  "source": "fresh",
  "platform": "YouTube",
  "time_ms": 1358
}
```

**`source` field:**

| Value | Meaning | Flutter action |
|---|---|---|
| `"fresh"` | Live from Replit/YouTube | Nothing |
| `"cache"` | Served from 24h cache | Nothing |
| `"stale"` | Replit down; expired cache served | Show subtle banner |

**`requires_merge` field:**

| Value | Meaning | Flutter must |
|---|---|---|
| `false` | Muxed stream (video + audio) | Download `video_url` only |
| `true` | Video-only stream | Download `video_url` + `audio.url`, merge |

**Error responses:**
```jsonc
{ "error": "Video server timed out, please try again" }   // 503 — Replit timeout
{ "error": "Video server unavailable" }                   // 503 — Replit down, no cache
{ "error": "Video URL is required" }                      // 400
```

**Note:** YouTube URLs expire (contain `expire=` timestamp). Never persist them to local storage.

---

### `log-download-attempt`

Called by Flutter **after** a download completes successfully.

**Input:**
```jsonc
{
  "lesson_id": "uuid",
  "quality": "720p",
  "access_expires_at": "2026-12-01T00:00:00Z"   // or null for lifetime
}
```

**Output:**
```json
{ "success": true }
```

`access_expires_at` must be the value returned by `validate-course-access`.

---

## Offline Access Model

### At download time

```dart
// 1. Validate access
final access = await supabase.functions.invoke(
  'validate-course-access',
  body: {'lesson_id': lessonId},
);
final expiresAt = access.data['expires_at'] as String?;

// 2. Get formats
final info = await supabase.functions.invoke(
  'video-info',
  body: {'url': lesson.youtubeUrl},
);
final format = pickQuality(info.data['formats'], info.data['default_download_quality']);

// 3. Download
if (format['requires_merge']) {
  await downloadFile(format['video_url'], videoTempPath);
  await downloadFile(info.data['audio']['url'], audioTempPath);
  await mergeVideoAudio(videoTempPath, audioTempPath, finalPath);
} else {
  await downloadFile(format['video_url'], finalPath);
}

// 4. Save locally
await localDb.saveDownload(
  lessonId: lessonId,
  localPath: finalPath,
  quality: format['quality'],
  accessExpiresAt: expiresAt,
);

// 5. Log — after completion only
await supabase.functions.invoke('log-download-attempt', body: {
  'lesson_id': lessonId,
  'quality': format['quality'],
  'access_expires_at': expiresAt,
});
```

### At offline playback time (no server call)

```dart
bool canPlayOffline(String? accessExpiresAt) {
  if (accessExpiresAt == null) return true;                           // lifetime
  return DateTime.now().isBefore(DateTime.parse(accessExpiresAt));
}

if (!canPlayOffline(download.accessExpiresAt)) {
  showDialog('Your access has expired. Please renew your subscription.');
  return;
}

playLocalVideo(download.localPath);
```

---

## Replit Resilience

Replit free tier sleeps after inactivity. `video-info` handles this in three layers:

```
video-info called
      │
      ├─ Fresh cache hit?  ──yes──→  return immediately  ~150ms
      │
      ├─ Keep stale cache reference as fallback
      │
      ├─ Try Replit (8s timeout)
      │       │
      │       ├─ success  →  normalize → write cache → return source:"fresh"
      │       │
      │       └─ fail / timeout
      │               │
      │               ├─ stale cache?  →  return source:"stale"   ~200ms
      │               │
      │               └─ no cache  →  HTTP 503 to Flutter
      │
      └─ Flutter shows banner only when source == "stale"
```

### Environment variables

```bash
supabase secrets set VIDEO_API_KEY=your_key
supabase secrets set VIDEO_API_URL=https://your-replit.replit.dev  # optional override
supabase secrets set VIDEO_REPLIT_TIMEOUT_MS=8000                  # default: 8s
```

---

## Flutter Integration — Full Flow

```
User opens lesson
      │
      ├── online
      │     ├── validate-course-access { lesson_id }
      │     │     allowed: false → paywall, STOP
      │     │
      │     ├── video-info { url }
      │     │     source == 'stale' → show banner
      │     │
      │     └── play video_url in player
      │           requires_merge: false → video_url only
      │           requires_merge: true  → video_url + audio.url as separate tracks
      │
      └── wants offline download
            ├── validate-course-access  → { allowed, expires_at }
            ├── video-info              → pick quality
            ├── download files          → merge if requires_merge
            ├── save to local DB        → { localPath, accessExpiresAt }
            └── log-download-attempt    → fire and forget

User opens downloaded lesson (offline)
      └── canPlayOffline(accessExpiresAt)?
            yes → play local file
            no  → "Subscription expired" dialog
```

### FFmpeg merge

```dart
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';

Future<void> mergeVideoAudio({
  required String videoPath,
  required String audioPath,
  required String outputPath,
}) async {
  final session = await FFmpegKit.execute(
    '-i "$videoPath" -i "$audioPath" -c:v copy -c:a aac "$outputPath"'
  );
  final rc = await session.getReturnCode();
  if (!ReturnCode.isSuccess(rc)) throw Exception('FFmpeg merge failed');
  // Clean up temp files
  await File(videoPath).delete();
  await File(audioPath).delete();
}
```

---

## Deployment

```bash
# 1. Apply schema (tables only — no RPC functions)
supabase db push

# 2. Secrets
supabase secrets set VIDEO_API_KEY=your_key
supabase secrets set SUPABASE_SERVICE_ROLE=your_service_role_key

# 3. Deploy the 3 functions
supabase functions deploy validate-course-access
supabase functions deploy video-info
supabase functions deploy log-download-attempt
```

---

## Maintenance

### Cleanup (run via Supabase scheduled function or pg_cron)

```sql
-- Daily: remove expired cache
DELETE FROM public.video_cache WHERE expires_at < now();
```

### Monitoring

| Signal | Meaning |
|---|---|
| `source: "stale"` responses increasing | Replit sleeping more than usual |
| `video-info` returning HTTP 503 | Replit down and no cache — wake it manually |
| `access_expires_at` null in download_logs | Lifetime-access users (expected) |

### Free tier limits (Supabase)

| Resource | Limit | Expected usage |
|---|---|---|
| Edge Function invocations | 500,000 / month | Low — cache absorbs ~90% |
| Edge Function exec time | 150,000 GB-hours | Low |
| DB size | 500 MB | Monitor `video_cache` growth |
ENDOFFILE
Output

exit code 0
Done

You are out of free messages until 2:50 AM
