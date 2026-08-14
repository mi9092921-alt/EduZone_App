import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/tokens/app_theme.dart';
import 'package:app/features/auth/application/providers/auth_provider.dart';
import 'package:app/features/auth/domain/entities/auth_state.dart';
import 'package:app/features/auth/domain/entities/user_access.dart';
import 'package:app/features/auth/domain/enums/account_status.dart';
import 'package:app/features/auth/presentation/screens/locked_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// See banned_screen_test.dart for the rationale behind the fixed-state fake
// Auth notifier approach used across all AuthRestricted screens.
class _FixedAuth extends Auth {
  _FixedAuth(this._state);
  final AuthState _state;

  @override
  AuthState build() => _state;
}

Future<void> pumpLocked(
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
        home: const LockedScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('renders without throwing for a locked AuthRestricted state',
      (tester) async {
    await pumpLocked(
      tester,
      state: const AuthRestricted(
        status: AccountStatus.locked,
        access: UserAccess(status: AccountStatus.locked),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(LockedScreen), findsOneWidget);
  });

  testWidgets('shows the lock reason block when access.message is set',
      (tester) async {
    await pumpLocked(
      tester,
      state: const AuthRestricted(
        status: AccountStatus.locked,
        access: UserAccess(
          status: AccountStatus.locked,
          message: 'Too many failed login attempts',
        ),
      ),
    );
    await tester.pump();

    expect(
      find.textContaining('Too many failed login attempts'),
      findsOneWidget,
    );
  });

  testWidgets('does not throw when access.message is null', (tester) async {
    await pumpLocked(
      tester,
      state: const AuthRestricted(
        status: AccountStatus.locked,
        access: UserAccess(status: AccountStatus.locked),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
