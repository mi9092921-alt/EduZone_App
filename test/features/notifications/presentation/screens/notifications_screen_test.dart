import 'dart:async';

import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/notifications/application/providers/notifications_provider.dart';
import 'package:app/features/notifications/domain/entities/app_notification.dart';
import 'package:app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// NOTE ON SCOPE: the "Mark all read" action reads
// `SupabaseService.client.auth.currentUser?.id` directly inside its
// onPressed handler (not during build), which requires a real initialized
// Supabase client. No test in this repo currently stubs that singleton for
// widget tests, so this file — like every other screen test added in this
// pass — does not tap that button. It's still exercised indirectly by the
// `AuthAuthenticated` integration tests in integration_test/app_test.dart
// once Supabase is live in that harness.

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
}
