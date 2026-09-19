import 'dart:async';

import 'package:flutter/foundation.dart'
    show VoidCallback, visibleForTesting;

/// Small helpers shared by the video player wrappers
/// (youtube/player4/modern/offline) for the two cross-cutting behaviors
/// every player needs: throttled progress reporting and auto-hiding
/// controls.
///
/// Extracted from near-identical private implementations in
/// `player4_wrapper.dart`, `modern_player_wrapper.dart`,
/// `youtube_player_wrapper.dart`, `youtube_player_widget.dart`, and
/// `offline_player_wrapper.dart`. Per-player differences (e.g. "only
/// hide controls while playing") stay with the owning wrapper via
/// callbacks.

/// Throttles playback-progress reporting to at most once per [interval].
///
/// Position streams/listeners fire many times per second; reporting
/// progress that often is unnecessary network/battery cost. A 5-second
/// resolution is plenty for a "resume where you left off" feature.
///
/// The throttle is purely time-based: [shouldReport] ignores [position]
/// (it is accepted so call sites read naturally and a future
/// position-aware policy has a place to hook in without changing the
/// signature). Starts ready to report immediately, matching the original
/// epoch-initialized `_lastProgressReport` fields.
class PlayerProgressReporter {
  /// Minimum time between accepted reports.
  final Duration interval;

  /// Injectable clock for the test-only constructor below.
  final DateTime Function() _now;

  DateTime _lastReport;

  PlayerProgressReporter({this.interval = const Duration(seconds: 5)})
    : _now = DateTime.now,
      _lastReport = DateTime.fromMillisecondsSinceEpoch(0);

  /// Test-only constructor with an injectable, deterministic clock.
  @visibleForTesting
  PlayerProgressReporter.withClock({
    this.interval = const Duration(seconds: 5),
    required DateTime Function() now,
  }) : _now = now,
       _lastReport = DateTime.fromMillisecondsSinceEpoch(0);

  /// Returns true at most once per [interval]; when it returns true the
  /// last-reported timestamp has been advanced, so the caller must
  /// actually report.
  bool shouldReport(Duration position) {
    final now = _now();
    if (now.difference(_lastReport) < interval) return false;
    _lastReport = now;
    return true;
  }

  /// Allows the next [shouldReport] call to succeed immediately (e.g.
  /// after a lesson switch), without reporting anything itself.
  void reset() {
    _lastReport = DateTime.fromMillisecondsSinceEpoch(0);
  }
}

/// Cancel-and-restart timer that auto-hides a player's controls overlay.
///
/// Wraps the "cancel any pending hide, then schedule a new one" pattern.
/// The hide action itself is provided by the owner as [onHide] so
/// per-player conditions (e.g. the offline player only hides while
/// playing, the legacy YouTube player checks its controller state when
/// the timer fires) stay with the player that owns that state.
class AutoHideControlsTimer {
  /// How long controls stay visible before [onHide] fires.
  final Duration delay;

  final VoidCallback onHide;

  Timer? _timer;

  AutoHideControlsTimer({
    this.delay = const Duration(seconds: 3),
    required this.onHide,
  });

  /// Cancels any pending hide and schedules a new one after [delay].
  void restart() {
    _timer?.cancel();
    _timer = Timer(delay, onHide);
  }

  /// Cancels any pending hide without scheduling a new one.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Cancels the pending hide; call from the owning State's dispose().
  void dispose() => cancel();
}
