import 'dart:async';

import 'package:app/core/error/exceptions.dart';
import 'package:app/core/logging/domain/app_event.dart';
import 'package:app/core/logging/infrastructure/event_bus.dart';
import 'package:app/core/logging/logging_providers.dart';
import 'package:app/core/services/device_service.dart';
import 'package:app/features/auth/application/providers/auth_provider.dart';
import 'package:app/features/auth/application/services/update_service.dart';
import 'package:app/features/auth/data/datasources/auth_remote_ds.dart';
import 'package:app/features/auth/domain/entities/app_user.dart';
import 'package:app/features/auth/domain/entities/auth_state.dart';
import 'package:app/features/auth/domain/entities/bind_device_result.dart';
import 'package:app/features/auth/domain/entities/update_info.dart';
import 'package:app/features/auth/domain/entities/user_access.dart';
import 'package:app/features/auth/domain/enums/account_status.dart';
import 'package:app/features/auth/domain/enums/user_role.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

// ─── Mocks ───────────────────────────────────────────────────────────────────

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockDeviceService extends Mock implements DeviceService {}

class MockEventBus extends Mock implements EventBus {}

class _MockUpdateService extends Mock implements UpdateService {}

class _MockSession extends Mock implements Session {}

class _MockSupabaseUser extends Mock implements User {}

// ─── Helpers ─────────────────────────────────────────────────────────────────

const _tUser = AppUser(
  id: 'user-1',
  email: 'test@example.com',
  firstName: 'Test',
  tenantId: 'tenant-1',
);

const _tActiveAccess = UserAccess(status: AccountStatus.active);
const _tBannedAccess = UserAccess(status: AccountStatus.banned);
const _tLockedAccess = UserAccess(status: AccountStatus.locked);
const _tBindResult = BindDeviceResult(status: BindDeviceStatus.bound);

/// Flushes pending microtasks/timers repeatedly.
///
/// [AuthNotifier.build] fires `Future.microtask(() => _initializeSession())`
/// WITHOUT awaiting it (production code, lib/features/auth/presentation/
/// providers/auth_provider.dart:112). If that call is still pending when a
/// test invokes login()/logout()/verifyAccess(), its eventual
/// `_safeSetState(AuthUnauthenticated())` write can land AFTER the test's
/// own call and silently overwrite the state the test is asserting on —
/// this was the confirmed root cause of the previous
/// "Expected AuthAuthenticated, Actual AuthUnauthenticated" failures.
///
/// This helper drains the event queue so `_initializeSession()` settles
/// into its own (harmless, no-session) AuthUnauthenticated state FIRST,
/// before the test proceeds — so later writes are the true last word.
/// This is a test-only workaround; the underlying unawaited-Future race in
/// production code is a separate, still-open finding (see chat above) that
/// needs an explicit decision before touching lib/.
Future<void> _settleInitialization() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockAuthRemoteDataSource mockDataSource;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockDeviceService mockDevice;
  late MockEventBus mockEventBus;
  late _MockUpdateService mockUpdateService;

  /// Stubs the minimum set of calls that every login() invocation makes.
  void stubSuccessfulLogin() {
    when(() => mockDataSource.login(any(), any()))
        .thenAnswer((_) async => _tUser);
    when(() => mockDataSource.bindDevice(any(), any(), any()))
        .thenAnswer((_) async => _tBindResult);
    when(() => mockDataSource.checkUserAccess())
        .thenAnswer((_) async => _tActiveAccess);
    when(() => mockDataSource.syncUserActivity(
          userId: any(named: 'userId'),
          tenantId: any(named: 'tenantId'),
          deviceFingerprint: any(named: 'deviceFingerprint'),
        )).thenAnswer((_) async {});
    when(() => mockSupabase.channel(any())).thenReturn(
      _FakeRealtimeChannel(),
    );
    when(() => mockSupabase.removeChannel(any()))
        .thenAnswer((_) async => 'ok');
  }

  setUpAll(() {
    registerFallbackValue(
      AuthLoginEvent(timestamp: DateTime(2024), userId: 'u1'),
    );
    registerFallbackValue(_FakeRealtimeChannel());
    registerFallbackValue(Duration.zero);
    registerFallbackValue(SignOutScope.local);

    // ── Platform channel mocks ──────────────────────────────────────────
    // _initializeSession() calls PackageInfo.fromPlatform() as its very
    // first step. Without this, every test throws MissingPluginException
    // there, which (combined with the unawaited-microtask race explained
    // above) is what made login()/logout() results non-deterministic.
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async {
        if (call.method == 'getAll') {
          return {
            'appName': 'EduZone',
            'packageName': 'com.eduzone.app',
            'version': '1.0.0',
            'buildNumber': '1',
            'buildSignature': '',
            'installerStore': null,
          };
        }
        return null;
      },
    );

    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async {
        if (call.method == 'getAll') return <String, dynamic>{};
        return null;
      },
    );

    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '.',
    );
  });

  setUp(() {
    mockDataSource = MockAuthRemoteDataSource();
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockDevice = MockDeviceService();
    mockEventBus = MockEventBus();
    mockUpdateService = _MockUpdateService();

    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockAuth.onAuthStateChange)
        .thenAnswer((_) => const Stream.empty());
    when(() => mockAuth.currentSession).thenReturn(null);
    when(() => mockAuth.currentUser).thenReturn(null);
    when(() => mockAuth.signOut()).thenAnswer((_) async {});
    when(() => mockAuth.signOut(scope: any(named: 'scope')))
        .thenAnswer((_) async {});
    when(() => mockSupabase.channel(any())).thenReturn(_FakeRealtimeChannel());
    when(() => mockSupabase.removeChannel(any()))
        .thenAnswer((_) async => 'ok');
    when(() => mockSupabase.removeAllChannels())
        .thenAnswer((_) async => <String>[]);

    // CheckUserAccessService._check() (started automatically after a
    // successful login/session-restore) calls
    // `await _supabase.rpc('check_user_access')` for its background
    // polling/monitoring check. Without this stub, mocktail cannot return
    // null for this non-nullable-Future-returning method and throws
    // "type 'Null' is not a subtype of type 'PostgrestFilterBuilder<dynamic>'"
    // — this was caught internally by _check()'s own try/catch (hence the
    // "[Security] Check error" log noise) and never affected login()'s
    // result directly, but stubbing it properly removes the noise and
    // exercises the real polling path deterministically.
// ✅ صحيح:
when(() => mockSupabase.rpc('check_user_access')).thenAnswer(
  (_) => _FakeCheckAccessRpcBuilder(const {
    'allowed': true,
    'token_version': null,
  }),
);

    when(() => mockDevice.fingerprint).thenReturn('fp-test');
    when(() => mockDevice.platform).thenReturn('android');
    when(() => mockDevice.deviceInfoJson).thenReturn({'model': 'Test'});

    when(() => mockEventBus.emit(any())).thenReturn(null);
    when(() => mockUpdateService.checkForUpdate(any())).thenAnswer(
      (_) async => const UpdateInfo.upToDate(latestVersion: '1.0.0'),
    );

    container = ProviderContainer(
      overrides: [
        authRemoteDataSourceProvider.overrideWithValue(mockDataSource),
        supabaseClientProvider.overrideWithValue(mockSupabase),
        deviceServiceProvider.overrideWithValue(mockDevice),
        eventBusProvider.overrideWithValue(mockEventBus),
        updateServiceProvider.overrideWithValue(mockUpdateService),
      ],
    );
  });

  tearDown(() => container.dispose());

  // ─── Initial State ────────────────────────────────────────────────────────

  group('initial state', () {
    test('is AuthInitializing before session check completes', () {
      final state = container.read(authProvider);
      expect(state, isA<AuthInitializing>());
    });
  });

  // ─── login() ─────────────────────────────────────────────────────────────

  group('login()', () {
    test('transitions to AuthAuthenticated on success', () async {
      // Read once to trigger build(), then let the unawaited
      // _initializeSession() microtask settle BEFORE calling login() —
      // see _settleInitialization() doc comment for why this matters.
      container.read(authProvider);
      await _settleInitialization();

      stubSuccessfulLogin();

      await container.read(authProvider.notifier).login(
            'test@example.com',
            'password',
          );

      final state = container.read(authProvider);
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).user, _tUser);
    });

    test('transitions through AuthAuthenticating before resolving', () async {
      container.read(authProvider);
      await _settleInitialization();

      stubSuccessfulLogin();

      final states = <AuthState>[];
      container.listen(authProvider, (_, next) => states.add(next));

      await container.read(authProvider.notifier).login(
            'test@example.com',
            'password',
          );

      expect(states.first, isA<AuthAuthenticating>());
      expect(states.last, isA<AuthAuthenticated>());
    });

    test('transitions to AuthRestricted when access is denied', () async {
      container.read(authProvider);
      await _settleInitialization();

      when(() => mockDataSource.login(any(), any()))
          .thenAnswer((_) async => _tUser);
      when(() => mockDataSource.bindDevice(any(), any(), any()))
          .thenAnswer((_) async => _tBindResult);
      when(() => mockDataSource.checkUserAccess())
          .thenAnswer((_) async => _tBannedAccess);
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await container.read(authProvider.notifier).login(
            'test@example.com',
            'password',
          );

      final state = container.read(authProvider);
      expect(state, isA<AuthRestricted>());
      expect(
        (state as AuthRestricted).status,
        AccountStatus.banned,
      );
    });

    test('still transitions to AuthRestricted when locked access sign-out fails', () async {
      container.read(authProvider);
      await _settleInitialization();

      when(() => mockDataSource.login(any(), any()))
          .thenAnswer((_) async => _tUser);
      when(() => mockDataSource.bindDevice(any(), any(), any()))
          .thenAnswer((_) async => _tBindResult);
      when(() => mockDataSource.checkUserAccess())
          .thenAnswer((_) async => _tLockedAccess);
      when(() => mockAuth.signOut()).thenThrow(Exception('sign out failed'));

      await container.read(authProvider.notifier).login(
            'test@example.com',
            'password',
          );

      final state = container.read(authProvider);
      expect(state, isA<AuthRestricted>());
      expect((state as AuthRestricted).status, AccountStatus.locked);
    });

    test('sets error key on InvalidCredentialsException', () async {
      container.read(authProvider);
      await _settleInitialization();

      when(() => mockDataSource.login(any(), any()))
          .thenThrow(const InvalidCredentialsException());
      when(() => mockAuth.currentSession).thenReturn(null);

      await container.read(authProvider.notifier).login(
            'test@example.com',
            'wrong',
          );

      final state = container.read(authProvider);
      expect(state, isA<AuthUnauthenticated>());
      expect((state as AuthUnauthenticated).error, 'errorAuth');
    });

    test('sets error key on MaxDevicesReachedException', () async {
      container.read(authProvider);
      await _settleInitialization();

      when(() => mockDataSource.login(any(), any()))
          .thenAnswer((_) async => _tUser);
      when(() => mockDataSource.bindDevice(any(), any(), any()))
          .thenThrow(const MaxDevicesReachedException());
      when(() => mockAuth.currentSession).thenReturn(null);

      await container.read(authProvider.notifier).login(
            'test@example.com',
            'password',
          );

      final state = container.read(authProvider);
      expect(state, isA<AuthUnauthenticated>());
      expect((state as AuthUnauthenticated).error, 'errorMaxDevices');
    });

    test('sets errorGeneric for unexpected exceptions', () async {
      container.read(authProvider);
      await _settleInitialization();

      when(() => mockDataSource.login(any(), any()))
          .thenThrow(Exception('unexpected'));
      when(() => mockAuth.currentSession).thenReturn(null);

      await container.read(authProvider.notifier).login(
            'test@example.com',
            'password',
          );

      final state = container.read(authProvider);
      expect((state as AuthUnauthenticated).error, 'errorGeneric');
    });
  });

  // ─── logout() ────────────────────────────────────────────────────────────

  group('logout()', () {
    Future<void> putInAuthenticatedState() async {
      container.read(authProvider);
      await _settleInitialization();

      stubSuccessfulLogin();
      await container.read(authProvider.notifier).login(
            'test@example.com',
            'password',
          );
    }

    test('transitions to AuthUnauthenticated after logout', () async {
      await putInAuthenticatedState();

      when(() => mockAuth.signOut()).thenAnswer((_) async {});
      when(() => mockSupabase.removeAllChannels())
          .thenAnswer((_) async => <String>[]);

      final rpcBuilder = _MockRpcBuilder();
      when(() => mockSupabase.rpc('logout_current_user'))
          .thenAnswer((_) => rpcBuilder);
      when(() => rpcBuilder.timeout(any()))
          .thenAnswer((_) async => null);

      await container.read(authProvider.notifier).logout();

      expect(container.read(authProvider), isA<AuthUnauthenticated>());
    });

    test('is idempotent — second call is a no-op', () async {
      await putInAuthenticatedState();

      when(() => mockAuth.signOut()).thenAnswer((_) async {});
      when(() => mockSupabase.removeAllChannels())
          .thenAnswer((_) async => <String>[]);
      final rpcBuilder = _MockRpcBuilder();
      when(() => mockSupabase.rpc('logout_current_user'))
          .thenAnswer((_) => rpcBuilder);
      when(() => rpcBuilder.timeout(any())).thenAnswer((_) async => null);

      await container.read(authProvider.notifier).logout();
      // Second call — state is already AuthUnauthenticated, guarded no-op
      // at the top of logout() (lib/.../auth_provider.dart:541).
      await container.read(authProvider.notifier).logout();

      // forceLocalCleanup() calls the BARE signOut() — not
      // signOut(scope: ...) — see logout_orchestrator.dart:120. The
      // previous verify() checked the wrong overload and could never
      // match, regardless of how many times signOut() was really called.
      verify(() => mockAuth.signOut()).called(1);
    });
  });

  // ─── verifyAccess() ──────────────────────────────────────────────────────

  group('verifyAccess()', () {
    test('transitions to AuthAuthenticated when access is allowed', () async {
      container.read(authProvider);
      await _settleInitialization();

      when(() => mockDataSource.checkUserAccess())
          .thenAnswer((_) async => _tActiveAccess);
      when(() => mockDataSource.getCurrentUser())
          .thenAnswer((_) async => _tUser);
      when(() => mockSupabase.channel(any()))
          .thenReturn(_FakeRealtimeChannel());
      when(() => mockSupabase.removeChannel(any()))
          .thenAnswer((_) async => 'ok');

      await container.read(authProvider.notifier).verifyAccess();

      expect(container.read(authProvider), isA<AuthAuthenticated>());
    });

    test('transitions to AuthRestricted when access is denied', () async {
      container.read(authProvider);
      await _settleInitialization();

      when(() => mockDataSource.checkUserAccess())
          .thenAnswer((_) async => _tBannedAccess);

      await container.read(authProvider.notifier).verifyAccess();

      final state = container.read(authProvider);
      expect(state, isA<AuthRestricted>());
      expect((state as AuthRestricted).status, AccountStatus.banned);
    });

    test('stays in current state on network error', () async {
      container.read(authProvider);
      await _settleInitialization();

      when(() => mockDataSource.checkUserAccess())
          .thenThrow(const NoInternetException());

      final stateBefore = container.read(authProvider);
      await container.read(authProvider.notifier).verifyAccess();

      expect(container.read(authProvider), stateBefore);
    });
  });

  // ─── handleAccessDenied() ────────────────────────────────────────────────

  group('handleAccessDenied()', () {
    test('triggers logout and emits event', () async {
      container.read(authProvider);
      await _settleInitialization();

      stubSuccessfulLogin();
      await container.read(authProvider.notifier).login(
            'test@example.com',
            'password',
          );

      when(() => mockAuth.signOut()).thenAnswer((_) async {});
      when(() => mockSupabase.removeAllChannels())
          .thenAnswer((_) async => <String>[]);
      final rpcBuilder = _MockRpcBuilder();
      when(() => mockSupabase.rpc('logout_current_user'))
          .thenAnswer((_) => rpcBuilder);
      when(() => rpcBuilder.timeout(any())).thenAnswer((_) async => null);

      container
          .read(authProvider.notifier)
          .handleAccessDenied(reason: 'account_banned');

      await Future.delayed(const Duration(milliseconds: 50));

      expect(container.read(authProvider), isA<AuthUnauthenticated>());
      verify(() => mockEventBus.emit(any())).called(greaterThan(0));
    });
  });

  // ─── handleAccessRestricted() ────────────────────────────────────────────

  group('handleAccessRestricted()', () {
    test('sets AuthRestricted without forcing a logout', () async {
      container.read(authProvider);
      await _settleInitialization();

      stubSuccessfulLogin();
      await container.read(authProvider.notifier).login(
            'test@example.com',
            'password',
          );
      expect(container.read(authProvider), isA<AuthAuthenticated>());

      const access = UserAccess(status: AccountStatus.maintenance);
      container
          .read(authProvider.notifier)
          .handleAccessRestricted(access: access);

      final state = container.read(authProvider);
      expect(state, isA<AuthRestricted>());
      expect((state as AuthRestricted).status, AccountStatus.maintenance);

      // Unlike handleAccessDenied(), a restriction (maintenance/app_locked)
      // must NOT trigger the logout transaction — removeAllChannels() is
      // only ever called from LogoutOrchestrator.execute().
      verifyNever(() => mockSupabase.removeAllChannels());
    });
  });

  // ─── refreshUser() ───────────────────────────────────────────────────────

  group('refreshUser()', () {
    test('replaces the user in AuthAuthenticated with the fresh copy',
        () async {
      container.read(authProvider);
      await _settleInitialization();

      stubSuccessfulLogin();
      await container.read(authProvider.notifier).login(
            'test@example.com',
            'password',
          );

      const updatedUser = AppUser(
        id: 'user-1',
        email: 'test@example.com',
        firstName: 'Updated',
        tenantId: 'tenant-1',
      );
      when(() => mockDataSource.getCurrentUser())
          .thenAnswer((_) async => updatedUser);

      await container.read(authProvider.notifier).refreshUser();

      final state = container.read(authProvider) as AuthAuthenticated;
      expect(state.user.firstName, 'Updated');
      // access must be preserved from the prior state, not reset.
      expect(state.access, _tActiveAccess);
    });

    test('is a no-op when not currently authenticated', () async {
      container.read(authProvider);
      await _settleInitialization();

      when(() => mockDataSource.getCurrentUser())
          .thenAnswer((_) async => _tUser);

      final stateBefore = container.read(authProvider);
      await container.read(authProvider.notifier).refreshUser();

      expect(container.read(authProvider), stateBefore);
    });
  });

  // ─── login(): role gating ────────────────────────────────────────────────

  group('login(): role gating', () {
    test('blocks a non-student user and signs them out locally', () async {
      container.read(authProvider);
      await _settleInitialization();

      const teacherUser = AppUser(
        id: 'user-2',
        email: 'teacher@example.com',
        primaryRole: UserRole.teacher,
        tenantId: 'tenant-1',
      );

      when(() => mockDataSource.login(any(), any()))
          .thenAnswer((_) async => teacherUser);
      when(() => mockDataSource.bindDevice(any(), any(), any()))
          .thenAnswer((_) async => _tBindResult);
      when(() => mockDataSource.checkUserAccess())
          .thenAnswer((_) async => _tActiveAccess);

      await container.read(authProvider.notifier).login(
            'teacher@example.com',
            'password',
          );

      final state = container.read(authProvider);
      expect(state, isA<AuthUnauthenticated>());
      expect(
        (state as AuthUnauthenticated).error,
        'errorAuth',
        reason: 'a non-student role must be rejected client-side with the '
            'same generic auth error as bad credentials — never a '
            'role-revealing message',
      );
    });
  });

  // ─── _initializeSession(): device re-bind on cold start ──────────────────
  //
  // Covers the branch in _initializeSession() (auth_provider.dart) that
  // handles a session whose device fingerprint is no longer registered —
  // e.g. the backing `devices` row was deleted/deactivated out of band.
  // Previously untested: only the happy path (device already valid) was
  // covered indirectly by other tests.

  group('_initializeSession(): device re-bind on cold start', () {
    void stubValidSession() {
      final mockSession = _MockSession();
      final mockUser = _MockSupabaseUser();
      when(() => mockUser.id).thenReturn('user-1');
      when(() => mockSession.user).thenReturn(mockUser);
      when(() => mockAuth.currentSession).thenReturn(mockSession);
    }

    // Root cause of the previous "Expected AuthAuthenticated, Actual
    // AuthUnauthenticated" failure here: _initializeSession()'s Step 1
    // does `ref.read(updateServiceProvider)`, which (when left
    // un-overridden, as the shared `container` from setUp() leaves it)
    // constructs a *real* UpdateRemoteDataSource() — whose constructor
    // touches SupabaseService.client / Supabase.instance immediately.
    // That's never initialized in this test binary, so it throws, and
    // _initializeSession()'s outer catch short-circuits straight to
    // AuthUnauthenticated BEFORE the device-validation/re-bind branch
    // below ever runs — regardless of how mockDataSource is stubbed.
    //
    // The sibling "re-bind fails" test below happened to still pass
    // with the bug present, because AuthUnauthenticated is also its
    // expected outcome — but for the wrong reason, without actually
    // exercising the re-bind-failure branch either.
    //
    // Fix: give this group its own container with updateServiceProvider
    // stubbed to resolve immediately with an upToDate status, exactly
    // like the 'session race' group below already does. This lets
    // _initializeSession() proceed past Step 1 into the real
    // device-validation/re-bind logic under test.
    ProviderContainer buildRebindContainer() {
      final mockUpdateService = _MockUpdateService();
      when(() => mockUpdateService.checkForUpdate(any())).thenAnswer(
        (_) async => const UpdateInfo.upToDate(latestVersion: '1.0.0'),
      );

      final rebindContainer = ProviderContainer(
        overrides: [
          authRemoteDataSourceProvider.overrideWithValue(mockDataSource),
          supabaseClientProvider.overrideWithValue(mockSupabase),
          deviceServiceProvider.overrideWithValue(mockDevice),
          eventBusProvider.overrideWithValue(mockEventBus),
          updateServiceProvider.overrideWithValue(mockUpdateService),
        ],
      );
      addTearDown(rebindContainer.dispose);
      return rebindContainer;
    }

    test(
        're-binds and resumes the session when the device is missing but '
        're-bind succeeds', () async {
      stubValidSession();
      when(() => mockDataSource.validateDeviceExists(any(), any()))
          .thenAnswer((_) async => false);
      when(() => mockDataSource.bindDevice(any(), any(), any()))
          .thenAnswer((_) async => _tBindResult);
      when(() => mockDataSource.checkUserAccess())
          .thenAnswer((_) async => _tActiveAccess);
      when(() => mockDataSource.getCurrentUser())
          .thenAnswer((_) async => _tUser);
      when(() => mockDataSource.syncUserActivity(
            userId: any(named: 'userId'),
            tenantId: any(named: 'tenantId'),
            deviceFingerprint: any(named: 'deviceFingerprint'),
          )).thenAnswer((_) async {});

      final rebindContainer = buildRebindContainer();
      rebindContainer.read(authProvider);
      await _settleInitialization();

      expect(rebindContainer.read(authProvider), isA<AuthAuthenticated>());
    });

    test(
        'forces a full local logout when the device is missing AND '
        're-bind fails (e.g. MAX_DEVICES_REACHED)', () async {
      stubValidSession();
      when(() => mockDataSource.validateDeviceExists(any(), any()))
          .thenAnswer((_) async => false);
      when(() => mockDataSource.bindDevice(any(), any(), any()))
          .thenThrow(const MaxDevicesReachedException());

      final rebindContainer = buildRebindContainer();
      rebindContainer.read(authProvider);
      await _settleInitialization();

      expect(
        rebindContainer.read(authProvider),
        isA<AuthUnauthenticated>(),
        reason: 'a device that cannot be (re-)bound must never be left in '
            'an authenticated state — this is the security-critical branch '
            'in _initializeSession() (auth_provider.dart)',
      );
    });
  });

  // ─── _initializeSession(): transient error with an existing session ──────
  //
  // EduZone_Authentication_Session_Security_Architecture.md, Phase 18:
  // "if session != null and a network timeout occurs: do NOT clear the
  // session, do NOT sign out, do NOT auto-navigate to login — retain the
  // session and retry verification." Before this fix, ANY transient error
  // hit during _initializeSession() (regardless of whether a local
  // session existed) fell through to AuthUnauthenticated, which the
  // Router maps straight to /login — silently discarding a valid session
  // because of a network blip.

  group('_initializeSession(): transient error with an existing session', () {
    void stubValidSession() {
      final mockSession = _MockSession();
      final mockUser = _MockSupabaseUser();
      when(() => mockUser.id).thenReturn('user-1');
      when(() => mockSession.user).thenReturn(mockUser);
      when(() => mockAuth.currentSession).thenReturn(mockSession);
    }

    ProviderContainer buildDegradedContainer() {
      final mockUpdateService = _MockUpdateService();
      when(() => mockUpdateService.checkForUpdate(any())).thenAnswer(
        (_) async => const UpdateInfo.upToDate(latestVersion: '1.0.0'),
      );

      final degradedContainer = ProviderContainer(
        overrides: [
          authRemoteDataSourceProvider.overrideWithValue(mockDataSource),
          supabaseClientProvider.overrideWithValue(mockSupabase),
          deviceServiceProvider.overrideWithValue(mockDevice),
          eventBusProvider.overrideWithValue(mockEventBus),
          updateServiceProvider.overrideWithValue(mockUpdateService),
        ],
      );
      addTearDown(degradedContainer.dispose);
      return degradedContainer;
    }

    test(
        'transitions to AuthDegraded (not AuthUnauthenticated) and never '
        'signs out when a transient error occurs with a local session',
        () async {
      stubValidSession();
      when(() => mockDataSource.validateDeviceExists(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockDataSource.checkUserAccess())
          .thenThrow(const NoInternetException());

      final degradedContainer = buildDegradedContainer();
      degradedContainer.read(authProvider);
      await _settleInitialization();

      final state = degradedContainer.read(authProvider);
      expect(
        state,
        isA<AuthDegraded>(),
        reason: 'a transient error must never be treated as an explicit '
            'denial when a local session exists',
      );
      expect(state, isNot(isA<AuthUnauthenticated>()));

      verifyNever(() => mockAuth.signOut());
      verifyNever(() => mockAuth.signOut(scope: any(named: 'scope')));
    });

    test(
        'still resolves to AuthUnauthenticated(error:) on a transient '
        'error when there is no local session to protect', () async {
      when(() => mockAuth.currentSession).thenReturn(null);

      final mockUpdateService = _MockUpdateService();
      when(() => mockUpdateService.checkForUpdate(any()))
          .thenThrow(const NoInternetException());

      final noSessionContainer = ProviderContainer(
        overrides: [
          authRemoteDataSourceProvider.overrideWithValue(mockDataSource),
          supabaseClientProvider.overrideWithValue(mockSupabase),
          deviceServiceProvider.overrideWithValue(mockDevice),
          eventBusProvider.overrideWithValue(mockEventBus),
          updateServiceProvider.overrideWithValue(mockUpdateService),
        ],
      );
      addTearDown(noSessionContainer.dispose);

      noSessionContainer.read(authProvider);
      await _settleInitialization();

      final state = noSessionContainer.read(authProvider);
      expect(
        state,
        isA<AuthUnauthenticated>(),
        reason: 'with no local session there is nothing to protect — the '
            'pre-existing "show a mapped network error on /login" '
            'behaviour must be unchanged',
      );
    });

    test(
        'retryDegradedSession() re-runs verification and reaches '
        'AuthAuthenticated once the server becomes reachable again — '
        'proving the post-AuthDegraded write is not silently dropped',
        () async {
      stubValidSession();
      when(() => mockDataSource.validateDeviceExists(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockDataSource.checkUserAccess())
          .thenThrow(const NoInternetException());

      final degradedContainer = buildDegradedContainer();
      degradedContainer.read(authProvider);
      await _settleInitialization();

      expect(degradedContainer.read(authProvider), isA<AuthDegraded>());

      // Server becomes reachable again.
      when(() => mockDataSource.checkUserAccess())
          .thenAnswer((_) async => _tActiveAccess);
      when(() => mockDataSource.getCurrentUser())
          .thenAnswer((_) async => _tUser);
      when(() => mockDataSource.syncUserActivity(
            userId: any(named: 'userId'),
            tenantId: any(named: 'tenantId'),
            deviceFingerprint: any(named: 'deviceFingerprint'),
          )).thenAnswer((_) async {});

      await degradedContainer.read(authProvider.notifier).retryDegradedSession();

      final state = degradedContainer.read(authProvider);
      expect(
        state,
        isA<AuthAuthenticated>(),
        reason: 'this only passes if writes made after entering '
            'AuthDegraded are not dropped by the AuthInitializing-only '
            'guard that used to gate _initializeSession()\'s state writes',
      );
    });

    test('retryDegradedSession() is a no-op outside AuthDegraded', () async {
      container.read(authProvider);
      await _settleInitialization();

      final before = container.read(authProvider);
      expect(before, isA<AuthUnauthenticated>());

      await container.read(authProvider.notifier).retryDegradedSession();

      expect(container.read(authProvider), before);
    });
  });

  // ─── concurrency: overlapping login() calls ───────────────────────────────
  //
  // There is no app-level single-flight coordination for login() (unlike
  // the security doc's "Refresh Race Protection" phase, which applies to
  // *token refresh* — handled internally by the supabase_flutter/gotrue
  // SDK, not by application code). This test does not assert single-flight
  // behaviour (there is none to assert); it only pins down that two
  // overlapping calls converge to one consistent, non-corrupted state
  // instead of crashing or leaving a torn state.

  group('concurrency: overlapping login() calls', () {
    test('two overlapping login() calls converge to one consistent state',
        () async {
      container.read(authProvider);
      await _settleInitialization();
      stubSuccessfulLogin();

      final notifier = container.read(authProvider.notifier);
      final f1 = notifier.login('test@example.com', 'password');
      final f2 = notifier.login('test@example.com', 'password');

      await Future.wait([f1, f2]);

      final state = container.read(authProvider);
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).user, _tUser);
    });
  });

  // ─── session race: logout() during in-flight _initializeSession() ────────
  //
  // Regression test for the race documented in _settleInitialization()'s
  // doc comment above this file's `main()`: _initializeSession() is fired
  // unawaited from build(). If logout() is called while it is still in
  // flight, and _initializeSession() later resolves to AuthAuthenticated,
  // that stale write must NOT overwrite the logout. This directly
  // exercises the `_safeSetStateIfStillInitializing` guard in
  // lib/features/auth/application/providers/auth_provider.dart, which
  // implements the architecture doc's "logout always wins over late auth
  // response" invariant (see MERHALA 32 / concurrency tests).
  //
  // Uses its own ProviderContainer (rather than the shared `container`
  // from setUp) so updateServiceProvider can be overridden with a gate
  // that lets this test control exactly when _initializeSession() resumes.

  group('session race: logout() during in-flight _initializeSession()', () {
    test(
        'logout() wins over a slow _initializeSession() that would '
        'otherwise resolve to AuthAuthenticated', () async {
      final updateGate = Completer<UpdateInfo>();
      final mockUpdateService = _MockUpdateService();
      when(() => mockUpdateService.checkForUpdate(any()))
          .thenAnswer((_) => updateGate.future);

      final mockSession = _MockSession();
      final mockUser = _MockSupabaseUser();
      when(() => mockUser.id).thenReturn('user-1');
      when(() => mockSession.user).thenReturn(mockUser);
      when(() => mockAuth.currentSession).thenReturn(mockSession);

      when(() => mockDataSource.validateDeviceExists(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockDataSource.checkUserAccess())
          .thenAnswer((_) async => _tActiveAccess);
      when(() => mockDataSource.getCurrentUser())
          .thenAnswer((_) async => _tUser);
      when(() => mockDataSource.syncUserActivity(
            userId: any(named: 'userId'),
            tenantId: any(named: 'tenantId'),
            deviceFingerprint: any(named: 'deviceFingerprint'),
          )).thenAnswer((_) async {});

      final raceContainer = ProviderContainer(
        overrides: [
          authRemoteDataSourceProvider.overrideWithValue(mockDataSource),
          supabaseClientProvider.overrideWithValue(mockSupabase),
          deviceServiceProvider.overrideWithValue(mockDevice),
          eventBusProvider.overrideWithValue(mockEventBus),
          updateServiceProvider.overrideWithValue(mockUpdateService),
        ],
      );
      addTearDown(raceContainer.dispose);

      // build() fires the unawaited _initializeSession(), which is now
      // permanently blocked on updateGate.future until we complete it
      // below — state stays AuthInitializing until then.
      raceContainer.read(authProvider);
      expect(raceContainer.read(authProvider), isA<AuthInitializing>());

      final rpcBuilder = _MockRpcBuilder();
      when(() => mockSupabase.rpc('logout_current_user'))
          .thenAnswer((_) => rpcBuilder);
      when(() => rpcBuilder.timeout(any())).thenAnswer((_) async => null);

      // logout()'s only re-entrancy guard is
      // `state is AuthLoggingOut || state is AuthUnauthenticated`; the
      // current state is AuthInitializing, so this is a legitimate call
      // (e.g. the user backs out, or a deep link forces sign-out, during a
      // slow cold start).
      await raceContainer.read(authProvider.notifier).logout();
      expect(raceContainer.read(authProvider), isA<AuthUnauthenticated>());

      // Now let the stale _initializeSession() resume and run to
      // completion. Without the `state is AuthInitializing` guard inside
      // _safeSetStateIfStillInitializing, it would overwrite the state
      // above with AuthAuthenticated once it finishes.
      updateGate.complete(const UpdateInfo.upToDate(latestVersion: '1.0.0'));
      await _settleInitialization();

      expect(
        raceContainer.read(authProvider),
        isA<AuthUnauthenticated>(),
        reason: 'a stale _initializeSession() result must never overwrite '
            'an explicit logout() that happened while it was in flight',
      );
    });
  });

  // ─── _initializeSession(): transient getCurrentUser() failure ────────────
  //
  // Regression test for auth_remote_ds.dart's getCurrentUser(): it used to
  // swallow EVERY exception (including transient network/server failures)
  // into a bare `null`, which _initializeSession() then treated exactly
  // like "no such user" — forcing AuthUnauthenticated(error: null) with no
  // retry/error signal, and completely bypassing AuthErrorPolicy.isTransient()
  // for this code path. A valid session hitting a momentary network blip
  // during cold start was silently dropped to a bare, unexplained login
  // screen instead of being classified transient.
  //
  // getCurrentUser() now propagates (mapped to ServerException for
  // PostgrestException, matching checkUserAccess()'s existing convention
  // in the same file) so AuthErrorPolicy actually gets a chance to run.
  // This test pins the resulting OBSERVABLE contract at the notifier level
  // — AuthUnauthenticated.error must be non-null for a transiently-classified
  // failure — rather than mocking Supabase's raw query-builder chain, which
  // has no working precedent anywhere in this test suite.
  group('_initializeSession(): transient getCurrentUser() failure', () {
    test(
        'attaches an error key instead of silently landing on a bare '
        'AuthUnauthenticated when getCurrentUser() fails with a transient '
        'error after device/access checks already succeeded', () async {
      final mockSession = _MockSession();
      final mockUser = _MockSupabaseUser();
      when(() => mockUser.id).thenReturn('user-1');
      when(() => mockSession.user).thenReturn(mockUser);
      when(() => mockAuth.currentSession).thenReturn(mockSession);

      when(() => mockDataSource.validateDeviceExists(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockDataSource.checkUserAccess())
          .thenAnswer((_) async => _tActiveAccess);
      // Simulates the network/server failure that getCurrentUser() used to
      // swallow into `null` — see auth_remote_ds.dart getCurrentUser().
      when(() => mockDataSource.getCurrentUser())
          .thenThrow(const ServerException('Request timeout'));

      final mockUpdateService = _MockUpdateService();
      when(() => mockUpdateService.checkForUpdate(any())).thenAnswer(
        (_) async => const UpdateInfo.upToDate(latestVersion: '1.0.0'),
      );

      final container2 = ProviderContainer(
        overrides: [
          authRemoteDataSourceProvider.overrideWithValue(mockDataSource),
          supabaseClientProvider.overrideWithValue(mockSupabase),
          deviceServiceProvider.overrideWithValue(mockDevice),
          eventBusProvider.overrideWithValue(mockEventBus),
          updateServiceProvider.overrideWithValue(mockUpdateService),
        ],
      );
      addTearDown(container2.dispose);

      container2.read(authProvider);
      await _settleInitialization();

      // NOTE: as of the AuthDegraded state (see auth_state.dart /
      // _scheduleDegradedRetry() in auth_provider.dart), a transient
      // failure with a still-present local session no longer lands on
      // AuthUnauthenticated at all -- it correctly lands on AuthDegraded
      // with a capped, auto-retrying backoff, per
      // EduZone_Authentication_Session_Security_Architecture.md Phase 18
      // ("transient network error must never directly cause logout").
      // This is a strictly better outcome than what this test originally
      // asserted (AuthUnauthenticated with a non-null error) -- the
      // original bug (getCurrentUser() swallowing the exception into a
      // silent `null`, bypassing AuthErrorPolicy entirely) is still what
      // this test guards against; only the now-current expected state
      // changed.
      final state = container2.read(authProvider);
      expect(state, isA<AuthDegraded>());
      final degraded = state as AuthDegraded;
      expect(
        degraded.error,
        isNotNull,
        reason: 'a transient getCurrentUser() failure must be classified '
            'by AuthErrorPolicy.isTransient() and reach _scheduleDegradedRetry() '
            'with a non-null error key -- a null error here would mean the '
            'exception was swallowed before reaching the classifier (the '
            'pre-fix bug in auth_remote_ds.dart getCurrentUser())',
      );
      expect(
        degraded.retryAttempt,
        greaterThan(0),
        reason: 'the first entry into AuthDegraded must schedule (and '
            'count) a retry attempt, not just describe an error',
      );
    });
  });
}

// ─── Private test doubles ─────────────────────────────────────────────────────

class _FakeRealtimeChannel extends Fake implements RealtimeChannel {
  @override
  RealtimeChannel onPostgresChanges({
    required PostgresChangeEvent event,
    String? schema,
    String? table,
    PostgresChangeFilter? filter,
    required void Function(PostgresChangePayload payload) callback,
  }) =>
      this;

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus status, Object? error)? callback,
    Duration? timeout,
  ]) =>
      this;
}

class _MockRpcBuilder extends Mock
    implements PostgrestFilterBuilder<dynamic> {}

/// Makes `await supabase.rpc('check_user_access')` resolve to a fixed
/// map, so [CheckUserAccessService._check] (started automatically after
/// login/session-restore) behaves deterministically instead of throwing.
class _FakeCheckAccessRpcBuilder extends Fake
    implements PostgrestFilterBuilder<dynamic> {
  _FakeCheckAccessRpcBuilder(this._value);

  final Map<String, dynamic> _value;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(dynamic value) onValue, {
    Function? onError,
  }) {
    return Future<dynamic>.value(_value).then(onValue, onError: onError);
  }
}
