import 'package:app/features/profile/domain/entities/student_profile.dart';
import 'package:app/features/profile/domain/repositories/profile_repository.dart';
import 'package:app/features/profile/domain/usecases/update_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late UpdateProfile usecase;
  late MockProfileRepository mockRepository;

  setUp(() {
    mockRepository = MockProfileRepository();
    usecase = UpdateProfile(mockRepository);
  });

  const tProfile = StudentProfile(
    id: 'user1',
    tenantId: 'tenant1',
    email: 'test@example.com',
    firstName: 'John',
  );

  test('should update profile via the repository', () async {
    when(
      () => mockRepository.updateProfile(firstName: 'John'),
    ).thenAnswer((_) async => tProfile);

    final result = await usecase(firstName: 'John');

    expect(result, equals(tProfile));
    verify(() => mockRepository.updateProfile(firstName: 'John')).called(1);
    verifyNoMoreInteractions(mockRepository);
  });

  test('should upload avatar via the repository', () async {
    when(
      () => mockRepository.uploadAvatar('path/to/img'),
    ).thenAnswer((_) async => 'http://img.com');

    final result = await usecase.uploadAvatar('path/to/img');

    expect(result, equals('http://img.com'));
    verify(() => mockRepository.uploadAvatar('path/to/img')).called(1);
    verifyNoMoreInteractions(mockRepository);
  });
}
