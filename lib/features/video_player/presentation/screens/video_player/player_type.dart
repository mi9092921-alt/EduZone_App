/// The 4 video player backends `VideoPlayerScreen` can be configured to
/// drive, each wired to its own route (`lesson`, `lesson2`, `lesson3`,
/// `lesson4` — see `player_switch_sheet.dart`).
///
/// Extracted from `video_player_screen.dart` so it can be imported by the
/// router and other screens without pulling in the full screen file.
enum PlayerType { youtube, proxy, modern, player4 }
