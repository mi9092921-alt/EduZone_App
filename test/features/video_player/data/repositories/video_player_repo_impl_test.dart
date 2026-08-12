import 'package:app/core/error/exceptions.dart';
import 'package:app/core/error/failures.dart';
import 'package:app/features/video_player/data/datasources/video_player_remote_ds.dart';
import 'package:app/features/video_player/data/repositories/video_player_repo_impl.dart';
import 'package:app/features/video_player/domain/entities/lesson_progress_sync_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockVideoPlayerRemoteDataSource extends Mock
    implements VideoPlayerRemoteDataSource {}

void main() {
  late VideoPlayerRepositoryImpl repository;
  late MockVideoPlayerRemoteDataSource mockDataSource;

  setUpAll(() {
    registerFallbackValue(<LessonProgressSyncItem>[]);
  });

  setUp(() {
    mockDataSource = MockVideoPlayerRemoteDataSource();
    repository = VideoPlayerRepositoryImpl(mockDataSource);
  });

  group('syncProgress', () {
    test('should return Right(null) when data source succeeds', () async {
      when(
        () => mockDataSource.syncProgressBatch(any()),
      ).thenAnswer((_) async => Future.value());

      final result = await repository.syncProgress(
        courseId: 'c1',
        lessonId: 'l1',
        completed: true,
        progressPct: 100.0,
        watchTimeSec: 60,
      );

      expect(result, isA<Right<Failure, void>>());
    });

    test('should return Left(ServerFailure) on exception', () async {
      when(
        () => mockDataSource.syncProgressBatch(any()),
      ).thenThrow(const ServerException('Failed'));

      final result = await repository.syncProgress(
        courseId: 'c1',
        lessonId: 'l1',
        completed: true,
        progressPct: 100.0,
        watchTimeSec: 60,
      );

      expect(result, isA<Left<Failure, void>>());
    });

    test('syncProgressBatch should pass items to data source', () async {
      const items = [
        LessonProgressSyncItem(
          courseId: 'c1',
          lessonId: 'l1',
          completed: false,
          progressPct: 40.0,
          watchTimeSec: 30,
        ),
      ];
      when(
        () => mockDataSource.syncProgressBatch(items),
      ).thenAnswer((_) async => Future.value());

      final result = await repository.syncProgressBatch(items);

      expect(result, isA<Right<Failure, void>>());
      verify(() => mockDataSource.syncProgressBatch(items)).called(1);
    });
  });

  group('logActivity', () {
    test(
      'should pass through to data source without mapping exceptions',
      () async {
        when(
          () => mockDataSource.logActivity(
            eventType: 'event',
            metadata: {'foo': 'bar'},
          ),
        ).thenAnswer((_) async => Future.value());

        await repository.logActivity(
          eventType: 'event',
          metadata: {'foo': 'bar'},
        );

        verify(
          () => mockDataSource.logActivity(
            eventType: 'event',
            metadata: {'foo': 'bar'},
          ),
        ).called(1);
      },
    );
  });
}
