import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';
import '../../../../../core/services/encryption_service.dart'
    show detectContainerExt;
import '../../../../../core/services/offline_playback_service.dart';
import '../../../application/providers/downloads_provider.dart';
import '../../../domain/entities/downloaded_lesson.dart';
import 'offline_player_center_button.dart';
import 'offline_player_controls_overlay.dart';
import 'offline_player_error_view.dart';
import 'offline_player_loading_view.dart';
import 'offline_player_seek_slider.dart';

/// Offline lesson playback with AES-256-GCM file decryption.
///
/// **Media Kit Migration:**
/// Replaced `video_player` with `media_kit` (libmpv engine) for:
/// - Playback speed control (0.5x–2x via `setRate()`)
/// - Buffered seek slider (no jitter during drag)
/// - Reactive streams (`player.stream.*`) instead of manual listeners
/// - Hardware-accelerated rendering, fewer aspect-ratio glitches
///
/// Decryption flow (AES-256-GCM via `OfflinePlaybackService`) unchanged.
///
/// **Hardening pass (this version):**
/// - Guards against native `Player` leaks if the widget is disposed while
///   `_initializePlayer` is still awaiting (proxy start / decryption).
/// - Cleans up partially-decrypted temp files if initialization fails
///   partway through, instead of leaving plaintext media on disk.
/// - Adds a retry action to the error state.
/// - Controls no longer auto-hide while paused (only while actually
///   playing), which was the previous, unintuitive behavior.
/// - Seek (`_skipSeconds`) is clamped to `[0, duration]`.
/// - Slider value is clamped to `[0, max]` to avoid a Flutter assertion
///   failure if position and duration momentarily disagree.
/// - Surfaces mid-playback engine errors via `player.stream.error` (logged,
///   non-fatal) instead of silently ignoring them.
/// - Raw exception text is only shown in debug builds; release builds show
///   a generic, localized message.
///
/// **Structure (this version):** lifecycle/player-management logic
/// (initialization, dual-track decryption, dispose/cleanup, playback
/// controls) stays in this file — it's one cohesive unit driven by
/// `setState`/`mounted`/stream subscriptions, and this is
/// security-adjacent (DRM/decryption) code where minimizing behavioral
/// risk matters more than file length. The purely-presentational pieces
/// (loading view, error view, center button, controls overlay, seek
/// slider, duration formatting) have been extracted into sibling files in
/// this folder — each one is a plain, decoupled, independently-testable
/// widget/function with no direct dependency on `Player` or this State
/// class.
class OfflinePlayerWrapper extends ConsumerStatefulWidget {
  final DownloadedLesson download;
  final bool isFullScreen;
  final bool isVertical;
  final VoidCallback onToggleFullScreen;

  const OfflinePlayerWrapper({
    super.key,
    required this.download,
    required this.isFullScreen,
    required this.isVertical,
    required this.onToggleFullScreen,
  });

  @override
  ConsumerState<OfflinePlayerWrapper> createState() =>
      _OfflinePlayerWrapperState();
}

class _OfflinePlayerWrapperState extends ConsumerState<OfflinePlayerWrapper>
    with WidgetsBindingObserver {
  late final OfflinePlaybackService _playbackService;
  Player? _player;
  VideoController? _videoController;
  Uri? _proxyUri;
  File? _tempDecryptedFile; // kept for fallback path
  File? _tempAudioDecryptedFile; // kept for dual-track audio path
  bool _isLoading = true;
  bool _hasError = false;
  bool _isPlaying = false;
  bool _showControls = true;
  int _speedIndex = 2; // Index 2 = 1.0x in _speeds below
  late final List<double> _speeds =
      [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]; // Indices: [0, 1, 2, 3, 4, 5]
  StreamSubscription<bool>? _playingSubscription; // Nullable: avoids
  // LateInitializationError in dispose() if _initializePlayer() throws
  // before this is ever assigned (e.g. decryption failure).
  StreamSubscription<int?>? _widthSubscription;
  StreamSubscription<int?>? _heightSubscription;
  StreamSubscription<bool>? _completedSubscription;
  StreamSubscription<String>? _errorSubscription;
  int? _videoWidth;
  int? _videoHeight;
  Timer? _autoHideTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playbackService = OfflinePlaybackService(
      encryptionService: ref.read(encryptionServiceProvider),
    );
    _initializePlayer();
    _resetAutoHideTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause on both `paused` (backgrounded) and `inactive` (e.g. an
    // incoming call or notification shade on iOS) so audio doesn't keep
    // playing during a transient interruption.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _player?.pause();
    }
    // Intentionally no auto-resume on foreground.
  }

  Future<void> _initializePlayer() async {
    try {
      final isDualTrack = widget.download.audioPath != null &&
          widget.download.audioPath!.isNotEmpty;

      if (isDualTrack) {
        // For dual-track downloads, bypass streaming proxy and decrypt both files.
        //
        // The temp file extension must match the *real* container (mp4,
        // webm, mkv, ...) — mpv/ffmpeg use the file extension as a strong
        // hint when picking a demuxer, so hardcoding `.mp4` for content
        // that's actually WebM/VP9 (common for 720p+ YouTube video-only
        // streams) causes the demuxer to misidentify the container: the
        // video track fails to decode (black frame) while the separately
        // decrypted audio track still plays fine via setAudioTrack below.
        final tempDir = Directory.systemTemp;
        final videoExt = detectContainerExt(widget.download.encryptedPath);
        final audioExt = detectContainerExt(
          widget.download.audioPath ?? '',
          fallback: 'm4a',
        );
        final videoTempFile = File(
          '${tempDir.path}/${widget.download.id}_video_decrypted.$videoExt',
        );
        _tempDecryptedFile = videoTempFile;
        final audioTempFile = File(
          '${tempDir.path}/${widget.download.id}_audio_decrypted.$audioExt',
        );
        _tempAudioDecryptedFile = audioTempFile;

        await Future.wait([
          _playbackService.preparePlayableFile(
            downloadId: widget.download.id,
            encryptedPath: widget.download.encryptedPath,
            outputPath: videoTempFile.path,
          ),
          _playbackService.preparePlayableFile(
            downloadId: widget.download.id,
            encryptedPath: widget.download.audioPath!,
            outputPath: audioTempFile.path,
          ),
        ]);
      } else {
        // Normal single-file flow: try streaming proxy first
        try {
          _proxyUri = await _playbackService.startStreamingProxy(
            downloadId: widget.download.id,
            encryptedPath: widget.download.encryptedPath,
          );
        } catch (e) {
          // Fallback: full decrypt to temp file. Same reasoning as the
          // dual-track branch above — the extension must reflect the real
          // container, not always '.mp4'.
          final tempDir = Directory.systemTemp;
          final videoExt = detectContainerExt(widget.download.encryptedPath);
          final tempFile = File(
            '${tempDir.path}/${widget.download.id}_decrypted.$videoExt',
          );
          _tempDecryptedFile = tempFile;

          await _playbackService.preparePlayableFile(
            downloadId: widget.download.id,
            encryptedPath: widget.download.encryptedPath,
            outputPath: tempFile.path,
          );
        }
      }

      final player = Player();

      // If the widget was disposed while we were awaiting decryption/proxy
      // setup above, don't leak a native Player instance that nothing will
      // ever dispose of.
      if (!mounted) {
        unawaited(player.dispose());
        return;
      }

      _player = player;
      _videoController = VideoController(player);

      // Subscribe to playing state only for the "controls" concern.
      // Deliberately NOT subscribing to player.stream.position here — that
      // stream fires every ~200-300ms during playback, which would reset
      // the auto-hide timer constantly and prevent controls from ever
      // hiding. Auto-hide is instead driven off play/pause transitions and
      // explicit user actions (see _resetAutoHideTimer call sites).
      _playingSubscription = player.stream.playing.listen((isPlaying) {
        if (!mounted) return;
        setState(() => _isPlaying = isPlaying);
        // Re-evaluate the auto-hide timer whenever play state changes,
        // regardless of what triggered it (our own button, a completed
        // video, a system pause, etc).
        _resetAutoHideTimer();
      });

      // When playback reaches the end, keep controls visible (don't leave
      // the user staring at a frozen last frame with no way to replay).
      _completedSubscription = player.stream.completed.listen((completed) {
        if (completed && mounted) {
          _autoHideTimer?.cancel();
          setState(() => _showControls = true);
        }
      });

      // Mid-playback engine errors (e.g. a corrupt frame) shouldn't crash
      // the whole screen — log them so they're visible in diagnostics
      // without disrupting an otherwise-working playback session.
      _errorSubscription = player.stream.error.listen((message) {
        if (kDebugMode) {
          debugPrint('OfflinePlayerWrapper: player error — $message');
        }
      });

      // The actual video's aspect ratio isn't known until the demuxer has
      // parsed the stream, and it may not match the isVertical/16:9 guess
      // used for the loading placeholder — e.g. a 4:3 or square source
      // would otherwise render inside a box sized for 16:9, visibly
      // mismatched from the real picture. Track the real dimensions and
      // rebuild once they arrive so the container matches the content.
      _widthSubscription = player.stream.width.listen((w) {
        if (mounted && w != null && w > 0) setState(() => _videoWidth = w);
      });
      _heightSubscription = player.stream.height.listen((h) {
        if (mounted && h != null && h > 0) setState(() => _videoHeight = h);
      });

      // Explicit play: false — video stays paused until the user taps the
      // center play button, matching the previous video_player behavior.
      //
      // NOTE: `Media(..., extras: {...})` is NOT a way to pass mpv
      // properties — `extras` is opaque metadata that media_kit stores
      // alongside the Media object and hands back to you via
      // `player.state.playlist`; it is never forwarded to the underlying
      // mpv engine. The previous code set `extras['audio-file']` /
      // `extras['aid']` here expecting mpv to pick them up, which it
      // never did — dual-track downloads played back with no sound.
      // Attach external audio through media_kit's track API after `open()`.
      if (_proxyUri != null) {
        await player.open(Media(_proxyUri.toString()), play: false);
      } else if (_tempDecryptedFile != null) {
        await player.open(Media(_tempDecryptedFile!.path), play: false);
      }

      // Attach the external, already-decrypted audio track for dual-track
      // (video-only + audio-only) downloads. Must happen after `open()`.
      //
      // IMPORTANT: `platform.setProperty('audio-file', path)` (the previous
      // approach) does NOT work here. `audio-file` is an mpv *option* that
      // is only consulted while a file is being loaded — setting it as a
      // property on an already-open Media has no effect on that Media
      // (mpv doesn't retroactively re-scan for external tracks), and mpv
      // does not raise an error for the no-op set, so the failure was
      // completely silent: no exception, no log, just a video with no
      // sound. `setAudioTrack` goes through media_kit's own Track API
      // (backed internally by the correct mpv mechanism for attaching a
      // track to a *running* instance), so it actually takes effect.
      if (isDualTrack && _tempAudioDecryptedFile != null) {
        try {
          await player.setAudioTrack(
            AudioTrack.uri(_tempAudioDecryptedFile!.uri.toString()),
          );
        } catch (e) {
          try {
            await player.setAudioTrack(
              AudioTrack.uri(_tempAudioDecryptedFile!.path),
            );
          } catch (fallbackError) {
            if (kDebugMode) {
              debugPrint(
                'OfflinePlayerWrapper: plain path audio fallback failed: '
                '$fallbackError',
              );
            }
          }
          // Non-fatal: video still plays, just silently. Surface in debug
          // builds only so this doesn't get lost in production logs.
          if (kDebugMode) {
            debugPrint(
              'OfflinePlayerWrapper: failed to attach external audio track — $e',
            );
          }
        }
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (error) {
      // Best-effort cleanup of any partially-prepared temp files so a
      // failed attempt doesn't leave decrypted plaintext media sitting in
      // the temp directory indefinitely.
      await _cleanupTempFilesQuietly();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _cleanupTempFilesQuietly() async {
    final tempFile = _tempDecryptedFile;
    if (tempFile != null) {
      await _playbackService.cleanupTempFile(tempFile).catchError((_) {});
    }
    final tempAudioFile = _tempAudioDecryptedFile;
    if (tempAudioFile != null) {
      await _playbackService.cleanupTempFile(tempAudioFile).catchError((_) {});
    }
  }

  /// Retries initialization from a clean slate after a failure. Mirrors the
  /// cleanup done in [dispose], but synchronously resets state so
  /// `_initializePlayer` can run again.
  Future<void> _retry() async {
    _autoHideTimer?.cancel();
    await _playingSubscription?.cancel();
    await _widthSubscription?.cancel();
    await _heightSubscription?.cancel();
    await _completedSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _player?.dispose();
    _player = null;
    _videoController = null;

    unawaited(_playbackService.stopStreamingProxy().catchError((_) {}));
    await _cleanupTempFilesQuietly();

    _tempDecryptedFile = null;
    _tempAudioDecryptedFile = null;
    _proxyUri = null;
    _videoWidth = null;
    _videoHeight = null;
    _isPlaying = false;

    if (!mounted) return;
    setState(() {
      _hasError = false;
      _isLoading = true;
      _errorMessage = null;
      _showControls = true;
    });

    await _initializePlayer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoHideTimer?.cancel();
    _playingSubscription?.cancel();
    _widthSubscription?.cancel();
    _heightSubscription?.cancel();
    _completedSubscription?.cancel();
    _errorSubscription?.cancel();
    // Note: VideoController has no dispose() method (removed upstream in
    // media_kit_video — see changelog "refactor: remove VideoController.dispose").
    // Disposing the Player alone releases the associated video output.
    _player?.dispose();
    // Restore all orientations on exit, regardless of fullscreen state.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Stop proxy if started — fire-and-forget so dispose stays synchronous.
    unawaited(_playbackService.stopStreamingProxy().catchError((_) {}));

    final tempFile = _tempDecryptedFile;
    if (tempFile != null) {
      unawaited(_playbackService.cleanupTempFile(tempFile).catchError((_) {}));
    }
    final tempAudioFile = _tempAudioDecryptedFile;
    if (tempAudioFile != null) {
      unawaited(
        _playbackService.cleanupTempFile(tempAudioFile).catchError((_) {}),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Prefer the real decoded video dimensions once known; until then (or
    // if the demuxer never reports them) fall back to the isVertical guess.
    // This is what keeps the picture from looking "off" relative to the
    // actual video — the container now matches the source instead of
    // assuming every lesson is exactly 16:9 or 9:16.
    final aspectRatio =
        (_videoWidth != null && _videoHeight != null && _videoHeight! > 0)
        ? _videoWidth! / _videoHeight!
        : (widget.isVertical ? 9 / 16 : 16 / 9);

    if (_isLoading) {
      return OfflinePlayerLoadingView(aspectRatio: aspectRatio);
    }

    if (_hasError) {
      return OfflinePlayerErrorView(
        aspectRatio: aspectRatio,
        errorMessage: _errorMessage,
        onRetry: _retry,
      );
    }

    final videoController = _videoController;
    if (videoController == null) {
      return const SizedBox.shrink();
    }

    if (widget.isFullScreen) {
      return SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            ColoredBox(
              color: Colors.black,
              child: Video(controller: videoController, controls: NoVideoControls),
            ),
            // SafeArea only in fullscreen: system bars are hidden here, so
            // notches/gesture-bar insets would otherwise shift the bottom
            // control row and slider relative to where they sit in
            // non-fullscreen mode (which already sits inside the app's
            // normal safe-area-aware layout). Without this, the same
            // overlay widget ends up visually offset between the two
            // modes even though the widget tree is identical.
            Positioned.fill(
              child: SafeArea(child: _buildControlsOverlay()),
            ),
            // Centered play button — kept identical (same size, opacity,
            // and paused-only visibility) between fullscreen and
            // non-fullscreen so the control layout doesn't shift when the
            // user toggles fullscreen.
            if (!_isPlaying) _buildCenterPlayButton(l10n),
          ],
        ),
      );
    }

    // Non-fullscreen mode
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ColoredBox(
            color: Colors.black,
            child: Video(controller: videoController, controls: NoVideoControls),
          ),
          // _buildControlsOverlay's own GestureDetector already handles
          // tap-to-toggle in both shown/hidden states, so no separate
          // InkWell layer is needed here.
          Positioned.fill(child: _buildControlsOverlay()),
          if (!_isPlaying) _buildCenterPlayButton(l10n),
        ],
      ),
    );
  }

  Widget _buildCenterPlayButton(AppLocalizations l10n) {
    return OfflinePlayerCenterButton(
      tooltip: l10n.playButtonLabel,
      onPressed: _togglePlayback,
    );
  }

  Widget _buildControlsOverlay() {
    return OfflinePlayerControlsOverlay(
      showControls: _showControls,
      onToggleControls: _toggleControls,
      seekSlider: OfflinePlayerSeekSlider(
        positionStream: _player?.stream.position ?? Stream.value(Duration.zero),
        initialPosition: _player?.state.position ?? Duration.zero,
        getDuration: () => _player?.state.duration ?? Duration.zero,
        onSeek: (position) async {
          await _player?.seek(position);
        },
        onSeekEnd: _resetAutoHideTimer,
      ),
      isPlaying: _isPlaying,
      onTogglePlayback: _togglePlayback,
      onRewind: () => _skipSeconds(-10),
      onFastForward: () => _skipSeconds(10),
      speedLabel: '${_speeds[_speedIndex]}x',
      onCycleSpeed: _cycleSpeed,
      isFullScreen: widget.isFullScreen,
      onFullscreenToggle: _handleFullscreenToggle,
    );
  }

  Future<void> _togglePlayback() async {
    final player = _player;
    if (player == null) return;
    if (_isPlaying) {
      await player.pause();
    } else {
      // If the video has already finished, "play" should restart it from
      // the top rather than doing nothing (mpv holds at the last frame).
      final pos = player.state.position;
      final dur = player.state.duration;
      if (dur > Duration.zero && pos >= dur) {
        await player.seek(Duration.zero);
      }
      await player.play();
    }
    // Play/pause state changes are also driven reactively by
    // `_playingSubscription`, but resetting here too keeps controls visible
    // immediately on tap rather than waiting for the stream event.
    _resetAutoHideTimer();
  }

  Future<void> _cycleSpeed() async {
    final player = _player;
    if (player == null) return;
    final newIndex = (_speedIndex + 1) % _speeds.length;
    await player.setRate(_speeds[newIndex]);
    if (!mounted) return;
    setState(() => _speedIndex = newIndex);
    _resetAutoHideTimer();
  }

  Future<void> _skipSeconds(int seconds) async {
    final player = _player;
    if (player == null) return;
    final duration = player.state.duration;
    final pos = player.state.position;
    var newPos = pos + Duration(seconds: seconds);
    if (newPos < Duration.zero) {
      newPos = Duration.zero;
    } else if (duration > Duration.zero && newPos > duration) {
      newPos = duration;
    }
    await player.seek(newPos);
    _resetAutoHideTimer();
  }

  void _resetAutoHideTimer() {
    _autoHideTimer?.cancel();
    if (!mounted) return;
    setState(() => _showControls = true);
    // Only auto-hide while actually playing. While paused, controls should
    // stay put until the user explicitly hides them (tapping the video) —
    // hiding them on a timer while paused made it easy to "lose" the play
    // button on a frozen frame.
    if (!_isPlaying) return;
    _autoHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetAutoHideTimer();
  }

  void _handleFullscreenToggle() {
    if (!widget.isFullScreen) {
      final isVertical = widget.isVertical;
      SystemChrome.setPreferredOrientations(
        isVertical
            ? [DeviceOrientation.portraitUp]
            : [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ],
      );
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    widget.onToggleFullScreen();
  }
}
