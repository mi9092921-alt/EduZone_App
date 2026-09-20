import 'dart:async';
import 'dart:io';

import 'package:app/core/error/exceptions.dart';
import 'package:app/core/services/encryption_service.dart';
import 'package:app/features/downloads/application/services/offline_clock_guard.dart';
import 'package:app/features/downloads/application/services/offline_policy_engine.dart';
import 'package:app/features/downloads/data/datasources/download_local_ds.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockDownloadLocalDataSource extends Mock
    implements DownloadLocalDataSource {}

class MockEncryptionService extends Mock implements EncryptionService {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  FakePostgrestFilterBuilder(this._future);
  final Future<T> _future;

  @override
  Future<S> then<S>(
    FutureOr<S> Function(T value) onValue, {
    Function? onError,
  }) {
    return _future.then(onValue, onError: onError);
  }
}

/// Deterministic stand-in for [OfflineClockGuard] so tests don't depend on
/// real secure storage — mirrors the real class's contract (throw =
/// rollback suspected, otherwise succeed) without any I/O.
class FakeClockGuard implements OfflineClockGuard {
  FakeClockGuard({this.shouldThrow = false});
  final bool shouldThrow;
  int callCount = 0;

  @override
  Future<void> checkAndRecord({DateTime? now}) async {
    callCount++;
    if (shouldThrow) {
      throw const ClockRollbackSuspectedException('simulated rollback');
    }
  }

  @override
  Duration get tolerance => const Duration(hours: 6);
}

void main() {
  late MockDownloadLocalDataSource localDataSource;
  late MockEncryptionService encryptionService;
  late MockSupabaseClient mockSupabaseClient;
  late Directory tempDir;
  late String encryptedPath;

  const downloadId = 'dl_1';
  const currentUserId = 'user_current';
  const currentDeviceId = 'device_current';

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(File('dummy'));
  });

  setUp(() async {
    localDataSource = MockDownloadLocalDataSource();
    encryptionService = MockEncryptionService();
    mockSupabaseClient = MockSupabaseClient();
    tempDir = Directory.systemTemp.createTempSync('offline_policy_engine_test');
    encryptedPath = '${tempDir.path}/video.edz';
    File(encryptedPath).writeAsBytesSync([1, 2, 3]);

    when(() => localDataSource.updateDownload(any(), any()))
        .thenAnswer((_) async {});
    when(() => localDataSource.verifyDownloadIntegrity(any()))
        .thenAnswer((_) async => true);
    when(() => encryptionService.calculateChecksum(any()))
        .thenAnswer((_) async => 'valid-checksum');
    when(() => mockSupabaseClient.rpc(
          'revalidate_offline_entitlement',
          params: any(named: 'params'),
        )).thenAnswer((_) => FakePostgrestFilterBuilder(
          Future.value({
            'status': 'ACTIVE',
            'expires_at': DateTime.now()
                .add(const Duration(days: 1))
                .toIso8601String(),
          }),
        ));
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  /// Mirrors the real datasource contract: delegates to the mocked
  /// `revalidate_offline_entitlement` RPC (same stub the suite already
  /// configures in setUp) and pre-classifies failures the way
  /// `DownloadRemoteDataSource.revalidateOfflineEntitlement` does —
  /// transient Postgrest classes and socket/timeout faults become
  /// ServerException(network_error), everything else
  /// ServerException(server_error).
  Future<Map<String, dynamic>> defaultRevalidateFromMock(
      {required String entitlementId}) async {
    try {
      return await mockSupabaseClient
          .rpc(
            'revalidate_offline_entitlement',
            params: {'p_entitlement_id': entitlementId},
          )
          as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      final code = e.code ?? '';
      final transient = code.startsWith('08') ||
          code.startsWith('53') ||
          code == 'PGRST000' ||
          code == 'PGRST001' ||
          code == 'PGRST002' ||
          code == 'PGRST003';
      throw ServerException(
        'Offline entitlement revalidation failed', // check-ignore
        transient ? 'network_error' : 'server_error',
      );
    } catch (e) {
      // Same catch-all shape as the real datasource: raw socket/timeout
      // faults (the mocked RPC throws them directly) classify as
      // network_error → offline fallback in the engine.
      throw ServerException(
        'Offline entitlement revalidation failed', // check-ignore
        e is SocketException || e is TimeoutException
            ? 'network_error'
            : 'server_error',
      );
    }
  }

  OfflinePolicyEngine buildEngine({
    String? userId = currentUserId,
    String device = currentDeviceId,
    OfflineClockGuard? clockGuard,
    Future<Map<String, dynamic>> Function({required String entitlementId})?
        revalidateEntitlement,
  }) {
    return OfflinePolicyEngine(
      localDataSource: localDataSource,
      encryptionService: encryptionService,
      revalidateEntitlement:
          revalidateEntitlement ?? defaultRevalidateFromMock,
      currentUserId: () => userId,
      deviceFingerprint: () => device,
      clockGuard: clockGuard,
    );
  }


  Map<String, dynamic> validRow({
    String status = 'completed',
    int? expiresAt,
    String? userId = currentUserId,
    String? deviceId = currentDeviceId,
    String? path,
    String entitlementId = 'ent_1',
    String serverStatus = 'ACTIVE',
    int? serverExpiresAt,
    String checksum = 'valid-checksum',
  }) {
    return {
      'id': downloadId,
      'download_status': status,
      'expires_at': expiresAt ??
          DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
      'user_id': userId,
      'device_id': deviceId,
      'encrypted_path': path ?? encryptedPath,
      'entitlement_id': entitlementId,
      'server_status': serverStatus,
      'server_expires_at': serverExpiresAt ??
          DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
      'checksum': checksum,
    };
  }

  group('OfflinePolicyEngine.authorize — allow path', () {
    test('allows playback when every invariant is satisfied', () async {
      when(() => localDataSource.getDownloadById(downloadId))
          .thenAnswer((_) async => validRow());
      when(() => encryptionService.retrieveKey(downloadId))
          .thenAnswer((_) async => 'a-key');

      await buildEngine().authorize(downloadId);

      verify(() => localDataSource.getDownloadById(downloadId)).called(1);
    });
  });

  group('OfflinePolicyEngine.authorize — tamper detection (P6.22/P6.23)', () {
    test('denies when the stored signature does not match current fields',
        () async {
      when(() => localDataSource.getDownloadById(downloadId))
          .thenAnswer((_) async => validRow());
      when(() => localDataSource.verifyDownloadIntegrity(downloadId))
          .thenAnswer((_) async => false);

      await expectLater(
        buildEngine().authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.tampered,
          ),
        ),
      );

      // Denied before any decryption is attempted.
      verifyNever(() => encryptionService.retrieveKey(any()));
    });

    test(
      'tamper check wins even when the (untrustworthy) field values would '
      'otherwise look fine',
      () async {
        when(() => localDataSource.getDownloadById(downloadId))
            .thenAnswer((_) async => validRow());
        when(() => localDataSource.verifyDownloadIntegrity(downloadId))
            .thenAnswer((_) async => false);
        when(() => encryptionService.retrieveKey(downloadId))
            .thenAnswer((_) async => 'a-key');

        await expectLater(
          buildEngine().authorize(downloadId),
          throwsA(
            isA<OfflinePlaybackDeniedException>().having(
              (e) => e.reason,
              'reason',
              OfflinePlaybackDenialReason.tampered,
            ),
          ),
        );
      },
    );

    test(
      'tamper check runs before status/expiry/ownership are trusted for a '
      'decision — e.g. a tampered "completed" status does not leak through '
      'as notCompleted instead',
      () async {
        when(() => localDataSource.getDownloadById(downloadId)).thenAnswer(
          (_) async => validRow(
            status: 'downloading',
            userId: 'someone_else',
            expiresAt: DateTime.now()
                .subtract(const Duration(days: 1))
                .millisecondsSinceEpoch,
          ),
        );
        when(() => localDataSource.verifyDownloadIntegrity(downloadId))
            .thenAnswer((_) async => false);

        await expectLater(
          buildEngine().authorize(downloadId),
          throwsA(
            isA<OfflinePlaybackDeniedException>().having(
              (e) => e.reason,
              'reason',
              OfflinePlaybackDenialReason.tampered,
            ),
          ),
        );
      },
    );
  });

  group('OfflinePolicyEngine.authorize — clock rollback (P6.16)', () {
    test('denies playback when a clock rollback is suspected', () async {
      when(() => localDataSource.getDownloadById(downloadId))
          .thenAnswer((_) async => validRow());
      final clockGuard = FakeClockGuard(shouldThrow: true);

      await expectLater(
        buildEngine(clockGuard: clockGuard).authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.clockRollbackSuspected,
          ),
        ),
      );

      expect(clockGuard.callCount, 1);
      // Denied before the key is ever fetched.
      verifyNever(() => encryptionService.retrieveKey(any()));
    });

    test('clock check runs before the expiry check, so a rolled-back clock '
        "can't be used to make an expired download look unexpired",
        () async {
      when(() => localDataSource.getDownloadById(downloadId)).thenAnswer(
        (_) async => validRow(
          expiresAt: DateTime.now()
              .subtract(const Duration(days: 1))
              .millisecondsSinceEpoch,
        ),
      );

      await expectLater(
        buildEngine(clockGuard: FakeClockGuard(shouldThrow: true))
            .authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.clockRollbackSuspected,
          ),
        ),
      );
    });

    test('allows playback when the clock guard reports no rollback',
        () async {
      when(() => localDataSource.getDownloadById(downloadId))
          .thenAnswer((_) async => validRow());
      when(() => encryptionService.retrieveKey(downloadId))
          .thenAnswer((_) async => 'a-key');
      final clockGuard = FakeClockGuard();

      await buildEngine(clockGuard: clockGuard).authorize(downloadId);

      expect(clockGuard.callCount, 1);
    });
  });

  group('OfflinePolicyEngine.authorize — deny paths (P6.41 invariants)', () {
    test('denies when the download is not found', () async {
      when(() => localDataSource.getDownloadById(downloadId))
          .thenAnswer((_) async => null);

      await expectLater(
        buildEngine().authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.downloadNotFound,
          ),
        ),
      );
    });

    test('denies when the download is not completed', () async {
      when(() => localDataSource.getDownloadById(downloadId)).thenAnswer(
        (_) async => validRow(status: 'downloading'),
      );

      await expectLater(
        buildEngine().authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.notCompleted,
          ),
        ),
      );
    });

    test('denies when the license/offline window has expired', () async {
      when(() => localDataSource.getDownloadById(downloadId)).thenAnswer(
        (_) async => validRow(
          expiresAt: DateTime.now()
              .subtract(const Duration(days: 1))
              .millisecondsSinceEpoch,
        ),
      );

      await expectLater(
        buildEngine().authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.expired,
          ),
        ),
      );
    });

    test('denies when the download belongs to a different account', () async {
      when(() => localDataSource.getDownloadById(downloadId)).thenAnswer(
        (_) async => validRow(userId: 'someone_else'),
      );

      await expectLater(
        buildEngine().authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.ownerMismatch,
          ),
        ),
      );
    });

    test('denies when there is no signed-in account but the download is owned',
        () async {
      when(() => localDataSource.getDownloadById(downloadId))
          .thenAnswer((_) async => validRow());

      await expectLater(
        buildEngine(userId: null).authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.ownerMismatch,
          ),
        ),
      );
    });

    test('denies when the download is bound to a different device', () async {
      when(() => localDataSource.getDownloadById(downloadId)).thenAnswer(
        (_) async => validRow(deviceId: 'someone_elses_device'),
      );

      await expectLater(
        buildEngine().authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.deviceMismatch,
          ),
        ),
      );
    });

    test('denies when the encrypted file is missing from disk', () async {
      when(() => localDataSource.getDownloadById(downloadId)).thenAnswer(
        (_) async => validRow(path: '${tempDir.path}/does_not_exist.edz'),
      );

      await expectLater(
        buildEngine().authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.missingFile,
          ),
        ),
      );
    });

    test('denies when the decryption key is missing from secure storage',
        () async {
      when(() => localDataSource.getDownloadById(downloadId))
          .thenAnswer((_) async => validRow());
      when(() => encryptionService.retrieveKey(downloadId))
          .thenAnswer((_) async => null);

      await expectLater(
        buildEngine().authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.missingKey,
          ),
        ),
      );
    });
  });

  group('OfflinePolicyEngine.authorize — entitlement and integrity invariants', () {
    test(
      'denies an unbound legacy row without an active entitlement',
      () async {
        when(() => localDataSource.getDownloadById(downloadId)).thenAnswer(
          (_) async => validRow(
            entitlementId: '',
          ),
        );

        await expectLater(
          buildEngine().authorize(downloadId),
          throwsA(
            isA<OfflinePlaybackDeniedException>().having(
              (e) => e.reason,
              'reason',
              OfflinePlaybackDenialReason.serverRevalidationDenied,
            ),
          ),
        );
      },
    );

    test('denies when entitlement status is revoked on the server', () async {
      when(() => localDataSource.getDownloadById(downloadId)).thenAnswer(
        (_) async => validRow(),
      );
      when(() => mockSupabaseClient.rpc(
            'revalidate_offline_entitlement',
            params: any(named: 'params'),
          )).thenAnswer((_) => FakePostgrestFilterBuilder(
            Future.value({
              'status': 'REVOKED',
              'expires_at': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
            }),
          ));

      await expectLater(
        buildEngine().authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.serverRevalidationDenied,
          ),
        ),
      );
    });

    test('denies when the server content version differs from the local copy',
        () async {
      final row = validRow()..['content_version'] = 'v1';
      when(() => localDataSource.getDownloadById(downloadId))
          .thenAnswer((_) async => row);
      when(() => mockSupabaseClient.rpc(
            'revalidate_offline_entitlement',
            params: any(named: 'params'),
          )).thenAnswer((_) => FakePostgrestFilterBuilder(
            Future.value({
              'status': 'ACTIVE',
              'content_version': 'v2',
              'expires_at': DateTime.now()
                  .add(const Duration(days: 1))
                  .toIso8601String(),
            }),
          ));

      await expectLater(
        buildEngine().authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.serverRevalidationDenied,
          ),
        ),
      );
    });

    test('allows playback when device is offline (SocketException) with valid local cached entitlement', () async {
      when(() => localDataSource.getDownloadById(downloadId))
          .thenAnswer((_) async => validRow());
      when(() => encryptionService.retrieveKey(downloadId))
          .thenAnswer((_) async => 'a-key');
      when(() => mockSupabaseClient.rpc(
            'revalidate_offline_entitlement',
            params: any(named: 'params'),
          )).thenAnswer((_) => FakePostgrestFilterBuilder(
            Future.error(const SocketException('no network')),
          ));

      await buildEngine().authorize(downloadId);
      verify(() => localDataSource.getDownloadById(downloadId)).called(1);
    });

    test('denies when video checksum does not match expected hash', () async {
      when(() => localDataSource.getDownloadById(downloadId))
          .thenAnswer((_) async => validRow(checksum: 'expected-hash'));
      when(() => encryptionService.calculateChecksum(any()))
          .thenAnswer((_) async => 'tampered-hash');

      await expectLater(
        buildEngine().authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.tampered,
          ),
        ),
      );
    });
  });

  test(
    'every denial reason is carried verbatim on the exception '
    '(UI localizes it; debugDetail stays dev-only)',
    () {
      // The user-facing wording moved to the l10n ARB layer
      // (OfflinePlayerErrorView.offlineDenialMessage) — the exception's
      // contract is the machine-readable reason plus a debugDetail that
      // must never be rendered. The localized-copy exhaustiveness is
      // guarded by offline_player_error_view_test.dart.
      for (final reason in OfflinePlaybackDenialReason.values) {
        final exception = OfflinePlaybackDeniedException(
          reason,
          'downloadId=secret-internal-id',
        );
        expect(exception.reason, reason);
        expect(exception.debugDetail, contains('secret-internal-id'));
      }
    },
  );
}
