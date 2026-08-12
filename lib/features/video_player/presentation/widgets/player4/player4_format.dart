/// Formats [d] as `m:ss` (minutes unpadded, seconds always 2 digits).
///
/// Named distinctly from the offline-player's `formatPlayerDuration` (which
/// uses `mm:ss` / `hh:mm:ss`) because the two players have always used
/// slightly different formats — preserved as-is rather than unified, to
/// avoid changing on-screen behavior as part of a pure refactor.
///
/// Pure function (no widget/state dependency) so it can be unit-tested
/// directly.
String formatPlayer4Duration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
