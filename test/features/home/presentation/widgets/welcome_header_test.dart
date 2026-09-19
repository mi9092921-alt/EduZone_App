import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/auth/application/providers/auth_provider.dart';
import 'package:app/features/home/presentation/widgets/welcome_header.dart';
import 'package:app/shared/models/account_status.dart';
import 'package:app/shared/models/app_user.dart';
import 'package:app/shared/models/auth_state.dart';
import 'package:app/shared/models/user_access.dart';
import 'package:app/shared/providers/home_notifications_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_gateways.dart';

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
  //
  // The unread badge is read through the shared HomeNotificationsGateway
  // contract (implemented by the notifications feature in the real app),
  // so these tests override the gateway with an in-memory fake. When the
  // gateway is NOT overridden (null default) the badge must be absent.
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

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
              homeNotificationsGatewayProvider.overrideWithValue(
                FakeHomeNotificationsGateway(),
              ),
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
              homeNotificationsGatewayProvider.overrideWithValue(
                FakeHomeNotificationsGateway(),
              ),
            ],
            child: const WelcomeHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome, jane.doe 👋'), findsOneWidget);
    });

    testWidgets('shows no badge when the notifications gateway is unavailable',
        (WidgetTester tester) async {
      // Null gateway default (bare container): unreadCount degrades to 0.
      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [
              authProvider
                  .overrideWithValue(authenticatedUser(firstName: 'Sam')),
            ],
            child: const WelcomeHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('shows no badge when there are no unread notifications',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [
              authProvider
                  .overrideWithValue(authenticatedUser(firstName: 'Sam')),
              homeNotificationsGatewayProvider.overrideWithValue(
                FakeHomeNotificationsGateway(),
              ),
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
              homeNotificationsGatewayProvider.overrideWithValue(
                FakeHomeNotificationsGateway(
                  initial: [
                    buildNotification(),
                    buildNotification(id: 'n2'),
                  ],
                ),
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
      final manyNotifications = List.generate(120, (i) => buildNotification(id: 'n$i'));

      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [
              authProvider
                  .overrideWithValue(authenticatedUser(firstName: 'Sam')),
              homeNotificationsGatewayProvider.overrideWithValue(
                FakeHomeNotificationsGateway(initial: manyNotifications),
              ),
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
