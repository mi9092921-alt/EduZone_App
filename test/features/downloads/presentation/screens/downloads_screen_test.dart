import 'package:app/features/downloads/domain/entities/download_enums.dart';
import 'package:app/features/downloads/domain/entities/downloaded_lesson.dart';
import 'package:app/features/downloads/presentation/screens/downloads_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveCourseGroupTitle', () {
    test('uses course title when available', () {
      final download = DownloadedLesson(
        id: '1',
        lessonId: 'lesson-1',
        courseId: 'course-123',
        courseTitle: 'Advanced Physics',
        title: 'Lesson 1',
        localPath: '/tmp/1',
        encryptedPath: '/tmp/1.enc',
        videoUrl: 'https://example.com/video.mp4',
        quality: VideoQuality.p720,
        fileSize: 100,
        status: DownloadStatus.completed,
        downloadedAt: DateTime(2024),
        expiresAt: DateTime(2025),
      );

      expect(resolveCourseGroupTitle(download), 'Advanced Physics');
    });

    test('falls back to course id when title is empty', () {
      final download = DownloadedLesson(
        id: '2',
        lessonId: 'lesson-2',
        courseId: 'course-456',
        title: 'Lesson 2',
        localPath: '/tmp/2',
        encryptedPath: '/tmp/2.enc',
        videoUrl: 'https://example.com/video2.mp4',
        quality: VideoQuality.p720,
        fileSize: 200,
        status: DownloadStatus.completed,
        downloadedAt: DateTime(2024),
        expiresAt: DateTime(2025),
      );

      expect(resolveCourseGroupTitle(download), 'course-456');
    });
  });
}
