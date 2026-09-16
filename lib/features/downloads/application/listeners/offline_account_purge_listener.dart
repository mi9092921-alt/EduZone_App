import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/logging/domain/app_event.dart';
import '../../../../core/logging/logging_providers.dart';
import '../providers/downloads_provider.dart';
import '../services/offline_account_guard.dart';

part 'offline_account_purge_listener.g.dart';

/// Listens for [AuthLoginEvent] and purges local downloads left behind by
/// a *different* account that was previously signed into this device
/// (P6.20 "Account Switching" — see [OfflineAccountGuard]).
///
/// This listener lives in the downloads feature so the guard's dependencies
/// (local data source + encryption service) are resolved from downloads' own
/// DI providers; auth only emits the login event on the [EventBus] and never
/// imports downloads internals. Best-effort, fire-and-forget — must never
/// block or fail login. (Playback of another account's downloads is already
/// independently denied by OfflinePolicyEngine even if this purge is delayed
/// or fails.)
///
/// Eagerly subscribed by `lib/app/app_listeners.dart` at app startup.
@Riverpod(keepAlive: true)
StreamSubscription<void> offlineAccountPurgeListener(Ref ref) {
  final sub = ref.watch(eventBusProvider).stream.listen((event) {
    if (event is! AuthLoginEvent) return;
    unawaited(
      OfflineAccountGuard(
        localDataSource: ref.read(downloadLocalDataSourceProvider),
        encryptionService: ref.read(encryptionServiceProvider),
      ).purgeDownloadsForOtherAccounts(event.userId!).catchError((e) {
        debugPrint(
          '[Downloads] Offline purge failed: ${e.runtimeType}',
        );
        return 0;
      }),
    );
  });
  ref.onDispose(sub.cancel);
  return sub;
}

/// Invalidates the app-wide account-purge listener at a session boundary so
/// its subscription is rebuilt with the next account's provider graph.
void invalidateOfflineAccountPurgeProviders(Ref ref) {
  ref.invalidate(offlineAccountPurgeListenerProvider);
}
