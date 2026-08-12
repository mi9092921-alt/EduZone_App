import '../../../data/models/streaming_video_info.dart';

/// Picks the best matching [StreamingFormat] for [defaultLabel] out of
/// [formats], in priority order:
///
///  1. Exact quality-string match (case-insensitive).
///  2. Exact resolution-height match (e.g. both are "720p"-shaped).
///  3. Closest resolution height.
///  4. First available format, as a last resort.
///
/// Returns `null` only if [formats] is empty.
///
/// Pure function — didn't depend on any widget state in the original
/// `_findDefaultFormat`, so it moves out unchanged and is now directly
/// unit-testable.
StreamingFormat? findDefaultStreamingFormat(
  List<StreamingFormat> formats,
  String defaultLabel,
) {
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
