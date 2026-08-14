import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/tokens/app_theme.dart';
import 'package:app/features/auth/application/providers/auth_provider.dart';
import 'package:app/features/auth/domain/entities/auth_state.dart';
import 'package:app/features/auth/domain/entities/user_access.dart';
import 'package:app/features/auth/domain/enums/account_status.dart';
import 'package:app/features/auth/presentation/screens/maintenance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// See suspended_screen_test.dart for the full rationale: access.until stays
// null throughout to avoid triggering the real, inherited verifyAccess()
// (which would hit an uninitialized _remoteDataSource on this fixed-state
// fake). MaintenanceScreen additionally starts an unconditional 60s polling
// Timer.periodic in initState() regardless of `until` — the bounded,
// short pumps below never reach that interval, so it never fires here.
class _FixedAuth extends Auth {
  _FixedAuth(this._state);
  final AuthState _state;

  @override
  AuthState build() => _state;
}

Future<void> pumpMaintenance(
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
        home: const MaintenanceScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('renders without throwing for a maintenance AuthRestricted '
      'state (no countdown — access.until is null)', (tester) async {
    await pumpMaintenance(
      tester,
      state: const AuthRestricted(
        status: AccountStatus.maintenance,
        access: UserAccess(status: AccountStatus.maintenance),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(MaintenanceScreen), findsOneWidget);
  });

  testWidgets(
      'disposes cleanly (cancels both polling and countdown timers) '
      'across a few bounded frames', (tester) async {
    await pumpMaintenance(
      tester,
      state: const AuthRestricted(
        status: AccountStatus.maintenance,
        access: UserAccess(status: AccountStatus.maintenance),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Unmount by pumping an empty tree — exercises dispose(), which must
    // cancel _pollingTimer and _countdownTimer unconditionally even though
    // only the polling timer was actually started in this scenario.
    await tester.pumpWidget(const SizedBox.shrink());

    expect(tester.takeException(), isNull);
  });
}
