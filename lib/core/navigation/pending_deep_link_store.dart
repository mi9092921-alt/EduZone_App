import 'package:flutter/foundation.dart';

/// Process-wide holder for a deep-link destination intercepted before it
/// could be honoured, to be restored once the session state allows it.
///
/// Deliberately a static store (the same idiom as
/// `SecurityService.killSwitchEngaged`), NOT a Riverpod provider: the
/// router's redirect callback runs during the widget-tree build phase, and
/// mutating provider state there throws "Tried to modify a provider while
/// the widget tree was building" — which previously left the initial
/// redirect silently unresolved (the app stayed on /splash until some
/// later navigation happened). A plain static write has no such
/// restriction.
///
/// Lifecycle: in-memory only — it resets on process restart, which matches
/// the deep-link semantics (a cold-start deep link is stashed by the
/// redirect during the very first navigation and consumed once the session
/// resolves; if the process dies before that, the link is gone, exactly
/// like any unhandled deep link).
///
/// The router owns the stash/consume/clear lifecycle (see
/// `evaluateAppRedirect` in app_router.dart); only router-validated
/// locations are ever stored, so this is not an open-redirect surface.
abstract final class PendingDeepLinkStore {
  static String? _pending;

  /// Records [location] as the destination to restore later. The last
  /// requested location wins, which matches user intent (the redirect may
  /// fire several times while a session is pending).
  static void stash(String location) => _pending = location;

  /// Returns and clears the pending destination (if any).
  static String? consume() {
    final value = _pending;
    _pending = null;
    return value;
  }

  /// Discards the pending destination without consuming it.
  static void clear() => _pending = null;

  /// Test-only reset.
  @visibleForTesting
  static void resetForTest() => _pending = null;
}
