import '../../../../../core/l10n/arb/app_localizations.dart';

/// Maps any exception thrown while fetching/playing a video to the most
/// accurate user-facing, localized message.
///
/// Takes [l10n] directly (rather than a `BuildContext`) so it can be
/// unit-tested without pumping a widget tree — callers pass
/// `AppLocalizations.of(context)!`.
///
/// Phase 11 (failure taxonomy): an authorization denial (revoked/expired
/// entitlement, banned/suspended account, wrong lesson — surfaced by
/// video-info as 401/403/404/410 or an access-denied message) maps to
/// [videoAccessDenied], NOT to the generic server error. Collapsing a
/// denial into "server error" sends users (and support triage) down the
/// wrong path, and the reverse — treating a transient playback/network
/// fault as an auth failure — is never done here without evidence: only
/// explicit denial markers take the access branch. Everything else keeps
/// the previous network → parse → server fallback order.
String mapPlayer4ErrorToMessage(AppLocalizations l10n, Object e) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('network') ||
      msg.contains('failed host lookup') ||
      msg.contains('socketexception') ||
      msg.contains('no internet') ||
      msg.contains('network_error')) {
    return l10n.checkInternetConnection;
  }
  if (msg.contains('access denied') ||
      msg.contains('access_denied') ||
      msg.contains('unauthorized') ||
      msg.contains('forbidden') ||
      msg.contains('lesson not found') ||
      msg.contains('lesson_not_found') ||
      msg.contains('error 401') ||
      msg.contains('error 403') ||
      msg.contains('error 404') ||
      msg.contains('error 410') ||
      msg.contains('status 401') ||
      msg.contains('status 403') ||
      msg.contains('status 404') ||
      msg.contains('status 410')) {
    return l10n.videoAccessDenied;
  }
  if (msg.contains('formatexception') ||
      msg.contains('type cast') ||
      msg.contains('invalid video-info response format')) {
    return l10n.videoParseError;
  }
  return l10n.serverError;
}
