/// The 3 video player backends `VideoPlayerScreen` can be configured to
/// drive, each wired to its own route (`lesson`, `lesson3`, `lesson4` — see
/// `player_switch_sheet.dart`).
///
/// Extracted from `video_player_screen.dart` so it can be imported by the
/// router and other screens without pulling in the full screen file.
// Proxy was removed because its WebView implementation had a security
// vulnerability and lacked the required navigation delegate.
enum PlayerType { youtube, modern, player4 }
