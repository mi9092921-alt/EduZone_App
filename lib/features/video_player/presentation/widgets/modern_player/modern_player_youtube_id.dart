/// Matches the common YouTube URL shapes:
///   watch?v=ID , youtu.be/ID , embed/ID , shorts/ID , live/ID
/// and captures the 11-char video id right after them.
final RegExp _youtubeIdPattern = RegExp(
  r'(?:youtube(?:-nocookie)?\.com/(?:watch\?v=|embed/|shorts/|live/)|youtu\.be/)([A-Za-z0-9_-]{11})',
);

/// Extracts an 11-character YouTube video id from [raw].
///
/// - A bare 11-char id (no `/`) is returned as-is.
/// - Recognized YouTube URL shapes have their id captured out.
/// - Anything else is returned unchanged.
/// - Returns `null` for `null`/empty input.
///
/// Pure function — didn't depend on any widget state in the original
/// `_extractVideoId`, so it moves out unchanged and is now directly
/// unit-testable.
///
/// NOTE: this is logically identical to
/// `player4/player4_youtube_id.dart`'s `extractYoutubeVideoId` — both
/// players parse YouTube URLs the same way. Kept as a separate copy here
/// rather than a shared import so each player variant stays a
/// self-contained, independently pluggable unit (per the `PlayerType`
/// enum in the router) with no cross-player-family coupling. Worth a
/// follow-up if a third player ever needs the same logic: promote to one
/// shared `lib/features/video_player/presentation/widgets/youtube_id.dart`
/// used by all player variants instead of duplicating a third time.
String? extractModernPlayerVideoId(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (raw.length == 11 && !raw.contains('/')) return raw;

  final match = _youtubeIdPattern.firstMatch(raw);
  if (match != null) return match.group(1);

  return raw;
}
