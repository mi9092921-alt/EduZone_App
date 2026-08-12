import 'package:app/features/profile/domain/entities/student_profile.dart';
import 'package:app/features/profile/domain/repositories/profile_repository.dart';
import 'package:app/features/profile/domain/usecases/get_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  late GetProfile usecase;
  late MockProfileRepository mockRepository;

  setUp(() {
    mockRepository = MockProfileRepository();
    usecase = GetProfile(mockRepository);
  });

  const tProfile = StudentProfile(
    id: 'user1',
    tenantId: 'tenant1',
    email: 'test@example.com',
  );

  test('should get profile from the repository', () async {
    when(() => mockRepository.getProfile()).thenAnswer((_) async => tProfile);

    final result = await usecase();

    expect(result, equals(tProfile));
    verify(() => mockRepository.getProfile()).called(1);
    verifyNoMoreInteractions(mockRepository);
  });
}
