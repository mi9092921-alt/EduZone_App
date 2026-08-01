import 'package:app/core/error/exceptions.dart';
import 'package:app/core/error/failures.dart';
import 'package:app/features/video_player/data/datasources/video_player_remote_ds.dart';
import 'package:app/features/video_player/data/repositories/video_player_repo_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockVideoPlayerRemoteDataSource extends Mock
    implements VideoPlayerRemoteDataSource {}

void main() {
  late VideoPlayerRepositoryImpl repository;
  late MockVideoPlayerRemoteDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockVideoPlayerRemoteDataSource();
    repository = VideoPlayerRepositoryImpl(mockDataSource);
  });

  group('syncProgress', () {
    test('should return Right(null) when data source succeeds', () async {
      when(
        () => mockDataSource.syncProgress(
          courseId: 'c1',
          lessonId: 'l1',
          completed: true,
          progressPct: 100.0,
          watchTimeSec: 60,
        ),
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
        () => mockDataSource.syncProgress(
          courseId: 'c1',
          lessonId: 'l1',
          completed: true,
          progressPct: 100.0,
          watchTimeSec: 60,
        ),
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
