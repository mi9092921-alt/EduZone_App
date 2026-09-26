import '../../../../core/l10n/arb/app_localizations.dart';

/// Maps a YouTube IFrame API error code — surfaced by
/// `youtube_player_flutter` as `YoutubePlayerValue.errorCode` (0 = no
/// error) — to the most accurate user-facing, localized message.
///
/// Takes [l10n] directly (rather than a `BuildContext`) so it can be
/// unit-tested without pumping a widget tree — callers pass
/// `AppLocalizations.of(context)!`, mirroring
/// `mapPlayer4ErrorToMessage` in `player4_error_mapper.dart`.
///
/// IFrame API codes (only the app-relevant subset is special-cased; the
/// package's synthetic `-1` for a malformed JS payload and the rare HTML5
/// `5` both fall through to the generic code-bearing message so support
/// can still triage from a screenshot):
/// - `1`/`2`: malformed/invalid video id in the player request.
/// - `100`: video removed or set to private by its owner.
/// - `101`/`150`: owner disabled embedding/playback for this video.
String mapYoutubeErrorCodeToMessage(AppLocalizations l10n, int errorCode) {
  switch (errorCode) {
    case 1:
    case 2:
      return l10n.invalidVideoUrl;
    case 100:
    case 101:
    case 150:
      // A removed/private/embedding-disabled video is unwatchable for the
      // student regardless of entitlement; the access-denied copy is the
      // closest existing message and routes them to support. Kept
      // deliberate here so a future key (e.g. videoUnavailable) has a
      // single swap point.
      return l10n.videoAccessDenied;
    default:
      return l10n.videoLoadErrorCode(errorCode);
  }
}
