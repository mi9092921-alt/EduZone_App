import 'package:app/core/error/exceptions.dart';
import 'package:app/features/profile/data/datasources/profile_remote_ds.dart';
import 'package:app/features/profile/data/repositories/profile_repo_impl.dart';
import 'package:app/features/profile/domain/entities/student_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileRemoteDataSource extends Mock
    implements ProfileRemoteDataSource {}

void main() {
  late ProfileRepositoryImpl repository;
  late MockProfileRemoteDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockProfileRemoteDataSource();
    repository = ProfileRepositoryImpl(remoteDataSource: mockDataSource);
  });

  group('getProfile', () {
    const tProfile = StudentProfile(
      id: 'user1',
      tenantId: 'tenant1',
      email: 'test@example.com',
    );

    test('should return profile when call is successful', () async {
      when(() => mockDataSource.getProfile()).thenAnswer((_) async => tProfile);

      final result = await repository.getProfile();

      expect(result, equals(tProfile));
      verify(() => mockDataSource.getProfile()).called(1);
    });

    test('should throw ServerException when call fails', () async {
      when(() => mockDataSource.getProfile()).thenThrow(Exception('Failed'));

      expect(() => repository.getProfile(), throwsA(isA<ServerException>()));
    });
  });

  group('updateProfile', () {
    const tProfile = StudentProfile(
      id: 'user1',
      tenantId: 'tenant1',
      email: 'test@example.com',
      firstName: 'John',
    );

    test('should return updated profile when call is successful', () async {
      when(
        () => mockDataSource.updateProfile(firstName: 'John'),
      ).thenAnswer((_) async => tProfile);

      final result = await repository.updateProfile(firstName: 'John');

      expect(result, equals(tProfile));
    });

    test('should throw ServerException when call fails', () async {
      when(
        () => mockDataSource.updateProfile(firstName: 'John'),
      ).thenThrow(Exception('Failed'));

      expect(
        () => repository.updateProfile(firstName: 'John'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('uploadAvatar', () {
    test('should return String url when call is successful', () async {
      when(
        () => mockDataSource.uploadAvatar('path'),
      ).thenAnswer((_) async => 'http://url.com/a.jpg');

      final result = await repository.uploadAvatar('path');

      expect(result, 'http://url.com/a.jpg');
    });

    test('should throw ServerException when call fails', () async {
      when(
        () => mockDataSource.uploadAvatar('path'),
      ).thenThrow(Exception('Failed'));

      expect(
        () => repository.uploadAvatar('path'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
