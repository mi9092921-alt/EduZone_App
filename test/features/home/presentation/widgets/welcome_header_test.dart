import 'dart:async';

import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/home/presentation/widgets/welcome_header.dart';
import 'package:app/features/notifications/domain/entities/app_notification.dart';
import 'package:app/features/notifications/application/providers/notifications_provider.dart';
import 'package:app/features/profile/domain/entities/student_profile.dart';
import 'package:app/features/profile/application/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // NOTE: the notification bell icon calls `context.push(...)` (go_router),
  // which needs a real GoRouter ancestor. These tests verify rendered
  // content only and do not tap that icon — see the same note in
  // discovery_banner_test.dart.
  //
  // `child` is expected to already be wrapped in its own `ProviderScope`
  // (with whatever overrides that test needs) by the caller — this avoids
  // needing to name the `Override` type explicitly here, which keeps this
  // helper compatible regardless of exactly how a given Riverpod version
  // exports/names that type.
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

  group('WelcomeHeader', () {
    testWidgets('greets the user with their first name when profile loads',
        (WidgetTester tester) async {
      const profile = StudentProfile(
        id: 'u1',
        email: 'jane.doe@example.com',
        firstName: 'Jane',
        lastName: 'Doe',
      );

      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [
              profileProvider.overrideWith((ref) async => profile),
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

    testWidgets('falls back to the default name while the profile is loading',
        (WidgetTester tester) async {
      // An uncompleted Completer (rather than Future.delayed) keeps the
      // provider in the "loading" state indefinitely without registering a
      // Timer — Future.delayed here would leave a pending Timer that
      // flutter_test flags as a leak/failure at teardown since it never
      // fires within the test.
      final neverCompletes = Completer<StudentProfile>();
      addTearDown(() {
        if (!neverCompletes.isCompleted) {
          neverCompletes.complete(const StudentProfile(id: 'u1', email: 'a@b.com'));
        }
      });

      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [
              profileProvider.overrideWith((ref) => neverCompletes.future),
              notificationsProvider.overrideWith((ref) async => []),
            ],
            child: const WelcomeHeader(),
          ),
        ),
      );
      // Deliberately do not pumpAndSettle — we want to observe the loading
      // frame before the completer ever resolves.
      await tester.pump();

      expect(find.text('Welcome, Student 👋'), findsOneWidget);
    });

    testWidgets('falls back to the default name when the profile fails to load',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [
              profileProvider.overrideWith(
                (ref) async => throw Exception('profile fetch failed'),
              ),
              notificationsProvider.overrideWith((ref) async => []),
            ],
            child: const WelcomeHeader(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Student 👋'), findsOneWidget);
    });

    testWidgets('shows no badge when there are no unread notifications',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [
              profileProvider.overrideWith(
                (ref) async =>
                    const StudentProfile(id: 'u1', email: 'a@b.com', firstName: 'Sam'),
              ),
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
              profileProvider.overrideWith(
                (ref) async =>
                    const StudentProfile(id: 'u1', email: 'a@b.com', firstName: 'Sam'),
              ),
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
              profileProvider.overrideWith(
                (ref) async =>
                    const StudentProfile(id: 'u1', email: 'a@b.com', firstName: 'Sam'),
              ),
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
