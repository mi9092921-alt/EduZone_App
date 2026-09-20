import 'dart:async';

import 'package:app/features/auth/application/providers/auth_provider.dart';
import 'package:app/features/notifications/application/providers/notifications_provider.dart';
import 'package:app/features/notifications/presentation/widgets/realtime_notification_handler.dart';
import 'package:app/shared/models/account_status.dart';
import 'package:app/shared/models/app_notification.dart';
import 'package:app/shared/models/app_user.dart';
import 'package:app/shared/models/auth_state.dart';
import 'package:app/shared/models/user_access.dart';
import 'package:app/shared/models/user_role.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Fixtures (widget test) ──────────────────────────────────────────────────

class _FakeAuthenticatedAuth extends Auth {
  @override
  AuthState build() =>
      const AuthAuthenticated(user: _testUser, access: _testAccess);
}

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

// ─── Unit: RealtimeRefreshThrottle ───────────────────────────────────────────

void main() {
  group('RealtimeRefreshThrottle', () {
    test('first event refreshes immediately (leading edge)', () {
      fakeAsync((async) {
        var refreshes = 0;
        final throttle = RealtimeRefreshThrottle(
          minInterval: const Duration(milliseconds: 600),
          onRefresh: () => refreshes++,
        );

        throttle.notify();
        expect(refreshes, 1);
        throttle.dispose();
      });
    });

    test('burst of events inside the window collapses into one trailing '
        'refresh instead of one per event', () {
      fakeAsync((async) {
        var refreshes = 0;
        final throttle = RealtimeRefreshThrottle(
          minInterval: const Duration(milliseconds: 600),
          onRefresh: () => refreshes++,
        );

        // Leading edge.
        throttle.notify();
        expect(refreshes, 1);

        // Simulates markAllAsRead on 3 rows: 3 events, no extra refreshes.
        throttle.notify();
        throttle.notify();
        throttle.notify();
        expect(refreshes, 1);

        // Trailing edge: exactly one coalesced refresh when the window closes.
        async.elapse(const Duration(milliseconds: 700));
        expect(refreshes, 2);
        throttle.dispose();
      });
    });

    test('event after the window closes refreshes immediately again', () {
      fakeAsync((async) {
        var refreshes = 0;
        final throttle = RealtimeRefreshThrottle(
          minInterval: const Duration(milliseconds: 600),
          onRefresh: () => refreshes++,
        );

        throttle.notify();
        expect(refreshes, 1);

        async.elapse(const Duration(milliseconds: 700));
        throttle.notify();
        expect(refreshes, 2);
        throttle.dispose();
      });
    });

    test('no trailing refresh when no further events arrive in the window', () {
      fakeAsync((async) {
        var refreshes = 0;
        final throttle = RealtimeRefreshThrottle(
          minInterval: const Duration(milliseconds: 600),
          onRefresh: () => refreshes++,
        );

        throttle.notify();
        expect(refreshes, 1);

        async.elapse(const Duration(milliseconds: 700));
        expect(refreshes, 1);
        throttle.dispose();
      });
    });

    test('notify after dispose is a no-op and never refreshes', () {
      fakeAsync((async) {
        var refreshes = 0;
        final throttle = RealtimeRefreshThrottle(
          minInterval: const Duration(milliseconds: 600),
          onRefresh: () => refreshes++,
        );
        throttle.dispose();

        throttle.notify();
        async.elapse(const Duration(milliseconds: 700));
        expect(refreshes, 0);
      });
    });
  });

  // ─── Widget wiring ────────────────────────────────────────────────────────
  //
  // The throttle's timing behaviour is unit-tested above with fakeAsync;
  // here we only assert the handler wires realtime events into it.

  group('RealtimeNotificationHandler', () {
    testWidgets(
      'a realtime event invalidates notificationsProvider (leading edge)',
      (tester) async {
        // A Completer-backed stream (not a StreamController): the sink-close
        // teardown inside the test binding's fake clock deadlocks on the
        // done-event microtask, and a StreamController would trip the
        // close_sinks lint. The completer's future completes mid-test; the
        // stream emits once and finishes by itself.
        final changesCompleter = Completer<void>();
        var notificationsBuildCount = 0;

        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(() => _FakeAuthenticatedAuth()),
            notificationsChangesProvider.overrideWith(
              (ref) => Stream<void>.fromFuture(changesCompleter.future),
            ),
            notificationsProvider.overrideWith((ref) async {
              notificationsBuildCount++;
              return const <AppNotification>[];
            }),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: RealtimeNotificationHandler(child: SizedBox.expand()),
            ),
          ),
        );
        // Initial notificationsProvider build ("first load").
        await tester.pump();
        expect(notificationsBuildCount, 1);

        // One realtime event: first pump delivers it to the handler's
        // listener (leading refresh), second flushes the invalidated
        // provider's rebuild.
        changesCompleter.complete(null);
        await tester.pump();
        await tester.pump();
        expect(notificationsBuildCount, 2);

        // Let the throttle window close so no timer is left pending at
        // teardown.
        await tester.pump(const Duration(milliseconds: 700));
      },
    );
  });
}
