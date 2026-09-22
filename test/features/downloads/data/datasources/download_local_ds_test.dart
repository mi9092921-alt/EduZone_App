import 'package:app/core/services/storage_service.dart';
import 'package:app/features/downloads/data/datasources/download_local_ds.dart';
import 'package:app/shared/models/download_enums.dart';
import 'package:app/shared/models/downloaded_lesson.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Phase 10 — fail-closed account scoping.
///
/// `StorageService` treats a NULL `ownerUserId` as "no filter" (unscoped), so
/// a null Supabase session used to turn every scoped getter into a
/// cross-account read. These tests pin the `''` sentinel (`''` matches no
/// user_id) on the account-facing paths, and the deliberate null on the
/// WorkManager maintenance path.
class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockStorageService storage;
  late DownloadLocalDataSource localDs;

  setUp(() {
    storage = MockStorageService();
    // Session unreadable — the exact condition the old code let flow
    // through as null (background isolate / not-yet-initialized client).
    localDs = DownloadLocalDataSource(
      storage,
      currentUserId: () => null,
      deviceFingerprint: () => 'device-fp',
    );
  });

  test('getDownloads scopes to a fail-closed empty owner when the session '
      'is unreadable (never the unscoped query)', () async {
    when(
      () => storage.getDownloadedLessons(ownerUserId: any(named: 'ownerUserId')),
    ).thenAnswer((_) async => []);

    await localDs.getDownloads();

    verify(() => storage.getDownloadedLessons(ownerUserId: '')).called(1);
  });

  test('getDownloadsById/ByLessonId scoped paths fail closed too', () async {
    when(
      () => storage.getDownloadById(
        any(),
        ownerUserId: any(named: 'ownerUserId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => storage.getDownloadByLessonId(
        any(),
        ownerUserId: any(named: 'ownerUserId'),
      ),
    ).thenAnswer((_) async => null);

    await localDs.getDownloadById('dl-1');
    await localDs.getDownloadByLessonId('lesson-1');

    verify(() => storage.getDownloadById('dl-1', ownerUserId: '')).called(1);
    verify(
      () => storage.getDownloadByLessonId('lesson-1', ownerUserId: ''),
    ).called(1);
  });

  test('the explicit unscoped tooling path still passes null', () async {
    when(
      () => storage.getDownloadById(
        any(),
        ownerUserId: any(named: 'ownerUserId'),
      ),
    ).thenAnswer((_) async => null);

    await localDs.getDownloadById('dl-1', scopeToCurrentUser: false);

    final captured = verify(
      () => storage.getDownloadById('dl-1', ownerUserId: captureAny(named: 'ownerUserId')),
    ).captured.single;
    expect(
      captured,
      isNull,
      reason: 'the explicit tooling path must stay unscoped (null = no filter)',
    );
  });

  test('getExpiredDownloads defaults to the scoped (fail-closed) path and '
      'the background sweep can request the unscoped one explicitly',
      () async {
    when(
      () => storage.getExpiredDownloads(
        ownerUserId: any(named: 'ownerUserId'),
      ),
    ).thenAnswer((_) async => []);

    await localDs.getExpiredDownloads();
    verify(() => storage.getExpiredDownloads(ownerUserId: '')).called(1);

    // Explicit unscoped request (the WorkManager sweep).
    await localDs.getExpiredDownloads(scopeToCurrentUser: false);
    final captured = verify(
      () => storage.getExpiredDownloads(
        ownerUserId: captureAny(named: 'ownerUserId'),
      ),
    ).captured.last;
    expect(captured, isNull);
  });

  test('insertDownload refuses to mint an unowned (user_id NULL) row when '
      'no account is readable', () async {
    final download = DownloadedLesson(
      id: 'dl-1',
      lessonId: 'lesson-1',
      courseId: 'course-1',
      title: 'Lesson 1',
      localPath: '/tmp/l.enc',
      encryptedPath: '/tmp/l.enc',
      videoUrl: 'https://example.com/v.mp4',
      quality: VideoQuality.p720,
      fileSize: 10,
      status: DownloadStatus.completed,
      progress: 1,
      downloadedAt: DateTime(2026),
      expiresAt: DateTime(2027),
    );

    await expectLater(
      () => localDs.insertDownload(download),
      throwsA(isA<StateError>()),
    );
    verifyNever(() => storage.insertDownload(any()));
  });
}