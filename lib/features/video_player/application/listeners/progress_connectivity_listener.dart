import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/video_provider.dart';
import '../services/lesson_progress_sync_engine.dart';

/// Phase 10 (connectivity): flushes the lesson-progress outbox as soon as
/// the device regains connectivity.
///
/// The sync engine's retry budget stops its timer cadence after repeated
/// failures — correct for a DETERMINISTIC business denial, wrong for a
/// plain offline stretch, where pending progress used to wait until the
/// next user-driven enqueue or the next app session. This listener closes
/// the gap: on the first offline→online transition it calls
/// [LessonProgressSyncEngine.flushOnReconnect] (which resets the budget
/// and flushes).
///
/// Lives in the video_player feature (the progress outbox's owner) and is
/// subscribed eagerly via `lib/app/app_listeners.dart`, like the other
/// event-bus listeners.
final progressConnectivityListenerProvider = Provider<StreamSubscription< // check-ignore: app-lifetime composition-root listener
    List<ConnectivityResult>>>((ref) {
  var wasOffline = false;
  final subscription = Connectivity().onConnectivityChanged.listen((results) {
    final isOffline = results.every((r) => r == ConnectivityResult.none);
    if (!isOffline && wasOffline) {
      final engine = ref.read(lessonProgressSyncEngineProvider);
      unawaited(engine.flushOnReconnect().catchError((Object e) {
        debugPrint('[ProgressConnectivityListener] flush error: $e');
      }));
    }
    wasOffline = isOffline;
  });
  ref.onDispose(subscription.cancel);
  return subscription;
});