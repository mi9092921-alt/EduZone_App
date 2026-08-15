import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../core/network/supabase_client.dart';
import '../../../../../core/utils/device_info_helper.dart';
import '../../../../../design_system/design_system.dart';
import '../../../../../shared/cross_feature/courses_shared.dart';
import '../../../application/providers/player4_provider.dart';
import '../../../application/providers/video_provider.dart';
import '../../../data/models/streaming_video_info.dart';
import 'player4_controls_overlay.dart';
import 'player4_error_mapper.dart';
import 'player4_error_view.dart';
import 'player4_format_selection.dart';
import 'player4_loading_overlay.dart';
import 'player4_youtube_id.dart';

/// Structure note: state management, Supabase/provider integration, and
/// playback-control logic (quality switching, error-retry debouncing,
/// progress reporting) stay in this file — it's one cohesive unit driven
/// by `setState`/`mounted`/stream subscriptions around a native `Player`,
/// and minimizing behavioral risk here matters more than file length. The
/// purely-presentational pieces (top bar, center controls, seek bar,
/// controls overlay shell, loading/error views) and the pure utility
/// functions (duration formatting, YouTube id extraction, format
/// selection, error-message mapping) have been extracted into sibling
/// files in this folder — each independently testable with no direct
/// dependency on `Player` or this State class.
class Player4Wrapper extends ConsumerStatefulWidget {
  final String courseId;
  final String lessonId;
  final bool isFullScreen;
  final bool isVertical;
  final VoidCallback onToggleFullScreen;

  const Player4Wrapper({
    super.key,
    required this.courseId,
    required this.lessonId,
    required this.isFullScreen,
    required this.isVertical,
    required this.onToggleFullScreen,
  });

  @override
  ConsumerState<Player4Wrapper> createState() => _Player4WrapperState();
}

class _Player4WrapperState extends ConsumerState<Player4Wrapper> {
  late final Player _player;
  late final VideoController _videoController;
  final List<StreamSubscription> _subscriptions = [];

  String? _loadedVideoId;
  bool _isLoadingVideoData = true;
  bool _hasError = false;
  String _errorMessage = '';

  bool _isMuted = false;
  Timer? _hideTimer;
  bool _showControls = true;
  double _playbackSpeed = 1.0;
  bool _loggedStarted = false;

  List<StreamingFormat> _availableFormats = [];
  StreamingFormat? _selectedFormat;
  StreamingVideoInfo? _videoInfo;

  final List<double> _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  final List<String> _targetQualities = [
    '1080p',
    '720p',
    '480p',
    '360p',
    '240p',
    '144p',
  ];

  int _retryCount = 0;
  String? _lastFailedVideoId;

  // Guards against out-of-order completions when the user switches quality
  // (or the widget reloads a new lesson) faster than a previous _playFormat
  // call can finish. Every call captures the counter's value at entry and
  // bails out after any await if a newer call has since started.
  int _playRequestId = 0;

  // Throttles progress reporting so we don't hammer the provider (and
  // Supabase behind it) on every position tick (~4x/second from media_kit).
  DateTime _lastProgressReport = DateTime.fromMillisecondsSinceEpoch(0);

  // Debounces full refetch-on-error handling. media_kit/mpv can emit
  // non-fatal error events (buffering hiccups, minor decode warnings) in
  // quick succession; without this, each one could trigger a fresh
  // Supabase fetch + player reopen.
  DateTime? _lastErrorRefreshAt;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);

    _subscriptions.add(
      _player.stream.position.listen((_) {
        _reportProgress();
      }),
    );

    _subscriptions.add(
      _player.stream.error.listen((err) {
        _handlePlayerError(err);
      }),
    );

    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  Future<void> _handleQualitySelected(StreamingFormat format) async {
    final previousFormat = _selectedFormat;

    setState(() {
      _selectedFormat = format;
      _hasError = false;
      _errorMessage = '';
    });

    await _playFormat(format, seekToCurrent: true);
    if (!mounted) return;

    if (_hasError && previousFormat != null) {
      setState(() => _selectedFormat = previousFormat);
    }
    _startHideTimer();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideTimer();
    }
  }

  Future<void> _refreshAndPlay(
    String videoId, {
    required bool seekToCurrent,
    bool forceRefresh = false,
  }) async {
    if (!mounted) return;
    setState(() {
      _isLoadingVideoData = true;
      _hasError = false;
    });

    try {
      if (forceRefresh) {
        ref.invalidate(player4VideoInfoProvider(videoId));
      }

      final videoInfo = await ref.read(
        player4VideoInfoProvider(videoId).future,
      );

      if (!mounted || _loadedVideoId != videoId) return;

      if (videoInfo.formats.isEmpty) {
        throw Exception('No formats available'); // check-ignore
      }

      // NOTE: intentionally keeping the previously selected quality (if any)
      // as the "saved" preference so it carries over between lessons,
      // mirroring common video-player UX (e.g. YouTube). Leave this as-is
      // unless the intended behavior is confirmed to be per-lesson reset.
      final savedQuality = _selectedFormat?.quality ?? videoInfo.defaultQuality;
      final format =
          findDefaultStreamingFormat(videoInfo.formats, savedQuality) ??
          videoInfo.formats.first;

      setState(() {
        _videoInfo = videoInfo;
        _availableFormats = videoInfo.formats;
        _selectedFormat = format;
        _isLoadingVideoData = false;
        _hasError = false;
      });

      await _playFormat(format, seekToCurrent: seekToCurrent);
    } catch (e, st) {
      debugPrint('🔴 [_refreshAndPlay] Exception type: ${e.runtimeType}');
      debugPrint('🔴 [_refreshAndPlay] StackTrace:\n$st');
      if (!mounted || _loadedVideoId != videoId) return;
      setState(() {
        _isLoadingVideoData = false;
        _hasError = true;
        _errorMessage = mapPlayer4ErrorToMessage(
          AppLocalizations.of(context)!,
          e,
        );
      });
    }
  }

  Future<void> _playFormat(
    StreamingFormat format, {
    required bool seekToCurrent,
  }) async {
    // Capture the request id for this call. If a newer _playFormat call
    // starts before this one finishes, requestId will no longer match
    // _playRequestId and we bail out instead of racing against it.
    final requestId = ++_playRequestId;

    try {
      StreamingFormat finalFormat = format;
      final String videoUrl = finalFormat.videoUrl;
      final currentPosition = _player.state.position;

      // Apply audio merge if format has no audio and global audio track exists
      if (!finalFormat.hasAudio) {
        if (_videoInfo?.audio != null) {
          final audioUrl = _videoInfo!.audio!.url;
          await _player.open(Media(videoUrl), play: false);
          if (requestId != _playRequestId) return;
          await _player.setAudioTrack(AudioTrack.uri(audioUrl));
          if (requestId != _playRequestId) return;
        } else {
          debugPrint(
            'Warning: Selected format requires audio merge, but global audio track is NULL!',
          );
          // Fallback to the closest format that has standalone audio (hasAudio = true)
          final fallback = _availableFormats.firstWhere(
            (f) => f.hasAudio,
            orElse: () => finalFormat,
          );

          if (fallback != finalFormat) {
            debugPrint(
              'Fallback: Switching to standalone audio format: ${fallback.quality}',
            );
            finalFormat = fallback;
            if (mounted && requestId == _playRequestId) {
              setState(() {
                _selectedFormat = finalFormat;
              });
            }
            await _player.open(Media(finalFormat.videoUrl), play: false);
            if (requestId != _playRequestId) return;
          } else {
            await _player.open(Media(videoUrl), play: false);
            if (requestId != _playRequestId) return;
          }
        }
      } else {
        await _player.open(Media(videoUrl), play: false);
        if (requestId != _playRequestId) return;
      }

      if (seekToCurrent) {
        await _player.seek(currentPosition);
        if (requestId != _playRequestId) return;
      }

      await _player.setRate(_playbackSpeed);
      if (requestId != _playRequestId) return;

      await _player.setVolume(_isMuted ? 0.0 : 100.0);
      if (requestId != _playRequestId) return;

      unawaited(
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && requestId == _playRequestId) {
            _player.play();
            _logLessonStartedOnce();
          }
        }),
      );
    } catch (e, st) {
      debugPrint(
        '[_playFormat] quality=${format.quality} failed: ${e.runtimeType}',
      );
      debugPrint('[_playFormat] StackTrace:\n$st');
      if (mounted && requestId == _playRequestId) {
        setState(() {
          _isLoadingVideoData = false;
          _hasError = true;
          _errorMessage = mapPlayer4ErrorToMessage(
            AppLocalizations.of(context)!,
            e,
          );
        });
      }
    }
  }

  void _handlePlayerError(dynamic error) {
    debugPrint('🎥 Player4 error occurred: ${error.runtimeType}');
    if (!mounted) return;

    final videoId = _loadedVideoId;
    final canRetry =
        videoId != null && (_lastFailedVideoId != videoId || _retryCount < 2);

    if (canRetry) {
      // Debounce: media_kit/mpv can fire non-fatal error events (buffering
      // hiccups, minor decode warnings) in quick succession. Avoid triggering
      // a full Supabase refetch + reopen more than once every 3 seconds.
      // NOTE: this only gates the retry path below — the final "give up and
      // show an error" branch in the `else` is never debounced, so a real
      // failure is always surfaced to the user even mid-burst.
      final now = DateTime.now();
      if (_lastErrorRefreshAt != null &&
          now.difference(_lastErrorRefreshAt!) < const Duration(seconds: 3)) {
        debugPrint('🎥 Ignoring error event: debounced (last refresh < 3s ago)');
        return;
      }

      if (_lastFailedVideoId != videoId) {
        _lastFailedVideoId = videoId;
        _retryCount = 0;
      }
      _retryCount++;
      _lastErrorRefreshAt = now;
      debugPrint(
        '🎥 Error detected during playback. Retrying URL refresh ($_retryCount/2)...',
      );

      unawaited(
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _loadedVideoId == videoId) {
            unawaited(
              _refreshAndPlay(videoId, seekToCurrent: true, forceRefresh: true),
            );
          }
        }),
      );
    } else {
      setState(() {
        _hasError = true;
        _errorMessage = AppLocalizations.of(context)!.serverError;
      });
    }
  }

  void _reportProgress() {
    if (!mounted) return;

    // Throttle: position ticks fire ~4x/second from media_kit. Reporting
    // progress that often is unnecessary network/battery cost; every 5s
    // is more than enough resolution for a "resume where you left off" feature.
    final now = DateTime.now();
    if (now.difference(_lastProgressReport) < const Duration(seconds: 5)) return;
    _lastProgressReport = now;

    final duration = _player.state.duration;
    final position = _player.state.position;

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

  void _logLessonStartedOnce() async {
    if (_loggedStarted) return;
    _loggedStarted = true;
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
            'player': 'player4',
          },
        },
      );
    } catch (_) {}
  }

  Widget _buildControlsOverlay(DesignSystemColors ds) {
    if (_isLoadingVideoData || _hasError) return const SizedBox.shrink();

    return Player4ControlsOverlay(
      showControls: _showControls,
      onToggleControls: _toggleControls,
      isFullScreen: widget.isFullScreen,
      onExitFullScreen: widget.onToggleFullScreen,
      isMuted: _isMuted,
      onToggleMute: () {
        setState(() {
          _isMuted = !_isMuted;
          _player.setVolume(_isMuted ? 0.0 : 100.0);
        });
        _startHideTimer();
      },
      speeds: _speeds,
      currentSpeed: _playbackSpeed,
      onSpeedSelected: (speed) {
        setState(() => _playbackSpeed = speed);
        _player.setRate(speed);
        _startHideTimer();
      },
      targetQualities: _targetQualities,
      availableFormats: _availableFormats,
      selectedFormat: _selectedFormat,
      onQualitySelected: (format) => unawaited(_handleQualitySelected(format)),
      onRewind: () async {
        final currentPos = _player.state.position;
        final target = currentPos - const Duration(seconds: 10);
        await _player.seek(target < Duration.zero ? Duration.zero : target);
        _startHideTimer();
      },
      onFastForward: () async {
        final currentPos = _player.state.position;
        final totalDur = _player.state.duration;
        final target = currentPos + const Duration(seconds: 10);
        await _player.seek(target > totalDur ? totalDur : target);
        _startHideTimer();
      },
      playingStream: _player.stream.playing,
      initialPlaying: _player.state.playing,
      onTogglePlayback: () {
        _player.playOrPause();
        _startHideTimer();
      },
      positionStream: _player.stream.position,
      initialPosition: _player.state.position,
      durationStream: _player.stream.duration,
      initialDuration: _player.state.duration,
      onSeek: (position) {
        _player.seek(position);
        _startHideTimer();
      },
      ds: ds,
    );
  }

  Widget _buildPlayerUI() {
    final ds = AppColors.of(context);
    final media = MediaQuery.of(context);
    final double playerHeight = widget.isVertical
        ? (media.size.width * 16.0 / 9.0).clamp(0.0, media.size.height * 0.52)
        : media.size.width * 9.0 / 16.0;

    final playerWidget = Center(child: Video(controller: _videoController));

    if (widget.isFullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            playerWidget,
            _buildControlsOverlay(ds),
            if (_isLoadingVideoData)
              Player4LoadingOverlay(
                backgroundColor: Colors.black.withValues(alpha: 0.8),
                spinnerColor: ds.primary,
              ),
          ],
        ),
      );
    }

    return SizedBox(
      height: playerHeight,
      width: double.infinity,
      child: Stack(
        children: [
          ColoredBox(color: Colors.black, child: playerWidget),
          _buildControlsOverlay(ds),
          if (_isLoadingVideoData)
            Player4LoadingOverlay(
              backgroundColor: Colors.black54,
              spinnerColor: ds.primary,
            ),
          if (_hasError)
            Player4ErrorView(
              errorMessage: _errorMessage,
              onRetry: () {
                if (_selectedFormat != null) {
                  unawaited(_playFormat(_selectedFormat!, seekToCurrent: true));
                } else if (_loadedVideoId != null) {
                  unawaited(
                    _refreshAndPlay(
                      _loadedVideoId!,
                      seekToCurrent: false,
                      forceRefresh: true,
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lessonContentAsync = ref.watch(lessonContentProvider(widget.lessonId));

    return lessonContentAsync.when(
      data: (content) {
        final videoId = extractYoutubeVideoId(content.videoUrl);
        if (videoId == null || videoId.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.invalidVideoUrl,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.of(context).error,
              ),
            ),
          );
        }

        if (_loadedVideoId != videoId) {
          _loadedVideoId = videoId;
          _retryCount = 0;
          _lastFailedVideoId = null;
          _loggedStarted = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_refreshAndPlay(videoId, seekToCurrent: false));
          });
        }

        return _buildPlayerUI();
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(AppLocalizations.of(context)!.errorLoading(e.toString())),
      ),
    );
  }
}
