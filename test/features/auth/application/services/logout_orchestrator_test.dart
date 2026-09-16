import 'package:app/core/network/request_cancellation_manager.dart';
import 'package:app/features/auth/application/services/logout_orchestrator.dart';
import 'package:app/features/auth/data/datasources/auth_remote_ds.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockRequestCancellationManager extends Mock
    implements RequestCancellationManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  late MockAuthRemoteDataSource mockDataSource;
  late MockFlutterSecureStorage mockStorage;
  late MockRequestCancellationManager mockCancellationManager;
  late LogoutOrchestrator orchestrator;

  setUp(() {
    mockDataSource = MockAuthRemoteDataSource();
    mockStorage = MockFlutterSecureStorage();
    mockCancellationManager = MockRequestCancellationManager();
    SharedPreferences.setMockInitialValues({});

    when(() => mockDataSource.revokeCurrentSession()).thenAnswer((_) async {});
    when(() => mockDataSource.disconnectRealtime())
        .thenAnswer((_) async => <String>[]);
    when(() => mockDataSource.signOutLocally()).thenAnswer((_) async {});
    when(() => mockCancellationManager.cancelAll()).thenReturn(null);
    when(() => mockStorage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});

    orchestrator = LogoutOrchestrator(
      authRemoteDataSource: mockDataSource,
      secureStorage: mockStorage,
      cancellationManager: mockCancellationManager,
    );
  });

  group('execute', () {
    test('cancels in-flight requests immediately', () async {
      await orchestrator.execute(logoutFlow: 'manual');

      verify(() => mockCancellationManager.cancelAll()).called(1);
    });

    test('returns success when all steps pass', () async {
      final result = await orchestrator.execute(logoutFlow: 'manual');

      expect(result.success, isTrue);
      expect(result.failedSteps, isEmpty);
      expect(result.logoutFlow, 'manual');
    });

    test('records server_revocation in failedSteps when RPC throws', () async {
      when(() => mockDataSource.revokeCurrentSession())
          .thenThrow(Exception('network error'));

      final result = await orchestrator.execute(logoutFlow: 'forced');

      expect(result.success, isFalse);
      expect(result.failedSteps, contains('server_revocation'));
    });

    test('records realtime_disconnect when removeAllChannels throws', () async {
      when(() => mockDataSource.disconnectRealtime())
          .thenThrow(Exception('realtime error'));

      final result = await orchestrator.execute(logoutFlow: 'manual');

      expect(result.failedSteps, contains('realtime_disconnect'));
    });

    test('toLog() contains required fields', () async {
      final result = await orchestrator.execute(logoutFlow: 'manual');
      final log = result.toLog();

      expect(log['event'], 'logout');
      expect(log['flow'], 'manual');
      expect(log.containsKey('duration_ms'), isTrue);
    });
  });

  group('forceLocalCleanup', () {
    test('wipes the actual Supabase access token key after local signOut',
        () async {
      final remainingKeys = <String>{'supabase_access_token'};

      when(() => mockStorage.delete(key: any(named: 'key')))
          .thenAnswer((invocation) async {
        remainingKeys.remove(invocation.namedArguments[#key] as String);
      });

      await orchestrator.forceLocalCleanup();

      expect(remainingKeys, isEmpty);
      verify(() => mockStorage.delete(key: 'supabase_access_token')).called(1);
      verifyNever(() => mockStorage.delete(key: 'access_token'));
      verifyNever(() => mockStorage.delete(key: 'refresh_token'));
      verifyNever(() => mockStorage.delete(key: 'user_id_cache'));
    });

    test('calls signOutLocally (never a full network signOut)', () async {
      await orchestrator.forceLocalCleanup();

      verify(() => mockDataSource.signOutLocally()).called(1);
    });

    test('continues cleanup even if signOutLocally throws', () async {
      when(() => mockDataSource.signOutLocally())
          .thenThrow(Exception('signOut failed'));

      await expectLater(orchestrator.forceLocalCleanup(), completes);
    });
  });
}
