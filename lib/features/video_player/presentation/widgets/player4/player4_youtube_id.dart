/// Matches the common YouTube URL shapes:
///   watch?v=ID , youtu.be/ID , embed/ID , shorts/ID , live/ID
/// and captures the 11-char video id right after them.
final RegExp _youtubeIdPattern = RegExp(
  r'(?:youtube(?:-nocookie)?\.com/(?:watch\?v=|embed/|shorts/|live/)|youtu\.be/)([A-Za-z0-9_-]{11})',
);

/// Extracts an 11-character YouTube video id from [urlOrId].
///
/// - A bare 11-char id (no `/`) is returned as-is.
/// - Recognized YouTube URL shapes have their id captured out.
/// - Anything else is returned unchanged (e.g. a direct id, or a
///   non-YouTube identifier this widget also needs to pass through).
/// - Returns `null` for `null`/empty input.
///
/// Pure function — didn't depend on any widget state in the original
/// `_extractVideoId`, so it moves out unchanged and is now directly
/// unit-testable.
String? extractYoutubeVideoId(String? urlOrId) {
  if (urlOrId == null || urlOrId.isEmpty) return null;
  if (urlOrId.length == 11 && !urlOrId.contains('/')) return urlOrId;

  final match = _youtubeIdPattern.firstMatch(urlOrId);
  if (match != null) return match.group(1);

  return urlOrId;
}
