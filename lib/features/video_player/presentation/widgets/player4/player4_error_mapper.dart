import '../../../../../core/l10n/arb/app_localizations.dart';

/// Maps any exception thrown while fetching/playing a video to the most
/// accurate user-facing, localized message.
///
/// Takes [l10n] directly (rather than a `BuildContext`) so it can be
/// unit-tested without pumping a widget tree — callers pass
/// `AppLocalizations.of(context)!`.
String mapPlayer4ErrorToMessage(AppLocalizations l10n, Object e) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('network') ||
      msg.contains('failed host lookup') ||
      msg.contains('socketexception') ||
      msg.contains('no internet') ||
      msg.contains('network_error')) {
    return l10n.checkInternetConnection;
  }
  if (msg.contains('formatexception') ||
      msg.contains('type cast') ||
      msg.contains('invalid video-info response format')) {
    return l10n.videoParseError;
  }
  return l10n.serverError;
}
