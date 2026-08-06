/// Formats [duration] as `mm:ss`, or `hh:mm:ss` once the video is an hour
/// or longer.
///
/// Pure function (no widget/state dependency) so it can be unit-tested
/// directly and reused anywhere a player duration needs to be displayed.
String formatPlayerDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = twoDigits(duration.inHours);
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  if (duration.inHours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}
