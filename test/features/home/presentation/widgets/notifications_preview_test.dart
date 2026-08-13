import 'dart:async';

import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/home/presentation/widgets/notifications_preview.dart';
import 'package:app/features/notifications/application/providers/notifications_provider.dart';
import 'package:app/features/notifications/domain/entities/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // `child` is expected to already be wrapped in its own `ProviderScope`
  // (with whatever overrides that test needs) by the caller — this avoids
  // needing to name the `Override` type explicitly here, which keeps this
  // helper compatible regardless of exactly how a given Riverpod version
  // exports/names that type.
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  AppNotification notification({
    required String id,
    required bool isRead,
    required String title,
  }) =>
      AppNotification(
        id: id,
        userId: 'u1',
        tenantId: 't1',
        isRead: isRead,
        createdAt: DateTime(2024),
        details: NotificationDetails(title: title, body: 'Body for $title'),
      );

  group('NotificationsPreview', () {
    testWidgets('renders nothing when there are no notifications at all',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [notificationsProvider.overrideWith((ref) async => [])],
            child: const NotificationsPreview(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsNothing);
    });

    testWidgets('renders nothing when every notification is already read',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [
              notificationsProvider.overrideWith(
                (ref) async => [
                  notification(id: 'n1', isRead: true, title: 'Already read'),
                ],
              ),
            ],
            child: const NotificationsPreview(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsNothing);
      expect(find.text('Already read'), findsNothing);
    });

    testWidgets('renders the section header and unread notification tiles',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [
              notificationsProvider.overrideWith(
                (ref) async => [
                  notification(id: 'n1', isRead: false, title: 'New assignment'),
                  notification(id: 'n2', isRead: true, title: 'Old, already read'),
                  notification(id: 'n3', isRead: false, title: 'Grade updated'),
                ],
              ),
            ],
            child: const NotificationsPreview(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('New assignment'), findsOneWidget);
      expect(find.text('Grade updated'), findsOneWidget);
      // Read notifications are filtered out entirely by this widget.
      expect(find.text('Old, already read'), findsNothing);
    });

    testWidgets('caps the preview at 2 unread notifications even if more exist',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [
              notificationsProvider.overrideWith(
                (ref) async => [
                  notification(id: 'n1', isRead: false, title: 'First'),
                  notification(id: 'n2', isRead: false, title: 'Second'),
                  notification(id: 'n3', isRead: false, title: 'Third'),
                ],
              ),
            ],
            child: const NotificationsPreview(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('Third'), findsNothing);
      expect(find.text('2 Notifications'), findsOneWidget);
    });

    testWidgets('renders nothing (silently) while notifications are loading',
        (WidgetTester tester) async {
      // An uncompleted Completer (rather than Future.delayed) keeps the
      // provider in the "loading" state without registering a Timer that
      // would otherwise be flagged as a pending-timer leak at teardown.
      final neverCompletes = Completer<List<AppNotification>>();
      addTearDown(() {
        if (!neverCompletes.isCompleted) neverCompletes.complete([]);
      });

      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [
              notificationsProvider.overrideWith((ref) => neverCompletes.future),
            ],
            child: const NotificationsPreview(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Notifications'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders nothing (silently) when the notifications fetch fails',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [
              notificationsProvider.overrideWith(
                (ref) async => throw Exception('network error'),
              ),
            ],
            child: const NotificationsPreview(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
