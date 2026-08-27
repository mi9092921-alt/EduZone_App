import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/design_system/tokens/app_theme.dart';
import 'package:app/features/auth/application/providers/auth_provider.dart';
import 'package:app/features/auth/domain/entities/auth_state.dart';
import 'package:app/features/auth/presentation/screens/login_screen.dart';
import 'package:app/shared/utils/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Widget-level coverage for LoginScreen (AUTH-00 audit finding: every other
// auth screen — banned/suspended/locked/maintenance/splash — already has a
// widget test; this one had none).
//
// authProvider is overridden with a fake Auth notifier whose build() and
// login() are replaced (same pattern as banned_screen_test.dart /
// suspended_screen_test.dart), rather than mocking the full
// Supabase/AuthRemoteDataSource chain that auth_notifier_test.dart already
// exercises at the notifier level. This screen's own responsibility —
// client-side form validation, the terms-agreement gate, and calling
// `authProvider.notifier.login(email, password)` with the right
// arguments — is what these tests pin, not login's internal behavior.
class _FakeAuth extends Auth {
  _FakeAuth(this._state, {this.onLogin});
  final AuthState _state;
  final void Function(String email, String password)? onLogin;

  @override
  AuthState build() => _state;

  @override
  Future<void> login(String email, String password) async {
    onLogin?.call(email, password);
  }
}

Future<void> pumpLogin(
  WidgetTester tester, {
  AuthState state = const AuthUnauthenticated(),
  void Function(String email, String password)? onLogin,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(() => _FakeAuth(state, onLogin: onLogin)),
      ],
      child: MaterialApp(
        scaffoldMessengerKey: FeedbackService.messengerKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(const Locale('en')),
        home: const LoginScreen(),
      ),
    ),
  );
}

AppLocalizations l10nOf(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(LoginScreen)))!;

/// Checks the terms checkbox, fills both fields, and taps the login button.
Future<void> fillAndSubmit(
  WidgetTester tester, {
  String email = 'test@example.com',
  String password = 'password123',
  bool agreeToTerms = true,
}) async {
  if (agreeToTerms) {
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
  }
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.byType(ElevatedButton));
  await tester.pump();
}

void main() {
  setUpAll(() {
    // LoginScreen.initState() calls PackageInfo.fromPlatform() unconditionally
    // for the version footer; without a mock this throws MissingPluginException
    // on every pump in a test environment.
    PackageInfo.setMockInitialValues(
      appName: 'EduZone',
      packageName: 'com.eduzone.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('renders without throwing and shows both fields + button',
      (tester) async {
    await pumpLogin(tester);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  group('terms-agreement gate', () {
    testWidgets(
        'tapping login without agreeing to terms shows an error snackbar '
        'and never calls login()', (tester) async {
      var loginCalled = false;
      await pumpLogin(tester, onLogin: (_, _) => loginCalled = true);
      await tester.pump();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'test@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(); // let the snackbar animation start

      final l10n = l10nOf(tester);
      expect(find.text(l10n.agreeToTermsError), findsOneWidget);
      expect(loginCalled, isFalse);
    });
  });

  group('client-side validation', () {
    testWidgets('empty fields show required-field errors and never call '
        'login()', (tester) async {
      var loginCalled = false;
      await pumpLogin(tester, onLogin: (_, _) => loginCalled = true);
      await tester.pump();

      await fillAndSubmit(tester, email: '', password: '');

      final l10n = l10nOf(tester);
      // Each required-field message shares its text with the field label.
      expect(find.text(l10n.emailHint), findsNWidgets(2));
      expect(find.text(l10n.passwordHint), findsNWidgets(2));
      expect(loginCalled, isFalse);
    });

    testWidgets('malformed email shows errorInvalidEmail and never calls '
        'login()', (tester) async {
      var loginCalled = false;
      await pumpLogin(tester, onLogin: (_, _) => loginCalled = true);
      await tester.pump();

      await fillAndSubmit(
        tester,
        email: 'not-an-email',
      );

      final l10n = l10nOf(tester);
      expect(find.text(l10n.errorInvalidEmail), findsOneWidget);
      expect(loginCalled, isFalse);
    });

    testWidgets(
        'password under 8 characters shows errorPasswordTooShort and never '
        'calls login()', (tester) async {
      var loginCalled = false;
      await pumpLogin(tester, onLogin: (_, _) => loginCalled = true);
      await tester.pump();

      await fillAndSubmit(
        tester,
        password: 'short',
      );

      final l10n = l10nOf(tester);
      expect(find.text(l10n.errorPasswordTooShort), findsOneWidget);
      expect(loginCalled, isFalse);
    });

    testWidgets(
        'valid email + password + agreed terms calls login() with the '
        'trimmed, entered credentials', (tester) async {
      String? capturedEmail;
      String? capturedPassword;
      await pumpLogin(
        tester,
        onLogin: (email, password) {
          capturedEmail = email;
          capturedPassword = password;
        },
      );
      await tester.pump();

      await fillAndSubmit(
        tester,
        email: '  test@example.com  ',
      );

      expect(capturedEmail, 'test@example.com');
      expect(capturedPassword, 'password123');
    });
  });

  group('AuthAuthenticating (isLoading) state', () {
    testWidgets('shows a loading indicator and does not throw',
        (tester) async {
      await pumpLogin(tester, state: const AuthAuthenticating());
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Both AppScreen's overlay and AppButton's inline spinner render a
      // CircularProgressIndicator while isLoading is true; this only
      // asserts presence, not which one, so it isn't coupled to either
      // component's internal layout.
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });

  group('AuthUnauthenticated(error: ...) mapping', () {
    testWidgets('errorAuth key renders the localized errorAuth message',
        (tester) async {
      await pumpLogin(
        tester,
        state: const AuthUnauthenticated(error: 'errorAuth'),
      );
      await tester.pump();

      final l10n = l10nOf(tester);
      expect(find.text(l10n.errorAuth), findsOneWidget);
    });

    testWidgets('an unrecognized error key falls back to errorGeneric '
        '(never shows a raw internal error key to the user)', (tester) async {
      await pumpLogin(
        tester,
        state: const AuthUnauthenticated(error: 'some_unmapped_backend_key'),
      );
      await tester.pump();

      final l10n = l10nOf(tester);
      expect(find.text(l10n.errorGeneric), findsOneWidget);
      expect(find.text('some_unmapped_backend_key'), findsNothing);
    });

    testWidgets('no error shown when error is null', (tester) async {
      await pumpLogin(tester);
      await tester.pump();

      final l10n = l10nOf(tester);
      expect(find.text(l10n.errorGeneric), findsNothing);
      expect(find.text(l10n.errorAuth), findsNothing);
    });
  });

  group('layout / dead-space regression (LOGIN-LAYOUT-BUG-01)', () {
    // Production UX report: the logo/title/fields/button were visually
    // packed into the top third of the screen with the rest of the
    // viewport left empty. Root cause was `Center` + `SingleChildScrollView`
    // around a `Column(mainAxisAlignment: center)` — a Column inside a
    // scroll view receives unbounded height, so `mainAxisAlignment.center`
    // silently becomes a no-op and the Column just packs to its intrinsic
    // (top) size, plus `AppScreen`'s own default `scrollable: true` was
    // wrapping the screen in a *second*, redundant scroll view. Fixed via
    // `AppScreen(scrollable: false)` + `LayoutBuilder` +
    // `ConstrainedBox(minHeight: viewport height)`, which lets the form
    // genuinely center when short and still scroll when the keyboard makes
    // it taller than the viewport.
    //
    // This can't be pinned with a golden image in this environment, so it
    // pins the *user-facing consequence* instead: with the form no longer
    // collapsed into the top third, the previously dead space at the
    // bottom of the screen is now part of the actual layout and must be
    // tappable (the screen's tap-outside-to-dismiss-keyboard gesture must
    // reach it).
    testWidgets(
        'tapping the empty space near the bottom of a phone-sized viewport '
        'dismisses the keyboard', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpLogin(tester);
      await tester.pump();

      await tester.tap(find.byType(TextFormField).at(0));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      // Near the bottom edge of the viewport -- before the fix this was
      // unreachable dead space below the top-packed form.
      await tester.tapAt(const Offset(200, 780));
      await tester.pump();

      expect(tester.testTextInput.isVisible, isFalse);
    });
  });

  group('password visibility toggle', () {
    testWidgets('starts obscured and toggles when the suffix icon is tapped',
        (tester) async {
      await pumpLogin(tester);
      await tester.pump();

      final passwordFieldBefore =
          tester.widget<TextField>(find.descendant(
        of: find.byType(TextFormField).at(1),
        matching: find.byType(TextField),
      ));
      expect(passwordFieldBefore.obscureText, isTrue);

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      final passwordFieldAfter =
          tester.widget<TextField>(find.descendant(
        of: find.byType(TextFormField).at(1),
        matching: find.byType(TextField),
      ));
      expect(passwordFieldAfter.obscureText, isFalse);
    });
  });
}
