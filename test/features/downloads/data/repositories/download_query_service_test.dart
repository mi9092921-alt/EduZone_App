import 'package:app/features/downloads/data/datasources/download_local_ds.dart';
import 'package:app/features/downloads/data/repositories/download_query_service.dart';
import 'package:app/features/downloads/domain/entities/download_enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDownloadLocalDataSource extends Mock
    implements DownloadLocalDataSource {}

Map<String, dynamic> row({String id = 'd1'}) => {
      'id': id,
      'lesson_id': 'lesson-1',
      'course_id': 'course-1',
      'course_title': 'Course',
      'title': 'Lesson',
      'local_path': '/local/video.mp4',
      'encrypted_path': '/local/video.mp4.enc',
      'audio_path': null,
      'video_url': 'https://example.test/video',
      'audio_url': null,
      'quality': '720p',
      // SQLite can return numeric values as doubles.
      'file_size': 1024.0,
      'download_status': 'completed',
      'progress': 1.0,
      'downloaded_at': 1000.0,
      'expires_at': 2000.0,
      'checksum': null,
      'last_accessed_at': null,
    };

void main() {
  late MockDownloadLocalDataSource local;
  late DownloadQueryService service;

  setUp(() {
    local = MockDownloadLocalDataSource();
    service = DownloadQueryService(local);
  });

  test('maps SQLite numeric values to a downloaded lesson', () async {
    when(() => local.getDownloadById('d1')).thenAnswer((_) async => row());

    final result = await service.getDownloadById('d1');

    expect(result.isRight(), isTrue);
    result.fold(
      (_) => fail('expected a lesson'),
      (lesson) {
        expect(lesson, isNotNull);
        expect(lesson!.fileSize, 1024);
        expect(lesson.downloadedAt.millisecondsSinceEpoch, 1000);
        expect(lesson.status, DownloadStatus.completed);
      },
    );
  });

  test('returns null when the local data source has no matching row', () async {
    when(() => local.getDownloadByLessonId('missing'))
        .thenAnswer((_) async => null);

    final result = await service.getDownloadByLessonId('missing');

    expect(result.isRight(), isTrue);
    expect(result.getOrElse((_) => throw StateError('failure')), isNull);
  });

  test('skips corrupt rows while retaining valid rows', () async {
    when(() => local.getDownloads()).thenAnswer(
      (_) async => [row(), {...row(id: 'bad')..remove('file_size')}],
    );

    final result = await service.getDownloads();

    expect(result.isRight(), isTrue);
    expect(result.getOrElse((_) => const []), hasLength(1));
  });

  test('delegates status, storage, and last-access queries', () async {
    when(() => local.getDownloadsByStatus('paused'))
        .thenAnswer((_) async => [row()]);
    when(() => local.getTotalStorageUsed()).thenAnswer((_) async => 55);
    when(() => local.updateLastAccessed('d1')).thenAnswer((_) async {});

    final statusResult = await service.getDownloadsByStatus(DownloadStatus.paused);
    final storageResult = await service.getTotalStorageUsed();
    final accessResult = await service.updateLastAccessed('d1');

    expect(statusResult.isRight(), isTrue);
    expect(storageResult.getOrElse((_) => -1), 55);
    expect(accessResult.isRight(), isTrue);
    verify(() => local.getDownloadsByStatus('paused')).called(1);
    verify(() => local.updateLastAccessed('d1')).called(1);
  });
}
