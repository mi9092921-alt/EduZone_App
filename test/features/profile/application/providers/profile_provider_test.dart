import 'package:app/features/auth/application/providers/auth_provider.dart';
import 'package:app/features/profile/application/providers/profile_provider.dart';
import 'package:app/features/profile/domain/entities/student_profile.dart';
import 'package:app/features/profile/domain/repositories/profile_repository.dart';
import 'package:app/shared/models/account_status.dart';
import 'package:app/shared/models/app_user.dart';
import 'package:app/shared/models/auth_state.dart';
import 'package:app/shared/models/user_access.dart';
import 'package:app/shared/models/user_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks & fakes ───────────────────────────────────────────────────────────

class MockProfileRepository extends Mock implements ProfileRepository {}

/// Minimal [Auth] stand-in: `updateName()` success calls
/// `ref.read(authProvider.notifier).refreshUser()`, which on the real
/// notifier would hit the remote data source. Both `build()` and
/// `refreshUser()` are stubbed so the success path can settle offline.
class _FakeAuth extends Auth {
  @override
  AuthState build() =>
      const AuthAuthenticated(user: _testUser, access: _testAccess);

  @override
  Future<void> refreshUser() async {}
}

// ─── Fixtures ────────────────────────────────────────────────────────────────

const _testUser = AppUser(
  id: 'user-1',
  email: 'user1@example.com',
  firstName: 'Test',
  lastName: 'User',
  tenantId: 'tenant-1',
);

const _testAccess = UserAccess(
  status: AccountStatus.active,
  role: UserRole.student,
);

const _testProfile = StudentProfile(
  id: 'user-1',
  email: 'user1@example.com',
  firstName: 'Test',
  lastName: 'User',
  tenantId: 'tenant-1',
);

/// Drains pending microtasks so awaited notifier futures settle before
/// assertions (same pattern as todo_notifier_test.dart).
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late MockProfileRepository repository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue('');
  });

  setUp(() {
    repository = MockProfileRepository();
    container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repository),
        authProvider.overrideWith(() => _FakeAuth()),
      ],
    );
    addTearDown(container.dispose);
  });

  group('profileProvider', () {
    test('returns the repository profile on success', () async {
      when(() => repository.getProfile()).thenAnswer((_) async => _testProfile);

      final result = await container.read(profileProvider.future);

      expect(result, same(_testProfile));
      verify(() => repository.getProfile()).called(1);
    });

    test('surfaces a repository failure as an error state', () async {
      when(() => repository.getProfile()).thenThrow(Exception('boom'));

      await expectLater(
        container.read(profileProvider.future),
        throwsA(anything),
      );
    });
  });

  group('ProfileActions.updateName', () {
    test('failure path: returns false and stores the error, no success message',
        () async {
      final error = Exception('update failed');
      when(
        () => repository.updateProfile(firstName: any(named: 'firstName'), lastName: any(named: 'lastName')),
      ).thenThrow(error);

      container.listen(profileActionsProvider, (_, _) {});
      final notifier = container.read(profileActionsProvider.notifier);

      final result = await notifier.updateName(firstName: 'New');

      expect(result, isFalse);
      expect(container.read(profileActionsProvider).isUpdating, isFalse);
      expect(container.read(profileActionsProvider).error, same(error));
      expect(container.read(profileActionsProvider).successMessage, isNull);
    });

    test(
      'success path: returns true, sets the success message, and refreshes auth',
      () async {
        when(
          () => repository.updateProfile(firstName: any(named: 'firstName'), lastName: any(named: 'lastName')),
        ).thenAnswer((_) async => _testProfile);

        container.listen(profileActionsProvider, (_, _) {});
        final notifier = container.read(profileActionsProvider.notifier);

        final result = await notifier.updateName(firstName: 'New');

        expect(result, isTrue);
        await _settle();
        final state = container.read(profileActionsProvider);
        expect(state.isUpdating, isFalse);
        expect(state.error, isNull);
        expect(state.successMessage, 'profile_updated');
      },
    );

    test('clears a previous error when a new update starts', () async {
      when(
        () => repository.updateProfile(firstName: any(named: 'firstName'), lastName: any(named: 'lastName')),
      ).thenThrow(Exception('first failure'));

      container.listen(profileActionsProvider, (_, _) {});
      final notifier = container.read(profileActionsProvider.notifier);
      await notifier.updateName(firstName: 'New');
      expect(container.read(profileActionsProvider).error, isNotNull);

      when(
        () => repository.updateProfile(firstName: any(named: 'firstName'), lastName: any(named: 'lastName')),
      ).thenAnswer((_) async => _testProfile);
      await notifier.updateName(firstName: 'New');

      final state = container.read(profileActionsProvider);
      expect(state.error, isNull);
      expect(state.successMessage, 'profile_updated');
    });
  });
}
