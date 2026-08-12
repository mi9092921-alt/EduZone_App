إذا كنت تريد تنفيذ تنزيل الدروس بشكل احترافي بمستوى التطبيقات الكبيرة (Coursera، Udemy، Netflix)، فالموضوع ليس مجرد زر "تنزيل". هناك دورة حياة كاملة للملف (Download Lifecycle).

التدفق العالمي عادة يكون هكذا:

## 1. الضغط على زر التنزيل

في `LessonTile`:

```dart
LessonTile(
   ...
   onDownload: () {
      _showDownloadOptions(lesson);
   }
)
```

بدل أن يبدأ التنزيل مباشرة، افتح نافذة خيارات:

* جودة منخفضة (360p)
* جودة متوسطة (720p)
* جودة عالية (1080p)
* حجم الملف المتوقع
* مساحة التخزين المطلوبة

مثال:

```text
Download lesson

360p — 120 MB
720p — 350 MB
1080p — 820 MB
```

لماذا؟

لأن التطبيقات الاحترافية لا تبدأ تنزيل 1GB فجأة دون سؤال المستخدم.

---

## 2. إنشاء كيان Download Model

في Domain:

```dart
class DownloadedLesson {
  final String lessonId;
  final String courseId;

  final String title;

  final String videoUrl;

  final String localPath;

  final double progress;

  final DownloadStatus status;

  final int fileSize;

  final DateTime downloadedAt;

  const DownloadedLesson({
      required this.lessonId,
      required this.courseId,
      required this.title,
      required this.videoUrl,
      required this.localPath,
      required this.progress,
      required this.status,
      required this.fileSize,
      required this.downloadedAt,
  });
}
```

الحالة:

```dart
enum DownloadStatus {
   pending,
   downloading,
   paused,
   completed,
   failed
}
```

---

## 3. إنشاء Download Service

يفضل طبقة منفصلة:

```text
lib/
 ├── features
 │    ├── downloads
 │    │      ├── data
 │    │      │      download_service.dart
 │    │      │      local_download_storage.dart
 │    │      │
 │    │      ├── domain
 │    │      │      downloaded_lesson.dart
 │    │      │
 │    │      ├── presentation
 │    │             downloads_page.dart
```

داخل الخدمة:

```dart
abstract class DownloadService {

   Future<void> startDownload({
      required Lesson lesson,
      required VideoQuality quality,
   });

   Future<void> pauseDownload(
      String lessonId,
   );

   Future<void> resumeDownload(
      String lessonId,
   );

   Future<void> deleteDownload(
      String lessonId,
   );

   Stream<DownloadProgress> watchProgress(
      String lessonId,
   );
}
```

---

## 4. تنزيل الملف فعليًا

في Flutter غالبًا تستخدم:

* Flutter
* Dio

لأن `Dio` يدعم:

* Progress tracking
* Resume
* Cancel token
* Retry
* Headers

مثال:

```dart
await dio.download(
   url,
   savePath,

   onReceiveProgress: (
      received,
      total,
   ){

      final progress =
          received / total;

   }
);
```

---

## 5. تخزين بيانات الدروس محليًا

لا تعتمد على `SharedPreferences`.

هذا غير مناسب للتنزيلات.

استعمل قاعدة بيانات محلية مثل:

* SQLite
* أو Hive

مثال جدول:

```text
downloaded_lessons

lesson_id
course_id
title
local_path
status
progress
file_size
downloaded_at
```

---

## 6. أثناء التنزيل

داخل `LessonTile`:

قبل:

```text
[ Download ]
```

أثناء التنزيل:

```text
[ 56% ███████░░░ ]
```

بعد اكتماله:

```text
✓ Downloaded
```

عند الفشل:

```text
Retry
```

---

## 7. صفحة "الدروس المنزلة"

داخل Bottom Navigation:

```text
Home
My Courses
Downloads
Profile
```

صفحة:

```text
Downloads

Flutter Basics
✓ Downloaded
350 MB

Advanced State Management
↓ Downloading
62%

API Course
❌ Failed
```

البيانات تأتي من:

```dart
final downloadsProvider =
    StreamProvider(
       ...
    );
```

---

## 8. عند فتح درس منزّل

عندما يضغط المستخدم:

```dart
if(download.localPath.isNotEmpty){

   playLocalVideo(
      download.localPath
   );

}else{

   playOnlineVideo();
}
```

التطبيقات الكبيرة دائمًا تعطي أولوية للنسخة المحلية.

---

## 9. أشياء احترافية غالبًا تُنسى

### منع التنزيل إذا المساحة غير كافية

```dart
if(freeSpace < fileSize){
   showNotEnoughStorage();
}
```

---

### دعم الإيقاف والاستكمال

```text
Pause
Resume
```

---

### التنزيل بالخلفية

حتى لو أغلق المستخدم التطبيق:

* Android → WorkManager
* iOS → Background Tasks

---

### منع النسخ غير المصرح به

إذا الفيديو مدفوع:

* لا تخزن الملف بصيغته الخام
* شفر الملف
* أو استخدم signed URLs
* أو DRM

---

### حذف تلقائي

مثال:

```text
Delete after 30 days
```

---

### السماح بالتنزيل على Wi-Fi فقط

الإعدادات:

```text
✓ Download on Wi-Fi only
```

---

إذا أردت تنفيذه فعليًا، فالخطوة التالية هي تصميم **الـ Riverpod providers + Repository + DownloadManager + قاعدة البيانات + شاشة Downloads كاملة بالكود الحقيقي داخل مشروعك الحالي**.
