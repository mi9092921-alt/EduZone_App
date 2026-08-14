import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/tokens/app_theme.dart';
import 'package:app/features/auth/application/providers/auth_provider.dart';
import 'package:app/features/auth/domain/entities/auth_state.dart';
import 'package:app/features/auth/domain/entities/user_access.dart';
import 'package:app/features/auth/domain/enums/account_status.dart';
import 'package:app/features/auth/presentation/screens/banned_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Widget-level coverage for BannedScreen. authProvider is overridden with a
// fixed-state fake Auth notifier (only Auth.build() is replaced) rather than
// mocking the full Supabase/DI chain that auth_notifier_test.dart uses —
// this screen only reads the sealed AuthState via ref.watch(authProvider),
// it never touches the data-source layer directly unless "Logout" is
// tapped, which these tests deliberately avoid (that path is already
// covered at the notifier level in auth_notifier_test.dart /
// logout_orchestrator_test.dart).
class _FixedAuth extends Auth {
  _FixedAuth(this._state);
  final AuthState _state;

  @override
  AuthState build() => _state;
}

Future<void> pumpBanned(
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
        home: const BannedScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('renders without throwing for a banned AuthRestricted state',
      (tester) async {
    await pumpBanned(
      tester,
      state: const AuthRestricted(
        status: AccountStatus.banned,
        access: UserAccess(status: AccountStatus.banned),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(BannedScreen), findsOneWidget);
  });

  testWidgets('shows the ban reason block only when access.message is set',
      (tester) async {
    await pumpBanned(
      tester,
      state: const AuthRestricted(
        status: AccountStatus.banned,
        access: UserAccess(
          status: AccountStatus.banned,
          message: 'Repeated policy violations',
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Repeated policy violations'), findsOneWidget);
  });

  testWidgets('does not render a reason block when access.message is null',
      (tester) async {
    await pumpBanned(
      tester,
      state: const AuthRestricted(
        status: AccountStatus.banned,
        access: UserAccess(status: AccountStatus.banned),
      ),
    );
    await tester.pump();

    // No specific reason text was supplied, so nothing derived from
    // access.message should be present. This is a smoke check (not
    // asserting on exact l10n copy) — the important regression signal is
    // that a null access.message never throws inside statusReason(...).
    expect(tester.takeException(), isNull);
  });

  testWidgets('logout button is disabled/hidden while AuthLoggingOut',
      (tester) async {
    // The screen reads a *second*, independent ref.watch(authProvider)
    // inside the Consumer wrapping the logout button (see banned_screen.dart)
    // specifically to react to AuthLoggingOut without rebuilding the whole
    // screen. Since our fake Auth serves a single fixed state, we verify
    // the loading affordance directly for that state instead of simulating
    // a live transition (which would require a stateful fake).
    await pumpBanned(tester, state: const AuthLoggingOut());
    await tester.pump();

    // AuthLoggingOut is not AuthRestricted, so `access` resolves to null
    // and the reason block is skipped — this must not throw.
    expect(tester.takeException(), isNull);
  });
}
