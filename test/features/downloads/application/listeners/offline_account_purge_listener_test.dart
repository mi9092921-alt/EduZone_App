import 'dart:async';
import 'dart:io';

import 'package:app/core/logging/domain/app_event.dart';
import 'package:app/core/logging/infrastructure/event_bus.dart';
import 'package:app/core/logging/logging_providers.dart';
import 'package:app/core/services/encryption_service.dart';
import 'package:app/features/downloads/application/listeners/offline_account_purge_listener.dart';
import 'package:app/features/downloads/application/providers/downloads_provider.dart';
import 'package:app/features/downloads/data/datasources/download_local_ds.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalDataSource extends Mock implements DownloadLocalDataSource {}

class _MockEncryptionService extends Mock implements EncryptionService {}

AuthLoginEvent _loginEvent(String userId) => AuthLoginEvent(
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      userId: userId,
    );

void main() {
  late _MockLocalDataSource localDataSource;
  late _MockEncryptionService encryptionService;
  late EventBus eventBus;
  late ProviderContainer container;

  setUp(() {
    localDataSource = _MockLocalDataSource();
    encryptionService = _MockEncryptionService();
    eventBus = EventBus();
    container = ProviderContainer(
      overrides: [
        eventBusProvider.overrideWith((ref) => eventBus),
        downloadLocalDataSourceProvider.overrideWith((ref) => localDataSource),
        encryptionServiceProvider.overrideWith((ref) => encryptionService),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() {
    eventBus.dispose();
  });

  /// Subscribes the real listener provider (mirroring the eager startup
  /// subscription in app_listeners.dart).
  void subscribe() {
    container.read(offlineAccountPurgeListenerProvider);
  }

  group('OfflineAccountPurgeListener', () {
    test('ignores non-login events entirely', () async {
      subscribe();
      when(() => localDataSource.getDownloadsOwnedByOthers(any()))
          .thenAnswer((_) async => []);

      eventBus.emit(ErrorOccurredEvent(
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        errorMessage: 'boom',
      ));
      await pumpEventQueue();

      verifyNever(() => localDataSource.getDownloadsOwnedByOthers(any()));
    });

    test('skips login events without a userId (nothing safe to purge)',
        () async {
      subscribe();
      when(() => localDataSource.getDownloadsOwnedByOthers(any()))
          .thenAnswer((_) async => []);

      eventBus.emit(AuthLoginEvent(
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      ));
      await pumpEventQueue();

      verifyNever(() => localDataSource.getDownloadsOwnedByOthers(any()));
    });

    test('with no other-account rows, deletes nothing', () async {
      subscribe();
      final gate = Completer<void>();
      when(() => localDataSource.getDownloadsOwnedByOthers('user-a'))
          .thenAnswer((_) async {
        gate.complete();
        return [];
      });

      eventBus.emit(_loginEvent('user-a'));
      await gate.future;
      await pumpEventQueue();

      verify(() => localDataSource.getDownloadsOwnedByOthers('user-a'))
          .called(1);
      verifyNever(() => localDataSource.deleteDownload(any()));
      verifyNever(() => encryptionService.deleteKey(any()));
    });

    test('purges another account\'s files, key, and row', () async {
      final tmp = await Directory.systemTemp.createTemp('purge_test_');
      addTearDown(() => tmp.delete(recursive: true));

      final video = File('${tmp.path}/lesson.bin');
      await video.writeAsBytes([1, 2, 3]);
      await File('${video.path}.tmp').writeAsBytes([4]);
      await File('${video.path}.idx').writeAsBytes([5]);

      subscribe();
      final gate = Completer<void>();
      // deleteDownload runs after the file deletions inside the guard's
      // loop, so completing here deterministically proves the file I/O
      // finished (pumpEventQueue alone does not wait for real file I/O).
      final deleted = Completer<void>();
      when(() => localDataSource.getDownloadsOwnedByOthers('user-b'))
          .thenAnswer((_) async {
        gate.complete();
        return [
          {'id': 'dl-1', 'encrypted_path': video.path, 'audio_path': null},
        ];
      });
      when(() => encryptionService.deleteKey('dl-1'))
          .thenAnswer((_) async {});
      when(() => localDataSource.deleteDownload('dl-1')).thenAnswer((_) async {
        deleted.complete();
      });

      eventBus.emit(_loginEvent('user-b'));
      await gate.future;
      await deleted.future;
      await pumpEventQueue();

      // Files + .tmp + .idx variants must all be gone.
      expect(video.existsSync(), isFalse);
      expect(File('${video.path}.tmp').existsSync(), isFalse);
      expect(File('${video.path}.idx').existsSync(), isFalse);
      verify(() => encryptionService.deleteKey('dl-1')).called(1);
      verify(() => localDataSource.deleteDownload('dl-1')).called(1);
    });

    test('a key deletion failure leaves the row for the next pass',
        () async {
      subscribe();
      final gate = Completer<void>();
      when(() => localDataSource.getDownloadsOwnedByOthers('user-c'))
          .thenAnswer((_) async {
        gate.complete();
        return [
          {'id': 'dl-2', 'encrypted_path': null, 'audio_path': null},
        ];
      });
      when(() => encryptionService.deleteKey('dl-2')).thenThrow(Exception());

      eventBus.emit(_loginEvent('user-c'));
      await gate.future;
      await pumpEventQueue();

      // Deleting the row would orphan the still-present key, so the row
      // must be left for the next purge pass.
      verifyNever(() => localDataSource.deleteDownload(any()));
    });
  });
}
