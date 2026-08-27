import 'dart:async';

import 'package:app/core/error/failures.dart';
import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/auth/application/providers/auth_provider.dart';
import 'package:app/features/auth/domain/entities/app_user.dart';
import 'package:app/features/auth/domain/entities/auth_state.dart';
import 'package:app/features/auth/domain/entities/user_access.dart';
import 'package:app/features/auth/domain/enums/account_status.dart';
import 'package:app/features/auth/domain/enums/user_role.dart';
import 'package:app/features/notifications/application/providers/notifications_provider.dart';
import 'package:app/features/notifications/domain/entities/app_notification.dart';
import 'package:app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// The "Mark all read" action used to read
// `SupabaseService.client.auth.currentUser?.id` directly inside its
// onPressed handler, which required a real initialized Supabase client and
// made this action impossible to exercise from a widget test. It now reads
// the user id from `authProvider` (the same testable source every other
// screen in this app uses), so the tap can be verified end-to-end below —
// see the "mark all as read" group.

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

class _FakeAuth extends Auth {
  @override
  AuthState build() =>
      const AuthAuthenticated(user: _testUser, access: _testAccess);
}

class _FakeUnauthenticatedAuth extends Auth {
  @override
  AuthState build() => const AuthUnauthenticated();
}

class _RecordingNotificationsRepository implements NotificationsRepository {
  String? lastMarkedAllAsReadUserId;
  String? lastMarkedAsReadId;

  @override
  Future<Either<Failure, List<AppNotification>>> getNotifications(
    String userId,
  ) async =>
      const Right([]);

  @override
  Stream<void> watchChanges(String userId) => const Stream<void>.empty();

  @override
  Future<Either<Failure, void>> markAsRead(String notificationId) async {
    lastMarkedAsReadId = notificationId;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> markAllAsRead(String userId) async {
    lastMarkedAllAsReadUserId = userId;
    return const Right(null);
  }
}

AppNotification _notification({
  required String id,
  required bool isRead,
  String title = 'New lesson available',
}) {
  return AppNotification(
    id: id,
    userId: 'user-1',
    tenantId: 'tenant-1',
    isRead: isRead,
    createdAt: DateTime(2024),
    details: NotificationDetails(title: title, body: 'Body for $title'),
  );
}

Future<void> pumpNotifications(
  WidgetTester tester, {
  required List<Override> overrides,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NotificationsScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('shows a loading skeleton while notifications are fetching', (
    tester,
  ) async {
    await pumpNotifications(
      tester,
      overrides: [
        notificationsProvider.overrideWith(
          (ref) => Completer<List<AppNotification>>().future,
        ),
      ],
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    // The skeleton renders 8 placeholder AppNotification.skeleton() tiles.
    expect(find.text(AppNotification.skeleton().title), findsWidgets);
  });

  testWidgets('shows the empty state when there are no notifications', (
    tester,
  ) async {
    await pumpNotifications(
      tester,
      overrides: [
        notificationsProvider.overrideWith((ref) async => const []),
      ],
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.noNotifications), findsOneWidget);
  });

  testWidgets('renders each notification title when the list has content', (
    tester,
  ) async {
    await pumpNotifications(
      tester,
      overrides: [
        notificationsProvider.overrideWith(
          (ref) async => [
            _notification(id: '1', isRead: false, title: 'First'),
            _notification(id: '2', isRead: true, title: 'Second'),
          ],
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets(
      'switching to the Unread filter hides read notifications without '
      're-fetching from the network', (tester) async {
    var fetchCount = 0;
    await pumpNotifications(
      tester,
      overrides: [
        notificationsProvider.overrideWith((ref) async {
          fetchCount++;
          return [
            _notification(id: '1', isRead: false, title: 'Unread one'),
            _notification(id: '2', isRead: true, title: 'Already read'),
          ];
        }),
      ],
    );
    await tester.pumpAndSettle();
    expect(fetchCount, 1);
    expect(find.text('Unread one'), findsOneWidget);
    expect(find.text('Already read'), findsOneWidget);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.unreadFilter));
    await tester.pumpAndSettle();

    expect(find.text('Unread one'), findsOneWidget);
    expect(find.text('Already read'), findsNothing);
    // Filtering is a pure client-side re-derivation of already-fetched
    // data, not a new network call.
    expect(fetchCount, 1);
  });

  testWidgets(
      'shows the "all caught up" empty state (not the generic empty state) '
      'when every notification is read and the Unread filter is active',
      (tester) async {
    await pumpNotifications(
      tester,
      overrides: [
        notificationsProvider.overrideWith(
          (ref) async => [_notification(id: '1', isRead: true)],
        ),
      ],
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.unreadFilter));
    await tester.pumpAndSettle();

    expect(find.text(l10n.noUnreadNotifications), findsOneWidget);
    expect(find.text(l10n.noNotifications), findsNothing);
  });

  testWidgets(
      'shows a generic error message (never the raw exception) when the '
      'notifications fetch fails', (tester) async {
    await pumpNotifications(
      tester,
      overrides: [
        notificationsProvider.overrideWith(
          (ref) async => throw Exception('rls denied'),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // This screen's error description is produced by
    // ErrorHandler.getMessage(context, e), which classifies the error to
    // a fixed, localized string rather than displaying `e.toString()`
    // (Section 14). An unclassified Exception like the one thrown above
    // falls through to l10n.errorGeneric — see
    // lib/shared/utils/error_handler.dart and
    // test/shared/utils/error_handler_test.dart for dedicated coverage.
    expect(find.text(l10n.errorGeneric), findsOneWidget);
    expect(find.textContaining('rls denied'), findsNothing);
  });

  group('NotificationsScreen — mark all as read', () {
    testWidgets(
        'tapping "Mark all read" calls the repository with the '
        "authenticated user's id from authProvider, not a raw Supabase "
        'singleton lookup', (tester) async {
      final repository = _RecordingNotificationsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeAuth()),
            notificationsRepositoryProvider.overrideWithValue(repository),
            notificationsProvider.overrideWith(
              (ref) async => [_notification(id: '1', isRead: false)],
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.markAllRead));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(repository.lastMarkedAllAsReadUserId, _testUser.id);
      expect(repository.lastMarkedAsReadId, isNull);
    });

    testWidgets(
        'tapping "Mark all read" while unauthenticated is a no-op (no '
        'repository call, no crash)', (tester) async {
      final repository = _RecordingNotificationsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _FakeUnauthenticatedAuth()),
            notificationsRepositoryProvider.overrideWithValue(repository),
            notificationsProvider.overrideWith(
              (ref) async => [_notification(id: '1', isRead: false)],
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.markAllRead));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(repository.lastMarkedAllAsReadUserId, isNull);
    });
  });
}
