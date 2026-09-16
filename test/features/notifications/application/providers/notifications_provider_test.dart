import 'dart:async';

import 'package:app/core/error/failures.dart';
import 'package:app/features/auth/application/providers/auth_provider.dart';
import 'package:app/features/notifications/application/providers/notifications_provider.dart';
import 'package:app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:app/shared/models/account_status.dart';
import 'package:app/shared/models/app_notification.dart';
import 'package:app/shared/models/app_user.dart';
import 'package:app/shared/models/auth_state.dart';
import 'package:app/shared/models/user_access.dart';
import 'package:app/shared/models/user_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

// ─── Mocks & fakes ───────────────────────────────────────────────────────────

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

class _FakeUnauthenticatedAuth extends Auth {
  @override
  AuthState build() => const AuthUnauthenticated();
}

class _FakeAuthenticatedAuth extends Auth {
  @override
  AuthState build() =>
      const AuthAuthenticated(user: _testUser, access: _testAccess);
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

AppNotification _notification(
  String id, {
  bool isRead = false,
  String? title = 'Test title',
}) {
  return AppNotification(
    id: id,
    userId: 'user-1',
    tenantId: 'tenant-1',
    isRead: isRead,
    createdAt: DateTime(2025),
    details: title == null ? null : NotificationDetails(title: title, body: 'Body'),
  );
}

/// Drains pending microtasks so the async `notifications` notifier settles
/// before assertions (same pattern as todo_notifier_test.dart).
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late MockNotificationsRepository repository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue('');
  });

  setUp(() {
    repository = MockNotificationsRepository();
container = ProviderContainer(
      overrides: [
        notificationsRepositoryProvider.overrideWithValue(repository),
        authProvider.overrideWith(() => _FakeUnauthenticatedAuth()),
      ],
    );
    addTearDown(container.dispose);
  });

  group('notificationsProvider', () {
    test('returns [] for an unauthenticated user without touching the repo',
        () async {
      container.listen(notificationsProvider, (_, _) {});

      final result = await container.read(notificationsProvider.future);

      expect(result, isEmpty);
      verifyNever(() => repository.getNotifications(any()));
    });

    test('returns the repository list for an authenticated user', () async {
      final container = ProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(repository),
          authProvider.overrideWith(() => _FakeAuthenticatedAuth()),
        ],
      );
      addTearDown(container.dispose);

      final list = [_notification('n-1'), _notification('n-2')];
      when(() => repository.getNotifications(any()))
          .thenAnswer((_) async => Right(list));

      container.listen(notificationsProvider, (_, _) {});

      final result = await container.read(notificationsProvider.future);

      expect(result, list);
      verify(() => repository.getNotifications('user-1')).called(1);
    });

    test('surfaces a repository failure as an error state', () async {
      final container = ProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(repository),
          authProvider.overrideWith(() => _FakeAuthenticatedAuth()),
        ],
      );
      addTearDown(container.dispose);

      const failure = ServerFailure('boom');
      when(() => repository.getNotifications(any()))
          .thenAnswer((_) async => const Left(failure));

      // NOTE: `expectLater(container.read(...future), throwsA(...))`
      // deadlocks here — a known Riverpod edge case where an autoDispose
      // async provider's first `build()` throwing, observed via a cold
      // `.future` read, never settles (see downloads_notifier_test.dart for
      // the same established workaround): establish a listener first, then
      // assert the synchronous state.
      final sub = container.listen(notificationsProvider, (_, _) {});
      addTearDown(sub.close);
      await _settle();

      final state = container.read(notificationsProvider);
      expect(state.hasError, isTrue);
      expect(state.error, same(failure));
    });
  });

  group('unreadCountProvider', () {
    test('is 0 for an unauthenticated user', () async {
      container.listen(notificationsProvider, (_, _) {});
      await container.read(notificationsProvider.future);
      await _settle();

      expect(container.read(unreadCountProvider), 0);
    });

    test('counts only unread notifications', () async {
      final container = ProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(repository),
          authProvider.overrideWith(() => _FakeAuthenticatedAuth()),
        ],
      );
      addTearDown(container.dispose);

      final list = [
        _notification('n-1'),
        _notification('n-2', isRead: true),
        _notification('n-3'),
      ];
      when(() => repository.getNotifications(any()))
          .thenAnswer((_) async => Right(list));

      container.listen(notificationsProvider, (_, _) {});
      await container.read(notificationsProvider.future);
      await _settle();

      expect(container.read(unreadCountProvider), 2);
    });

    test('is 0 while the notifications list has not loaded yet', () {
      expect(container.read(unreadCountProvider), 0);
    });
  });

  group('NotificationFilter', () {
    test('defaults to all', () {
      container.listen(notificationFilterProvider, (_, _) {});

      expect(container.read(notificationFilterProvider), 'all');
    });

    test('setFilter updates the state', () {
      final notifier = container.read(notificationFilterProvider.notifier);

      notifier.setFilter('unread');

      expect(container.read(notificationFilterProvider), 'unread');
    });
  });

  group('notificationsChangesProvider', () {
    test('emits nothing for an unauthenticated user (empty stream)', () async {
      var eventCount = 0;
      final sub = container.listen(
        notificationsChangesProvider,
        (_, _) => eventCount++,
      );
      addTearDown(sub.close);
      await _settle();

      expect(eventCount, 0);
    });

    test('forwards the repository change stream for an authenticated user',
        () async {
      final controller = StreamController<void>();
      final container = ProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(repository),
          authProvider.overrideWith(() => _FakeAuthenticatedAuth()),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(controller.close);

      when(() => repository.watchChanges(any()))
          .thenAnswer((_) => controller.stream);

      final events = <int>[];
      final sub = container.listen(
        notificationsChangesProvider,
        (_, _) => events.add(events.length),
      );
      addTearDown(sub.close);
      await _settle();

      controller.add(null);
      await _settle();

      expect(events, hasLength(1));
      verify(() => repository.watchChanges('user-1')).called(1);
    });
  });
}
