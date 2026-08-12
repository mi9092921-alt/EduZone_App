import 'package:supabase_flutter/supabase_flutter.dart';

/// Classifies whether a [PostgrestException] raised by the
/// `get_lesson_content` RPC represents a legitimate "access denied"
/// response (not enrolled / not a preview lesson) as opposed to a real
/// server-side error (lesson not found, a bug, a transient DB failure,
/// rate limiting, etc.).
///
/// This used to be an inline `||` chain in the data source that treated
/// *any* Postgres error with SQLSTATE `P0001` as "access denied" on its
/// own. `P0001` is the generic "raised_exception" code Postgres assigns to
/// *every* `RAISE EXCEPTION` in a PL/pgSQL function unless a custom
/// SQLSTATE is set — so any unrelated error raised inside the RPC (a typo
/// in a follow-up query, a lesson that doesn't exist, a future validation
/// error) was being silently swallowed and reported to the UI as "no
/// access" instead of surfacing as a real error.
///
/// The fix requires the message to actually mention a known
/// access-denial reason. The `P0001` code alone is informative but not
/// sufficient, since it is shared by every raised error in the function.
class LessonAccessErrorClassifier {
  const LessonAccessErrorClassifier._();

  /// Substrings the `get_lesson_content` RPC is known to raise when
  /// access is legitimately denied. Keep this list in sync with the
  /// RPC's `RAISE EXCEPTION` messages.
  static const List<String> _accessDeniedMarkers = [
    'ACCESS_DENIED',
    'not_enrolled',
    'NOT_ENROLLED',
  ];

  /// Postgres SQLSTATEs the RPC uses for user-raised (as opposed to
  /// infrastructure/database) errors. `P0001` is the default code for any
  /// `RAISE EXCEPTION` without an explicit SQLSTATE, so it is necessary
  /// but not sufficient on its own — it must be paired with a known
  /// access-denial message.
  static const List<String> _userRaisedCodes = ['P0001'];

  static bool isAccessDenied(PostgrestException e) {
    final hasKnownMarker =
        _accessDeniedMarkers.any((marker) => e.message.contains(marker));
    final isUserRaised =
        e.code != null && _userRaisedCodes.contains(e.code);

    // Require both: the RPC must have raised a user-level exception AND
    // that exception must actually be about access, not some other
    // condition that happens to share the same generic SQLSTATE.
    return hasKnownMarker && isUserRaised;
  }
}
