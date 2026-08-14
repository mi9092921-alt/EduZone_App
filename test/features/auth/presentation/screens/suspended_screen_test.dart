import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/tokens/app_theme.dart';
import 'package:app/features/auth/application/providers/auth_provider.dart';
import 'package:app/features/auth/domain/entities/auth_state.dart';
import 'package:app/features/auth/domain/entities/user_access.dart';
import 'package:app/features/auth/domain/enums/account_status.dart';
import 'package:app/features/auth/presentation/screens/suspended_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// See banned_screen_test.dart for the rationale behind the fixed-state fake
// Auth notifier approach.
//
// IMPORTANT: every state below deliberately has access.until == null.
// SuspendedScreen.initState() -> _startCountdown() calls
// ref.read(authProvider.notifier).verifyAccess() immediately if `until` is
// non-null and already in the past. Our fake Auth only overrides build(),
// so _remoteDataSource (a `late final` normally set inside the real
// build()) is never assigned — calling the real, inherited verifyAccess()
// would hit that uninitialized field. Keeping `until: null` skips the
// timer/verifyAccess() path entirely (see suspended_screen.dart:
// `if (until == null) return;`), which is sufficient to cover rendering,
// the reason block, and dispose() safety without needing a fuller
// integration-style double for Auth's data-source-dependent methods.
class _FixedAuth extends Auth {
  _FixedAuth(this._state);
  final AuthState _state;

  @override
  AuthState build() => _state;
}

Future<void> pumpSuspended(
  WidgetTester tester, {
  required AuthState state,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [authProvider.overrideWith(() => _FixedAuth(state))],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(const Locale('en')),
        home: const SuspendedScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'renders without throwing for a suspended AuthRestricted state '
      '(no countdown — access.until is null)', (tester) async {
    await pumpSuspended(
      tester,
      state: const AuthRestricted(
        status: AccountStatus.suspended,
        access: UserAccess(status: AccountStatus.suspended),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SuspendedScreen), findsOneWidget);
  });

  testWidgets('shows the suspension reason block when access.message is set',
      (tester) async {
    await pumpSuspended(
      tester,
      state: const AuthRestricted(
        status: AccountStatus.suspended,
        access: UserAccess(
          status: AccountStatus.suspended,
          message: 'Payment dispute under review',
        ),
      ),
    );
    await tester.pump();

    expect(
      find.textContaining('Payment dispute under review'),
      findsOneWidget,
    );
  });

  testWidgets(
      'disposes cleanly across a few frames without a pending-timer error',
      (tester) async {
    await pumpSuspended(
      tester,
      state: const AuthRestricted(
        status: AccountStatus.suspended,
        access: UserAccess(status: AccountStatus.suspended),
      ),
    );
    // Bounded, short pumps only — mirrors splash_screen_test.dart's
    // approach for screens with a repeating Timer.periodic. No timer was
    // even started here (until == null), so this mainly locks in that
    // dispose() (which unconditionally does `_countdownTimer?.cancel()`)
    // stays safe to call on a null timer.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Unmount by pumping an empty tree — exercises dispose().
    await tester.pumpWidget(const SizedBox.shrink());

    expect(tester.takeException(), isNull);
  });
}
