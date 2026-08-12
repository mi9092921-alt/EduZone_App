import 'package:app/core/network/request_cancellation_manager.dart';
import 'package:app/features/auth/application/services/logout_orchestrator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockRequestCancellationManager extends Mock
    implements RequestCancellationManager {}

class MockRpcBuilder extends Mock implements PostgrestFilterBuilder<dynamic> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late MockFlutterSecureStorage mockStorage;
  late MockRequestCancellationManager mockCancellationManager;
  late LogoutOrchestrator orchestrator;

  void stubRpc({bool throws = false}) {
    final builder = MockRpcBuilder();
    when(() => mockClient.rpc('logout_current_user')).thenAnswer((_) => builder);
    when(() => builder.timeout(any())).thenAnswer((_) {
      if (throws) return Future<dynamic>.error(Exception('network error'));
      return Future<dynamic>.value();
    });
  }

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockStorage = MockFlutterSecureStorage();
    mockCancellationManager = MockRequestCancellationManager();

    when(() => mockClient.auth).thenReturn(mockAuth);
    when(() => mockCancellationManager.cancelAll()).thenReturn(null);
    when(() => mockClient.removeAllChannels())
        .thenAnswer((_) async => <String>[]);

    orchestrator = LogoutOrchestrator(
      supabase: mockClient,
      secureStorage: mockStorage,
      cancellationManager: mockCancellationManager,
    );
  });

  group('execute', () {
    test('cancels in-flight requests immediately', () async {
      stubRpc();

      await orchestrator.execute(logoutFlow: 'manual');

      verify(() => mockCancellationManager.cancelAll()).called(1);
    });

    test('returns success when all steps pass', () async {
      stubRpc();

      final result = await orchestrator.execute(logoutFlow: 'manual');

      expect(result.success, isTrue);
      expect(result.failedSteps, isEmpty);
      expect(result.logoutFlow, 'manual');
    });

    test('records server_revocation in failedSteps when RPC throws', () async {
      stubRpc(throws: true);

      final result = await orchestrator.execute(logoutFlow: 'forced');

      expect(result.success, isFalse);
      expect(result.failedSteps, contains('server_revocation'));
    });

    test('records realtime_disconnect when removeAllChannels throws', () async {
      stubRpc();
      when(() => mockClient.removeAllChannels())
          .thenThrow(Exception('realtime error'));

      final result = await orchestrator.execute(logoutFlow: 'manual');

      expect(result.failedSteps, contains('realtime_disconnect'));
    });

    test('toLog() contains required fields', () async {
      stubRpc();

      final result = await orchestrator.execute(logoutFlow: 'manual');
      final log = result.toLog();

      expect(log['event'], 'logout');
      expect(log['flow'], 'manual');
      expect(log.containsKey('duration_ms'), isTrue);
    });
  });

  group('forceLocalCleanup', () {
    test('calls signOut with local scope', () async {
      when(
        () => mockAuth.signOut(),
      ).thenAnswer((_) async {});

      await orchestrator.forceLocalCleanup();

      verify(() => mockAuth.signOut()).called(1);
    });

    test('continues cleanup even if signOut throws', () async {
      when(
        () => mockAuth.signOut(),
      ).thenThrow(Exception('signOut failed'));

      await expectLater(orchestrator.forceLocalCleanup(), completes);
    });
  });
}
