import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pending_deep_link_provider.g.dart';

/// Deep-link destination that was intercepted before it could be honoured,
/// to be restored once the session state allows it.
///
/// Before this existed, every deep link (cold-start URI, FCM tap replayed
/// by FcmService.registerRouter, in-app navigation) that arrived while the
/// auth state was still `initializing`/`authenticating`/degraded — or
/// while the user was unauthenticated — was silently collapsed to `/home`
/// (or `/login` → `/home`) by the router redirect: the destination was
/// dropped, never to be restored after login.
///
/// The router redirect owns the stash/consume lifecycle:
///  - while a session is being established (or absent) and a protected
///    location is requested, the redirect stashes it here and forces
///    /splash (or /login);
///  - once [AppAuthState.authenticated] redirects away from
///    /splash//login, it consumes the stashed location and sends the user
///    there instead of unconditionally landing on /home;
///  - [loggingOut] clears the stash so a stale pre-logout destination can
///    never resurface for a different session.
///
/// Only router-validated locations (see the router's deep-link allowlist)
/// are ever stored, so this is not an open-redirect surface.
@riverpod
class PendingDeepLink extends _$PendingDeepLink {
  @override
  String? build() => null;

  /// Records [location] as the destination to restore later. Idempotent —
  /// the redirect may fire several times while a session is pending; the
  /// last requested location wins, which matches user intent.
  void stash(String location) {
    state = location;
  }

  /// Returns and clears the pending destination (if any).
  String? consume() {
    final value = state;
    state = null;
    return value;
  }

  /// Discards the pending destination without consuming it.
  void clear() {
    state = null;
  }
}
