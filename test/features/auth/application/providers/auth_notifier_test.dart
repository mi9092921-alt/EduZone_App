import 'dart:async';

import 'package:app/core/error/exceptions.dart';
import 'package:app/core/logging/domain/app_event.dart';
import 'package:app/core/logging/infrastructure/event_bus.dart';
import 'package:app/core/logging/logging_providers.dart';
import 'package:app/core/services/device_service.dart';
import 'package:app/features/auth/data/datasources/auth_remote_ds.dart';
import 'package:app/features/auth/domain/entities/app_user.dart';
import 'package:app/features/auth/domain/entities/auth_state.dart';
import 'package:app/features/auth/domain/entities/bind_device_result.dart';
import 'package:app/features/auth/domain/entities/user_access.dart';
import 'package:app/features/auth/domain/enums/account_status.dart';
import 'package:app/features/auth/application/providers/auth_provider.dart';
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

    container = ProviderContainer(
      overrides: [
        authRemoteDataSourceProvider.overrideWithValue(mockDataSource),
        supabaseClientProvider.overrideWithValue(mockSupabase),
        deviceServiceProvider.overrideWithValue(mockDevice),
        eventBusProvider.overrideWithValue(mockEventBus),
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