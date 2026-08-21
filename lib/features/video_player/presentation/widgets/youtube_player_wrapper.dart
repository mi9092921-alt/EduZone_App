import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../../core/network/network_config.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/device_info_helper.dart';
import '../../../../shared/cross_feature/courses_shared.dart';
import '../../../../shared/utils/error_handler.dart';
import '../../application/providers/video_provider.dart';
import 'youtube_player_widget.dart';

class YoutubePlayerWrapper extends ConsumerStatefulWidget {
  final String courseId;
  final String lessonId;
  final bool isFullScreen;
  final bool isVertical;
  final VoidCallback onToggleFullScreen;

  const YoutubePlayerWrapper({
    super.key,
    required this.courseId,
    required this.lessonId,
    required this.isFullScreen,
    required this.isVertical,
    required this.onToggleFullScreen,
  });

  @override
  ConsumerState<YoutubePlayerWrapper> createState() =>
      _YoutubePlayerWrapperState();
}

class _YoutubePlayerWrapperState extends ConsumerState<YoutubePlayerWrapper> {
  YoutubePlayerController? _controller;
  bool _isPlayerReady = false;
  String? _lastVideoId;
  // Guards against scheduling more than one pending post-frame
  // controller-swap callback for the same videoId (e.g. if build() runs
  // again — because of an unrelated provider change — before the
  // previously-scheduled callback has executed).
  String? _pendingVideoId;

  // P8.5/P8.22 fix: YoutubePlayerController's listener fires on every
  // internal position tick (multiple times per second) for the whole
  // playback session, not just once per meaningful change. Without a
  // throttle here, every tick called updateProgress() -> Riverpod state
  // write -> rebuild of video_player_screen.dart (which does
  // `ref.watch(videoProgressProvider(...))` to drive the progress bar),
  // for the entire duration of every lesson watched. Mirrors the same
  // 5-second throttle already used by Player4Wrapper._reportProgress()
  // for the same reason; the debounced DB/network sync inside
  // VideoProgress.updateProgress() is unaffected/unchanged by this.
  DateTime _lastProgressReport = DateTime.fromMillisecondsSinceEpoch(0);

  /// Disposes the previous controller (if any) and creates a new one for
  /// [videoId].
  ///
  /// MUST NOT be called directly from build(): disposing a
  /// `YoutubePlayerController` that a just-returned `CustomYoutubePlayer`
  /// may still be attached to, as a side effect of building, is exactly the
  /// "controller created -> widget rebuilt -> another controller created"
  /// hazard called out in the project's Memory/Resource Safety guidance,
  /// and Section 7 explicitly bans side effects inside build methods. See
  /// call site in [build] — this is only ever invoked from a post-frame
  /// callback, scheduled with a matching `setState` so the framework
  /// finishes the current frame with the old controller before this swaps
  /// it out and triggers a fresh, clean rebuild.
  void _initController(String videoId) {
    _lastVideoId = videoId;
    _controller?.dispose();
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        enableCaption: false,
      ),
    )..addListener(_videoListener);

    _isPlayerReady = false;
  }

  /// Schedules [_initController] for after the current frame instead of
  /// running it inline during build(). Deduplicates against an
  /// already-pending swap for the same [videoId] so a rebuild that happens
  /// to fire again before the callback runs doesn't queue a second one.
  void _scheduleControllerSwap(String videoId) {
    if (_pendingVideoId == videoId) return;
    _pendingVideoId = videoId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pendingVideoId != videoId) return; // superseded meanwhile
      _pendingVideoId = null;
      setState(() => _initController(videoId));
    });
  }

  void _videoListener() {
    if (!mounted || _controller == null || !_controller!.value.isReady) return;

    if (!_isPlayerReady) {
      _isPlayerReady = true;
      _logLessonStarted();
    }

    final now = DateTime.now();
    if (now.difference(_lastProgressReport) < const Duration(seconds: 5)) {
      return;
    }
    _lastProgressReport = now;

    final duration = _controller!.metadata.duration;
    final position = _controller!.value.position;

    if (duration.inSeconds > 0) {
      final pct = (position.inSeconds / duration.inSeconds) * 100;

      ref
          .read(videoProgressProvider(widget.courseId, widget.lessonId).notifier)
          .updateProgress(
            pct,
            position.inSeconds,
            widget.courseId,
            widget.lessonId,
          );
    }
  }

  /// Best-effort analytics ping: failure here must never block or
  /// interrupt playback (see catch block below). Previously had no
  /// timeout, so a stalled connection could leave this hanging
  /// indefinitely despite being written as fire-and-forget. See Section
  /// 13 ("Networking Reliability") of the project instructions.
  Future<void> _logLessonStarted() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await SupabaseService.client.rpc(
        'log_activity_async',
        params: {
          'p_user_id': userId,
          'p_type': 'lesson_started',
          'p_details': {
            'course_id': widget.courseId,
            'lesson_id': widget.lessonId,
            'device_platform': DeviceInfoHelper.platform,
            'player': 'youtube',
          },
        },
      ).timeout(NetworkConfig.telemetryTimeout);
    } catch (_) {
      // Best-effort analytics ping: failure here must never block or
      // interrupt playback, and there is nothing actionable for the user
      // to do about a dropped activity-log call, so it is intentionally
      // swallowed rather than surfaced.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lessonContentAsync = ref.watch(lessonContentProvider(widget.lessonId));

    return lessonContentAsync.when(
      data: (content) {
        final youtubeUrl = content.videoUrl;
        final videoId = (youtubeUrl == null || youtubeUrl.isEmpty)
            ? null
            : YoutubePlayer.convertUrlToId(youtubeUrl);
        if (videoId != null && videoId != _lastVideoId) {
          _scheduleControllerSwap(videoId);
        }

        if (_controller == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return CustomYoutubePlayer(
          controller: _controller!,
          isVertical: widget.isVertical,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(ErrorHandler.getMessage(context, e)),
      ),
    );
  }
}
