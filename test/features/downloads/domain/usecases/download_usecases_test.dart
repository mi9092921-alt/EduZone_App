import 'package:app/features/downloads/domain/entities/download_enums.dart';
import 'package:app/features/downloads/domain/entities/downloaded_lesson.dart';
import 'package:app/features/downloads/domain/repositories/download_repository.dart';
import 'package:app/features/downloads/domain/usecases/cancel_download_usecase.dart';
import 'package:app/features/downloads/domain/usecases/cleanup_expired_downloads_usecase.dart';
import 'package:app/features/downloads/domain/usecases/delete_download_usecase.dart';
import 'package:app/features/downloads/domain/usecases/pause_download_usecase.dart';
import 'package:app/features/downloads/domain/usecases/resume_download_usecase.dart';
import 'package:app/features/downloads/domain/usecases/start_download_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockDownloadRepository extends Mock implements DownloadRepository {}

void main() {
  late MockDownloadRepository repository;

  setUp(() => repository = MockDownloadRepository());

  test('start delegates every argument to the repository', () async {
    final lesson = DownloadedLesson.skeleton();
    when(
      () => repository.startDownload(
        lessonId: 'lesson',
        courseId: 'course',
        courseTitle: 'Course',
        title: 'Lesson',
        videoUrl: 'https://example.test/video',
        quality: VideoQuality.p720,
      ),
    ).thenAnswer((_) async => Right(lesson));

    final result = await StartDownloadUseCase(repository).call(
      lessonId: 'lesson',
      courseId: 'course',
      courseTitle: 'Course',
      title: 'Lesson',
      videoUrl: 'https://example.test/video',
      quality: VideoQuality.p720,
    );

    expect(result, Right(lesson));
    verify(
      () => repository.startDownload(
        lessonId: 'lesson',
        courseId: 'course',
        courseTitle: 'Course',
        title: 'Lesson',
        videoUrl: 'https://example.test/video',
        quality: VideoQuality.p720,
      ),
    ).called(1);
  });

  test('pause, resume, cancel, and delete delegate their id', () async {
    when(() => repository.pauseDownload('d1')).thenAnswer((_) async => const Right(null));
    when(() => repository.resumeDownload('d1')).thenAnswer((_) async => const Right(null));
    when(() => repository.cancelDownload('d1')).thenAnswer((_) async => const Right(null));
    when(() => repository.deleteDownload('d1')).thenAnswer((_) async => const Right(null));

    await PauseDownloadUseCase(repository).call('d1');
    await ResumeDownloadUseCase(repository).call('d1');
    await CancelDownloadUseCase(repository).call('d1');
    await DeleteDownloadUseCase(repository).call('d1');

    verify(() => repository.pauseDownload('d1')).called(1);
    verify(() => repository.resumeDownload('d1')).called(1);
    verify(() => repository.cancelDownload('d1')).called(1);
    verify(() => repository.deleteDownload('d1')).called(1);
  });

  test('cleanup delegates without arguments', () async {
    when(() => repository.cleanupExpiredDownloads()).thenAnswer((_) async => const Right(3));

    final result = await CleanupExpiredDownloadsUseCase(repository).call();

    expect(result, const Right(3));
    verify(() => repository.cleanupExpiredDownloads()).called(1);
  });
}
