import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../../core/feature_flags/feature_flag_keys.dart';
import '../../../../core/feature_flags/feature_flags_provider.dart';
import '../../../../core/logging/data/log_remote_ds.dart';
import '../../../../core/utils/device_info_helper.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/models/lesson_content.dart';
import '../../../../shared/utils/player_ui_helpers.dart';
import '../../../../shared/widgets/content_watermark.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../application/providers/video_provider.dart';
import 'youtube_player_widget.dart';

class YoutubePlayerWrapper extends ConsumerStatefulWidget {
  final String courseId;
  final String lessonId;

  /// Resolved lesson content, passed down by the route builder in
  /// `app_router.dart` (which watches the courses provider) so this widget
  /// does not import courses feature internals.
  final LessonContent lessonContent;
  final bool isFullScreen;
  final bool isVertical;
  final VoidCallback onToggleFullScreen;

  const YoutubePlayerWrapper({
    super.key,
    required this.courseId,
    required this.lessonId,
    required this.lessonContent,
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
  final _activityLogger = LogRemoteDataSource();
  bool _isPlayerReady = false;
  PlayerState? _lastCaptionSuppressionState;
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
  final PlayerProgressReporter _progressReporter = PlayerProgressReporter();

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
        // Keep the final rendered frame visible when playback ends. The
        // package otherwise fades its thumbnail over the video at the ended
        // state. loop remains false so playback never restarts automatically.
        hideThumbnail: true,
        forceHD: true,
        // Captions are intentionally disabled for this player.
        enableCaption: false,
      ),
    )..addListener(_videoListener);

    _isPlayerReady = false;
    _lastCaptionSuppressionState = null;
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
      _disableYoutubeCaptions();
      _lastCaptionSuppressionState = _controller!.value.playerState;
      _logLessonStarted();
    } else {
      // YouTube can restore the caption module after a state transition
      // (for example when buffering or resuming). Re-apply the suppression
      // only when the state changes; never poll the WebView on every tick.
      final playerState = _controller!.value.playerState;
      if (playerState != _lastCaptionSuppressionState) {
        _lastCaptionSuppressionState = playerState;
        _disableYoutubeCaptions();
      }
    }

    if (!_progressReporter.shouldReport(_controller!.value.position)) return;

    final duration = _controller!.metadata.duration;
    final position = _controller!.value.position;

    if (duration.inSeconds > 0) {
      final pct = (position.inSeconds / duration.inSeconds) * 100;

      ref
          .read(
            videoProgressProvider(widget.courseId, widget.lessonId).notifier,
          )
          .updateProgress(
            pct,
            position.inSeconds,
            widget.courseId,
            widget.lessonId,
          );
    }
  }

  /// `enableCaption: false` sets YouTube's initial `cc_load_policy`, but the
  /// iframe can still restore a previously selected caption track. Unload both
  /// caption-module names used by YouTube's iframe runtime. This is called on
  /// readiness and meaningful player-state transitions, not on every position
  /// tick, so the workaround does not add continuous WebView work.
  void _disableYoutubeCaptions() {
    final webViewController = _controller?.value.webViewController;
    if (webViewController == null) return;

    unawaited(
      webViewController.evaluateJavascript(
        source: """
(function () {
  try {
    // Some YouTube WebView builds restore the caption module from the user's
    // account preference even after unloadModule(). A permanent CSS rule is a
    // cheaper and more reliable fallback than polling or covering the video
    // with a Flutter overlay. It only targets YouTube's caption container.
    var styleId = 'eduzone-hide-youtube-captions';
    if (!document.getElementById(styleId)) {
      var style = document.createElement('style');
      style.id = styleId;
      style.textContent =
          '.ytp-caption-window-container, .ytp-caption-segment {' +
          'display: none !important; visibility: hidden !important;}';
      (document.head || document.documentElement).appendChild(style);
    }

    if (window.player && typeof window.player.unloadModule === 'function') {
      window.player.unloadModule('captions');
      window.player.unloadModule('cc');
    }
  } catch (_) {}
})();
""",
      ),
    );
  }

  /// Best-effort analytics ping: failure here must never block or
  /// interrupt playback. Routing through [LogRemoteDataSource] keeps the
  /// Supabase call out of the presentation layer; the datasource already
  /// applies the telemetry timeout and swallows failures.
  Future<void> _logLessonStarted() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await _activityLogger.logLessonStarted(
      userId: userId,
      courseId: widget.courseId,
      lessonId: widget.lessonId,
      player: 'youtube',
      devicePlatform: DeviceInfoHelper.platform,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final youtubeUrl = widget.lessonContent.videoUrl;
    final videoId = (youtubeUrl == null || youtubeUrl.isEmpty)
        ? null
        : YoutubePlayer.convertUrlToId(youtubeUrl);
    if (videoId != null && videoId != _lastVideoId) {
      _scheduleControllerSwap(videoId);
    }

    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Phase 11 content watermark: IgnorePointer-rooted (see
    // ContentWatermark), top-right over the video area — clear of the
    // center playback buttons and the bottom progress/time row — so taps
    // still reach the overlay GestureDetector below untouched. Gated by
    // the screen_watermark remote flag, fail-closed: an unevaluated flag
    // (default true) still shows the mark.
    final showWatermark = ref
        .watch(featureFlagsProvider)
        .isEnabled(FeatureFlagKey.screenWatermark);
    final watermarkText = watermarkFragmentForUserId(
      ref.watch(currentUserIdProvider),
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomYoutubePlayer(
          controller: _controller!,
          isVertical: widget.isVertical,
          isFullScreen: widget.isFullScreen,
          onToggleFullScreen: widget.onToggleFullScreen,
        ),
        if (showWatermark)
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.md,
            child: ContentWatermark(watermarkText: watermarkText),
          ),
      ],
    );
  }
}
