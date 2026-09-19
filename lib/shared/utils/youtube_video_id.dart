/// Matches the common YouTube URL shapes:
///   watch?v=ID , youtu.be/ID , embed/ID , shorts/ID , live/ID
/// and captures the 11-char video id right after them.
final RegExp _youtubeIdPattern = RegExp(
  r'(?:youtube(?:-nocookie)?\.com/(?:watch\?v=|embed/|shorts/|live/)|youtu\.be/)([A-Za-z0-9_-]{11})',
);

/// Strict shape of a real YouTube video id: exactly 11 chars from the
/// base64url-ish alphabet YouTube actually uses.
final RegExp _strictVideoIdShape = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// Extracts an 11-character YouTube video id from [urlOrId].
///
/// - A bare 11-char id matching YouTube's id alphabet is returned as-is.
/// - Recognized YouTube URL shapes have their id captured out.
/// - Anything else — including a bare string that merely happens to be
///   11 characters long but contains characters outside the id alphabet,
///   or a non-YouTube URL — returns `null`.
/// - Returns `null` for `null`/empty input.
///
/// SECURITY (AUTH/WEBVIEW-01): the result is interpolated unescaped into
/// JS string literals inside the players' WebView layers (`videoId:
/// "$videoId"`, `loadVideo('$videoId')`). The original player4 behavior
/// of returning raw, unrecognized input unchanged would let any value
/// containing JS-breaking characters flow straight into the WebView's
/// executing JS context — a DOM/JS injection primitive sourced from
/// whatever produced `content.videoUrl` (lesson content). Returning
/// `null` for anything that doesn't match the strict id shape closes
/// that path: every caller already treats a `null`/empty id as "show
/// invalid-video-url message" instead of building a player, so this is a
/// strict tightening, not a new failure mode.
///
/// Pure function — no widget state, directly unit-testable. Consolidates
/// the former per-player copies (`player4/player4_youtube_id.dart` and
/// `modern_player/modern_player_youtube_id.dart`), which parsed YouTube
/// URLs identically.
String? extractYoutubeVideoId(String? urlOrId) {
  if (urlOrId == null || urlOrId.isEmpty) return null;
  if (!urlOrId.contains('/') && _strictVideoIdShape.hasMatch(urlOrId)) {
    return urlOrId;
  }

  final match = _youtubeIdPattern.firstMatch(urlOrId);
  if (match != null) return match.group(1);

  return null;
}
