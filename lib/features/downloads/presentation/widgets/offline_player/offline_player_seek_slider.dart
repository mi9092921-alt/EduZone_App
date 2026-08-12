import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import 'offline_player_format.dart';

/// Seek slider + elapsed/total time row.
///
/// Deliberately decoupled from `media_kit`'s `Player` — it depends only on
/// a position [Stream], a duration getter, and a seek callback. `Player()`
/// opens native platform resources on construction and can't run inside a
/// normal `flutter test` sandbox (no libmpv), so a widget that talked to
/// `Player` directly would be untestable; this one can be driven by a fake
/// stream in tests.
///
/// Owns its own drag state ([_isDragging] / [_draggedPosition]) so drag
/// interaction never needs to reach back into the parent's state — mirrors
/// the original comment: "rebuilds stay local to the slider/time text".
class OfflinePlayerSeekSlider extends StatefulWidget {
  final Stream<Duration> positionStream;
  final Duration initialPosition;
  final Duration Function() getDuration;
  final Future<void> Function(Duration position) onSeek;

  /// Called after a completed seek (drag released), so the parent can
  /// re-evaluate its auto-hide timer. Mirrors the original
  /// `_resetAutoHideTimer()` call at the end of `onChangeEnd`.
  final VoidCallback onSeekEnd;

  const OfflinePlayerSeekSlider({
    super.key,
    required this.positionStream,
    required this.initialPosition,
    required this.getDuration,
    required this.onSeek,
    required this.onSeekEnd,
  });

  @override
  State<OfflinePlayerSeekSlider> createState() =>
      _OfflinePlayerSeekSliderState();
}

class _OfflinePlayerSeekSliderState extends State<OfflinePlayerSeekSlider> {
  bool _isDragging = false;
  Duration _draggedPosition = Duration.zero;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.positionStream,
      initialData: widget.initialPosition,
      builder: (context, snapshot) {
        final currentPosition = _isDragging
            ? _draggedPosition
            : (snapshot.data ?? Duration.zero);
        final duration = widget.getDuration();

        // Guard against a Flutter Slider assertion failure: `value` must
        // never exceed `max`. Position and duration can transiently
        // disagree right after a seek or while duration is still 0 during
        // early buffering.
        final maxMs = duration.inMilliseconds.toDouble();
        final valueMs = currentPosition.inMilliseconds.toDouble().clamp(
          0.0,
          maxMs,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              value: valueMs,
              max: maxMs,
              activeColor: Colors.white,
              inactiveColor: Colors.white24,
              onChanged: maxMs <= 0
                  ? null
                  : (v) {
                      setState(() {
                        _isDragging = true;
                        _draggedPosition = Duration(
                          milliseconds: v.toInt(),
                        );
                      });
                    },
              onChangeEnd: (v) async {
                await widget.onSeek(_draggedPosition);
                if (mounted) {
                  setState(() => _isDragging = false);
                  widget.onSeekEnd();
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatPlayerDuration(currentPosition),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    formatPlayerDuration(duration),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
