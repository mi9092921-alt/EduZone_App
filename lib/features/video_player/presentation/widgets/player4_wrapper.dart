import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/device_info_helper.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/cross_feature/courses_shared.dart';
import '../../data/models/streaming_video_info.dart';
import '../providers/player4_provider.dart';
import '../providers/video_provider.dart';

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
  final List<String> _targetQualities = ['1080p', '720p', '480p', '360p', '240p', '144p'];

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

    _subscriptions.add(_player.stream.position.listen((_) {
      _reportProgress();
    }));

    _subscriptions.add(_player.stream.error.listen((err) {
      _handlePlayerError(err);
    }));

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

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // Matches the common YouTube URL shapes:
  //   watch?v=ID , youtu.be/ID , embed/ID , shorts/ID , live/ID
  // and captures the 11-char video id right after them.
  static final RegExp _youtubeIdPattern = RegExp(
    r'(?:youtube(?:-nocookie)?\.com/(?:watch\?v=|embed/|shorts/|live/)|youtu\.be/)([A-Za-z0-9_-]{11})',
  );

  String? _extractVideoId(String? urlOrId) {
    if (urlOrId == null || urlOrId.isEmpty) return null;
    if (urlOrId.length == 11 && !urlOrId.contains('/')) return urlOrId;

    final match = _youtubeIdPattern.firstMatch(urlOrId);
    if (match != null) return match.group(1);

    // Not a recognized YouTube URL shape — return as-is (e.g. a direct id,
    // or a non-YouTube identifier this widget also needs to pass through).
    return urlOrId;
  }

  StreamingFormat? _findDefaultFormat(List<StreamingFormat> formats, String defaultLabel) {
    if (formats.isEmpty) return null;

    // 1. Exact match
    for (final f in formats) {
      if (f.quality.trim().toLowerCase() == defaultLabel.trim().toLowerCase()) {
        return f;
      }
    }

    int? parseHeight(String q) {
      final match = RegExp(r'(\d+)p').firstMatch(q);
      if (match != null) {
        return int.tryParse(match.group(1) ?? '');
      }
      return null;
    }

    final targetHeight = parseHeight(defaultLabel);
    if (targetHeight != null) {
      // 2. Height exact match
      for (final f in formats) {
        if (parseHeight(f.quality) == targetHeight) {
          return f;
        }
      }
      // 3. Closest height match
      StreamingFormat? closest;
      int minDiff = 999999;
      for (final f in formats) {
        final h = parseHeight(f.quality);
        if (h != null) {
          final diff = (h - targetHeight).abs();
          if (diff < minDiff) {
            minDiff = diff;
            closest = f;
          }
        }
      }
      if (closest != null) return closest;
    }

    // 4. Fallback to first available format
    return formats.first;
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

      final videoInfo = await ref.read(player4VideoInfoProvider(videoId).future);

      if (!mounted || _loadedVideoId != videoId) return;

      if (videoInfo.formats.isEmpty) {
        throw Exception('No formats available');
      }

      // NOTE: intentionally keeping the previously selected quality (if any)
      // as the "saved" preference so it carries over between lessons,
      // mirroring common video-player UX (e.g. YouTube). Leave this as-is
      // unless the intended behavior is confirmed to be per-lesson reset.
      final savedQuality = _selectedFormat?.quality ?? videoInfo.defaultQuality;
      final format = _findDefaultFormat(videoInfo.formats, savedQuality) ?? videoInfo.formats.first;

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
      debugPrint('🔴 [_refreshAndPlay] Exception: $e');
      debugPrint('🔴 [_refreshAndPlay] StackTrace:\n$st');
      if (!mounted || _loadedVideoId != videoId) return;
      setState(() {
        _isLoadingVideoData = false;
        _hasError = true;
        _errorMessage = _mapErrorToMessage(e);
      });
    }
  }

  /// Maps any exception to the most accurate user-facing message.
  String _mapErrorToMessage(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network') ||
        msg.contains('failed host lookup') ||
        msg.contains('socketexception') ||
        msg.contains('no internet') ||
        msg.contains('network_error')) {
      return AppLocalizations.of(context)!.checkInternetConnection;
    }
    if (msg.contains('formatexception') ||
        msg.contains('type cast') ||
        msg.contains('invalid video-info response format')) {
      return AppLocalizations.of(context)!.videoParseError;
    }
    return AppLocalizations.of(context)!.serverError;
  }

  Future<void> _playFormat(StreamingFormat format, {required bool seekToCurrent}) async {
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
            debugPrint('Fallback: Switching to standalone audio format: ${fallback.quality}');
            finalFormat = fallback;
            if (mounted && requestId == _playRequestId) {
              setState(() {
                _selectedFormat = finalFormat;
              });
            }
            await _player.open(
              Media(finalFormat.videoUrl),
              play: false,
            );
            if (requestId != _playRequestId) return;
          } else {
            await _player.open(
              Media(videoUrl),
              play: false,
            );
            if (requestId != _playRequestId) return;
          }
        }
      } else {
        await _player.open(
          Media(videoUrl),
          play: false,
        );
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

      unawaited(Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && requestId == _playRequestId) {
          _player.play();
          _logLessonStartedOnce();
        }
      }));
    } catch (e, st) {
      debugPrint('[_playFormat] quality=${format.quality} failed: $e');
      debugPrint('[_playFormat] StackTrace:\n$st');
      if (mounted && requestId == _playRequestId) {
        setState(() {
          _isLoadingVideoData = false;
          _hasError = true;
          _errorMessage = _mapErrorToMessage(e);
        });
      }
    }
  }

  void _handlePlayerError(dynamic error) {
    debugPrint('🎥 Player4 error occurred: $error');
    if (!mounted) return;

    final videoId = _loadedVideoId;
    final canRetry = videoId != null && (_lastFailedVideoId != videoId || _retryCount < 2);

    if (canRetry) {
      // Debounce: media_kit/mpv can fire non-fatal error events (buffering
      // hiccups, minor decode warnings) in quick succession. Avoid triggering
      // a full Supabase refetch + reopen more than once every 3 seconds.
      // NOTE: this only gates the retry path below — the final "give up and
      // show an error" branch in the `else` is never debounced, so a real
      // failure is always surfaced to the user even mid-burst.
      final now = DateTime.now();
      if (_lastErrorRefreshAt != null && now.difference(_lastErrorRefreshAt!) < const Duration(seconds: 3)) {
        debugPrint('🎥 Ignoring error event: debounced (last refresh < 3s ago)');
        return;
      }

      if (_lastFailedVideoId != videoId) {
        _lastFailedVideoId = videoId;
        _retryCount = 0;
      }
      _retryCount++;
      _lastErrorRefreshAt = now;
      debugPrint('🎥 Error detected during playback. Retrying URL refresh ($_retryCount/2)...');

      unawaited(Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _loadedVideoId == videoId) {
          unawaited(_refreshAndPlay(videoId, seekToCurrent: true, forceRefresh: true));
        }
      }));
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
      ref.read(videoProgressProvider(widget.courseId, widget.lessonId).notifier).updateProgress(
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

    return Positioned.fill(
      child: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          opacity: _showControls ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_showControls,
            child: Stack(
              children: [
                // Semi-transparent background
                Container(
                  color: Colors.black.withValues(alpha: 0.45),
                ),

                // Top control bar
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      widget.isFullScreen
                          ? AppIconButton(
                              icon: Icons.fullscreen_exit_rounded,
                              color: Colors.white,
                              iconSize: 24,
                              semanticLabel:
                                  AppLocalizations.of(context)!.exitFullScreenButtonTooltip,
                              onPressed: widget.onToggleFullScreen,
                            )
                          : const SizedBox(width: 40),
                      Row(
                        children: [
                          // Mute/Unmute
                          AppIconButton(
                            icon: _isMuted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            color: Colors.white,
                            iconSize: 22,
                            semanticLabel: AppLocalizations.of(context)!.volumeTooltip,
                            onPressed: () {
                              setState(() {
                                _isMuted = !_isMuted;
                                _player.setVolume(_isMuted ? 0.0 : 100.0);
                              });
                              _startHideTimer();
                            },
                          ),

                          // Speed Menu
                          PopupMenuButton<double>(
                            icon: const Icon(
                              Icons.speed_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            tooltip: AppLocalizations.of(context)!.speedTooltip,
                            color: ds.surface,
                            shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
                            offset: const Offset(0, 35),
                            constraints: const BoxConstraints(maxHeight: 240),
                            onSelected: (speed) {
                              setState(() => _playbackSpeed = speed);
                              _player.setRate(speed);
                              _startHideTimer();
                            },
                            itemBuilder: (context) => _speeds
                                .map((s) => PopupMenuItem<double>(
                                      value: s,
                                      height: 36,
                                      child: Text(
                                        s == 1.0 ? AppLocalizations.of(context)!.normalSpeed : '${s}x',
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          color: _playbackSpeed == s ? ds.primary : ds.textPrimary,
                                          fontWeight: _playbackSpeed == s ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),

                          // Quality Menu
                          PopupMenuButton<StreamingFormat>(
                            icon: const Icon(
                              Icons.settings_suggest_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            tooltip: AppLocalizations.of(context)!.settingsTooltip,
                            color: ds.surface,
                            shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
                            offset: const Offset(0, 35),
                            onSelected: (format) => unawaited(_handleQualitySelected(format)),
                            itemBuilder: (context) {
                              final uniqueLabels = <String>{};
                              final List<PopupMenuItem<StreamingFormat>> items = [];

                              for (final targetLabel in _targetQualities) {
                                final hasFormat = _availableFormats.any(
                                    (f) => f.quality.startsWith(targetLabel));
                                if (hasFormat && !uniqueLabels.contains(targetLabel)) {
                                  uniqueLabels.add(targetLabel);
                                  final formatData = _availableFormats.firstWhere(
                                      (f) => f.quality.startsWith(targetLabel));
                                  final isSelected = _selectedFormat?.quality.startsWith(targetLabel) ?? false;

                                  items.add(PopupMenuItem<StreamingFormat>(
                                    value: formatData,
                                    height: 38,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (isSelected)
                                          Icon(
                                            Icons.check_rounded,
                                            color: ds.primary,
                                            size: 16,
                                          )
                                        else
                                          const SizedBox(width: 16),
                                        Text(
                                          targetLabel,
                                          style: AppTextStyles.bodyMedium.copyWith(
                                            color: isSelected ? ds.primary : ds.textPrimary,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ));
                                }
                              }
                              return items;
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Center playback buttons
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppIconButton(
                        icon: Icons.replay_10_rounded,
                        color: Colors.white,
                        iconSize: widget.isFullScreen ? 28 : 32,
                        semanticLabel: AppLocalizations.of(context)!.rewindButtonTooltip,
                        onPressed: () async {
                          final currentPos = _player.state.position;
                          final target = currentPos - const Duration(seconds: 10);
                          await _player.seek(target < Duration.zero ? Duration.zero : target);
                          _startHideTimer();
                        },
                      ),
                      const SizedBox(width: 32),
                      StreamBuilder<bool>(
                        stream: _player.stream.playing,
                        initialData: _player.state.playing,
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data ?? false;
                          return CircleAvatar(
                            radius: widget.isFullScreen ? 26 : 30,
                            backgroundColor: ds.primary,
                            child: AppIconButton(
                              icon: isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              iconSize: widget.isFullScreen ? 26 : 34,
                              semanticLabel: isPlaying
                                  ? AppLocalizations.of(context)!.pauseButtonTooltip
                                  : AppLocalizations.of(context)!.playButtonLabel,
                              onPressed: () {
                                _player.playOrPause();
                                _startHideTimer();
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 32),
                      AppIconButton(
                        icon: Icons.forward_10_rounded,
                        color: Colors.white,
                        iconSize: widget.isFullScreen ? 28 : 32,
                        semanticLabel: AppLocalizations.of(context)!.fastForwardButtonTooltip,
                        onPressed: () async {
                          final currentPos = _player.state.position;
                          final totalDur = _player.state.duration;
                          final target = currentPos + const Duration(seconds: 10);
                          await _player.seek(target > totalDur ? totalDur : target);
                          _startHideTimer();
                        },
                      ),
                    ],
                  ),
                ),

                // Bottom time bar & Slider
                Positioned(
                  bottom: widget.isFullScreen ? AppSpacing.md : AppSpacing.xs,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  child: StreamBuilder<Duration>(
                    stream: _player.stream.position,
                    initialData: _player.state.position,
                    builder: (context, posSnapshot) {
                      final position = posSnapshot.data ?? Duration.zero;
                      return StreamBuilder<Duration>(
                        stream: _player.stream.duration,
                        initialData: _player.state.duration,
                        builder: (context, durSnapshot) {
                          final duration = durSnapshot.data ?? Duration.zero;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.white70,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.white70,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: 20,
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2.0,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                                    activeTrackColor: ds.primary,
                                    inactiveTrackColor: Colors.white12,
                                    thumbColor: ds.primary,
                                  ),
                                  child: Slider(
                                    value: position.inSeconds.toDouble().clamp(
                                        0.0, duration.inSeconds.toDouble()),
                                    max: duration.inSeconds.toDouble() > 0.0
                                        ? duration.inSeconds.toDouble()
                                        : 1.0,
                                    onChanged: (value) {
                                      _player.seek(Duration(seconds: value.toInt()));
                                      _startHideTimer();
                                    },
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerUI() {
    final ds = AppColors.of(context);
    final media = MediaQuery.of(context);
    final double playerHeight = widget.isVertical
        ? (media.size.width * 16.0 / 9.0).clamp(0.0, media.size.height * 0.52)
        : media.size.width * 9.0 / 16.0;

    final playerWidget = Center(
      child: Video(controller: _videoController),
    );

    if (widget.isFullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            playerWidget,
            _buildControlsOverlay(ds),
            if (_isLoadingVideoData)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.8),
                child: Center(child: CircularProgressIndicator(color: ds.primary)),
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
          ColoredBox(
            color: Colors.black,
            child: playerWidget,
          ),
          _buildControlsOverlay(ds),
          if (_isLoadingVideoData)
            ColoredBox(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator(color: ds.primary)),
            ),
          if (_hasError)
            Container(
              color: Colors.black.withValues(alpha: 0.96),
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, color: ds.error, size: 40),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _errorMessage,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: ds.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ds.surface2,
                        foregroundColor: ds.primary,
                        elevation: 0,
                        side: BorderSide(color: ds.primary.withValues(alpha: 0.4)),
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                      ),
                      onPressed: () {
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
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(
                        AppLocalizations.of(context)!.retryLoading,
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
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
        final videoId = _extractVideoId(content.videoUrl);
        if (videoId == null || videoId.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.invalidVideoUrl,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.of(context).error),
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
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
