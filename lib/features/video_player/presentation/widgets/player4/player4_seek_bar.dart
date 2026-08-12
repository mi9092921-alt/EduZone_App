import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import 'player4_format.dart';

/// Bottom time labels + seek slider.
///
/// Deliberately decoupled from `media_kit`'s `Player` — it depends only on
/// position/duration [Stream]s and an `onSeek` callback, so it can be
/// driven by fake streams in tests instead of a real native `Player()`
/// (which opens platform resources on construction and can't run inside a
/// normal `flutter test` sandbox).
///
/// Preserves the original's exact interaction model: unlike a typical
/// "seek on release" slider, this calls [onSeek] on every `onChanged` tick
/// (i.e. continuously while dragging), matching the original
/// `_buildControlsOverlay` behavior precisely rather than "improving" it
/// as part of this refactor.
class Player4SeekBar extends StatelessWidget {
  final Stream<Duration> positionStream;
  final Duration initialPosition;
  final Stream<Duration> durationStream;
  final Duration initialDuration;
  final DesignSystemColors ds;

  /// Fired on every slider `onChanged` tick with the new seek target.
  final ValueChanged<Duration> onSeek;

  const Player4SeekBar({
    super.key,
    required this.positionStream,
    required this.initialPosition,
    required this.durationStream,
    required this.initialDuration,
    required this.ds,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: positionStream,
      initialData: initialPosition,
      builder: (context, posSnapshot) {
        final position = posSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: durationStream,
          initialData: initialDuration,
          builder: (context, durSnapshot) {
            final duration = durSnapshot.data ?? Duration.zero;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatPlayer4Duration(position),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white70,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      formatPlayer4Duration(duration),
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
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5.0,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 10.0,
                      ),
                      activeTrackColor: ds.primary,
                      inactiveTrackColor: Colors.white12,
                      thumbColor: ds.primary,
                    ),
                    child: Slider(
                      value: position.inSeconds.toDouble().clamp(
                        0.0,
                        duration.inSeconds.toDouble(),
                      ),
                      max: duration.inSeconds.toDouble() > 0.0
                          ? duration.inSeconds.toDouble()
                          : 1.0,
                      onChanged: (value) {
                        onSeek(Duration(seconds: value.toInt()));
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
