import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/auth/application/providers/auth_provider.dart';
import 'package:app/features/home/presentation/widgets/welcome_header.dart';
import 'package:app/features/notifications/application/providers/notifications_provider.dart';
import 'package:app/shared/models/account_status.dart';
import 'package:app/shared/models/app_notification.dart';
import 'package:app/shared/models/app_user.dart';
import 'package:app/shared/models/auth_state.dart';
import 'package:app/shared/models/user_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // NOTE: the notification bell icon calls `context.push(...)` (go_router),
  // which needs a real GoRouter ancestor. These tests verify rendered
  // content only and do not tap that icon — see the same note in
  // discovery_banner_test.dart.
  //
  // WelcomeHeader reads the signed-in user's name from `authProvider`
  // (AppUser) — NOT from the profile feature — so these tests seed an
  // authenticated auth state directly via `overrideWithValue` and never
  // touch Supabase.
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  AppNotification unreadNotification(String id) => AppNotification(
        id: id,
        userId: 'u1',
        tenantId: 't1',
        createdAt: DateTime(2024),
      );

  AuthAuthenticated authenticatedUser({String? firstName}) =>
      AuthAuthenticated(
        user: AppUser(
          id: 'u1',
          email: 'jane.doe@example.com',
          firstName: firstName,
        ),
        access: const UserAccess(status: AccountStatus.active),
      );

  group('WelcomeHeader', () {
    testWidgets('greets the user with their first name when signed in',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [
              authProvider
                  .overrideWithValue(authenticatedUser(firstName: 'Jane')),
              notificationsProvider.overrideWith((ref) async => []),
            ],
            child: const WelcomeHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Jane 👋'), findsOneWidget);
      expect(find.text('What do you want to learn today?'), findsOneWidget);
    });

    testWidgets(
        'falls back to the email prefix when the user has no first name',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWithValue(authenticatedUser()),
              notificationsProvider.overrideWith((ref) async => []),
            ],
            child: const WelcomeHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome, jane.doe 👋'), findsOneWidget);
    });

    testWidgets('shows no badge when there are no unread notifications',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [
              authProvider
                  .overrideWithValue(authenticatedUser(firstName: 'Sam')),
              notificationsProvider.overrideWith((ref) async => []),
            ],
            child: const WelcomeHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('shows the unread count badge when there are unread notifications',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [
              authProvider
                  .overrideWithValue(authenticatedUser(firstName: 'Sam')),
              notificationsProvider.overrideWith(
                (ref) async => [unreadNotification('n1'), unreadNotification('n2')],
              ),
            ],
            child: const WelcomeHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('caps the displayed badge count at "99+"',
        (WidgetTester tester) async {
      final manyNotifications =
          List.generate(120, (i) => unreadNotification('n$i'));

      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [
              authProvider
                  .overrideWithValue(authenticatedUser(firstName: 'Sam')),
              notificationsProvider.overrideWith((ref) async => manyNotifications),
            ],
            child: const WelcomeHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('99+'), findsOneWidget);
    });
  });
}
