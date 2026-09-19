import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/home/presentation/widgets/notifications_preview.dart';
import 'package:app/shared/models/app_notification.dart';
import 'package:app/shared/providers/home_notifications_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `ProviderListenable` is exported from misc.dart in the resolved Riverpod
// version (not from the main flutter_riverpod.dart export list).
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_gateways.dart';

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

  Widget buildWithGateway(FakeHomeNotificationsGateway gateway) {
    return buildTestableWidget(
      ProviderScope(
        overrides: [
          homeNotificationsGatewayProvider.overrideWithValue(gateway),
        ],
        child: const NotificationsPreview(),
      ),
    );
  }

  group('NotificationsPreview', () {
    testWidgets('renders nothing when the gateway is not wired (null)',
        (WidgetTester tester) async {
      // Bare container: homeNotificationsGatewayProvider defaults to null —
      // the preview must degrade to nothing instead of throwing.
      await tester.pumpWidget(
        buildTestableWidget(
          const ProviderScope(child: NotificationsPreview()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsNothing);
    });

    testWidgets('renders nothing when there are no notifications at all',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWithGateway(FakeHomeNotificationsGateway()));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsNothing);
    });

    testWidgets('renders nothing when every notification is already read',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildWithGateway(
          FakeHomeNotificationsGateway(
            initial: [
              buildNotification(isRead: true, title: 'Already read'),
            ],
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
        buildWithGateway(
          FakeHomeNotificationsGateway(
            initial: [
              buildNotification(title: 'New assignment'),
              buildNotification(id: 'n2', isRead: true, title: 'Old, already read'),
              buildNotification(id: 'n3', title: 'Grade updated'),
            ],
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
        buildWithGateway(
          FakeHomeNotificationsGateway(
            initial: [
              buildNotification(title: 'First'),
              buildNotification(id: 'n2', title: 'Second'),
              buildNotification(id: 'n3', title: 'Third'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('Third'), findsNothing);
      expect(find.text('2 Notifications'), findsOneWidget);
    });

    testWidgets('marking a notification read goes through the gateway and '
        'refreshes it', (WidgetTester tester) async {
      final gateway = FakeHomeNotificationsGateway(
        initial: [buildNotification(title: 'New assignment')],
      );
      await tester.pumpWidget(buildWithGateway(gateway));
      await tester.pumpAndSettle();
      expect(find.text('New assignment'), findsOneWidget);

      // The tile's tap handler marks it read, then refreshes on success.
      await tester.tap(find.text('New assignment'));
      await tester.pumpAndSettle();

      expect(gateway.markAsReadCalls, hasLength(1));
      expect(gateway.markAsReadCalls.single.notificationId, 'n1');
      expect(gateway.markAsReadCalls.single.userId, 'user-1');
      expect(gateway.refreshCalls, 1);
    });

    testWidgets('renders nothing (silently) while notifications are loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          ProviderScope(
            overrides: [
              homeNotificationsGatewayProvider.overrideWithValue(
                _StaticGateway(
                  const AsyncValue<List<AppNotification>>.loading(),
                ),
              ),
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
              homeNotificationsGatewayProvider.overrideWithValue(
                _StaticGateway(
                  AsyncValue.error(Exception('network error'), StackTrace.empty),
                ),
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

/// Gateway whose `notifications` provider is pinned to one fixed
/// [AsyncValue] (used for the loading/error degradation states).
class _StaticGateway implements HomeNotificationsGateway {
  _StaticGateway(AsyncValue<List<AppNotification>> state)
      : _notificationsProvider =
            Provider<AsyncValue<List<AppNotification>>>((ref) => state);

  final Provider<AsyncValue<List<AppNotification>>> _notificationsProvider;

  @override
  ProviderListenable<AsyncValue<List<AppNotification>>> get notifications =>
      _notificationsProvider;

  @override
  ProviderListenable<int> get unreadCount => Provider<int>((ref) => 0);

  @override
  Future<bool> markAsRead({
    required String notificationId,
    required String userId,
  }) async => false;

  @override
  void refresh() {}
}
