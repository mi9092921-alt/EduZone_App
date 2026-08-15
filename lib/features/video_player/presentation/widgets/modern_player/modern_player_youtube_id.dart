/// Matches the common YouTube URL shapes:
///   watch?v=ID , youtu.be/ID , embed/ID , shorts/ID , live/ID
/// and captures the 11-char video id right after them.
final RegExp _youtubeIdPattern = RegExp(
  r'(?:youtube(?:-nocookie)?\.com/(?:watch\?v=|embed/|shorts/|live/)|youtu\.be/)([A-Za-z0-9_-]{11})',
);

/// Strict shape of a real YouTube video id: exactly 11 chars from the
/// base64url-ish alphabet YouTube actually uses.
final RegExp _strictVideoIdShape = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// Extracts an 11-character YouTube video id from [raw].
///
/// - A bare 11-char id matching YouTube's id alphabet is returned as-is.
/// - Recognized YouTube URL shapes have their id captured out.
/// - Anything else — including a bare string that merely happens to be
///   11 characters long but contains characters outside the id alphabet
///   — returns `null`.
/// - Returns `null` for `null`/empty input.
///
/// SECURITY (AUTH/WEBVIEW-01): this value is later interpolated
/// unescaped into a JS string literal inside `buildModernPlayerHtml`
/// (`videoId: "$videoId"`) and into a `evaluateJavascript` call
/// (`loadVideo('$videoId')`) in `ModernPlayerWrapper._switchVideo`. The
/// previous behavior of returning the raw, unrecognized input unchanged
/// meant any value shaped like a "video id" that wasn't actually a valid
/// YouTube id (e.g. containing `'`, `"`, `</script>`, or other
/// JS-breaking characters) would flow straight into that WebView's
/// executing JS context — a classic DOM/JS injection primitive, sourced
/// from whatever produced `content.videoUrl` (lesson content). Returning
/// `null` for anything that doesn't match the strict id shape closes
/// that path: `ModernPlayerWrapper` already treats a `null`/empty id as
/// "show invalid-video-url message" instead of building a WebView, so
/// this is a strict tightening, not a new failure mode.
///
/// Pure function — didn't depend on any widget state in the original
/// `_extractVideoId`, so it moves out unchanged and is now directly
/// unit-testable.
///
/// NOTE: this is logically similar to `player4/player4_youtube_id.dart`'s
/// `extractYoutubeVideoId` — both players parse YouTube URLs the same
/// way. Kept as a separate copy here rather than a shared import so each
/// player variant stays a self-contained, independently pluggable unit
/// (per the `PlayerType` enum in the router) with no cross-player-family
/// coupling. Worth a follow-up if a third player ever needs the same
/// logic: promote to one shared
/// `lib/features/video_player/presentation/widgets/youtube_id.dart` used
/// by all player variants instead of duplicating a third time.
String? extractModernPlayerVideoId(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (!raw.contains('/') && _strictVideoIdShape.hasMatch(raw)) return raw;

  final match = _youtubeIdPattern.firstMatch(raw);
  if (match != null) return match.group(1);

  return null;
}
