import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/datasources/player4_remote_ds.dart';
import '../../data/models/streaming_video_info.dart';

part 'player4_provider.g.dart';

@riverpod
Player4RemoteDataSource player4RemoteDataSource(Ref ref) {
  return Player4RemoteDataSource();
}

class Player4PendingLessonIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setLessonId(String? id) {
    state = id;
  }
}

final player4PendingLessonIdProvider =
    NotifierProvider.autoDispose<Player4PendingLessonIdNotifier, String?>(
  Player4PendingLessonIdNotifier.new,
);

@riverpod
class Player4VideoInfo extends _$Player4VideoInfo {
  Timer? _expiryTimer;

  @override
  Future<StreamingVideoInfo> build(String videoId) async {
    ref.onDispose(() {
      _expiryTimer?.cancel();
    });

    final remoteDataSource = ref.watch(player4RemoteDataSourceProvider);

    // ⚠️ IMPORTANT: keepAlive() MUST be called before any async gap.
    // If called after `await`, Riverpod may have already disposed this provider
    // (e.g. the user navigated away while the network call was in flight),
    // causing UnmountedRefException on `ref.keepAlive()`.
    final link = ref
        .keepAlive(); // check-ignore: content-keyed and self-expiring; not user-scoped

    final lessonId = ref.read(player4PendingLessonIdProvider);
    final info = await remoteDataSource.getVideoInfo(
      videoId,
      lessonId: lessonId,
    );

    // Auto-invalidate when the cached streaming URLs expire.
    if (info.cacheExpiresAt != null) {
      final now = DateTime.now();
      final delay = info.cacheExpiresAt!.difference(now);
      if (delay.isNegative) {
        // Already expired: release the keep-alive so the provider can be GC'd.
        link.close();
      } else {
        _expiryTimer?.cancel();
        _expiryTimer = Timer(delay, () {
          link.close();
          ref.invalidateSelf();
        });
      }
    }

    return info;
  }
}
