/// Canonical video-time formatters shared by every player surface.
///
/// Consolidates the former per-player copies
/// (`player4/player4_format.dart`, `offline_player/offline_player_format.dart`,
/// and `youtube_player_widget.dart`'s private `_formatDuration`).
///
/// The players historically used two slightly different display formats;
/// both are preserved as named functions rather than silently changing
/// every screen's on-screen output:
///
/// - [formatVideoDuration] — `m:ss` (minutes unpadded), switching to
///   `h:mm:ss` once the duration reaches an hour. Used by the player4
///   seek bar, which previously accumulated raw minutes past 59
///   ("63:05") — that pre-existing quirk is intentionally normalized to
///   the canonical hours segment.
/// - [formatVideoDurationPadded] — `mm:ss` (minutes always two digits),
///   switching to `hh:mm:ss` once the duration reaches an hour. Used by
///   the offline player and the legacy YouTube player controls.
///
/// Both are pure functions (no widget/state dependency) so they are
/// directly unit-testable.
library;

/// Formats [duration] as `m:ss`, or `h:mm:ss` once it is an hour or
/// longer (minutes and seconds always two digits; hours and sub-hour
/// minutes unpadded).
///
/// Examples: `0:00`, `5:03`, `1:02:03`.
String formatVideoDuration(Duration duration) {
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  if (duration.inHours > 0) {
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    return '${duration.inHours}:$minutes:$seconds';
  }
  return '${duration.inMinutes}:$seconds';
}

/// Formats [duration] as `mm:ss` (minutes always two digits), or
/// `hh:mm:ss` once it is an hour or longer.
///
/// Examples: `00:00`, `03:05`, `01:02:03`.
String formatVideoDurationPadded(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = twoDigits(duration.inHours);
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  if (duration.inHours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}
