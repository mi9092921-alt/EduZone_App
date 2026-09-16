import 'package:flutter/foundation.dart';

import '../error/exceptions.dart';

/// Global seam for reacting to server-side session revocation detected on
/// ANY network-bound call, not just auth ones.
///
/// `NetworkExceptionMapper` is a pure static classifier and must not know
/// about Riverpod or the auth feature; but when an arbitrary RPC comes back
/// with Postgres ERRCODE 28000 / AUTH_REQUIRED, the only sane reaction is a
/// forced sign-out — waiting for the next 5-minute access poll or Realtime
/// tick would let a locked/revoked user keep issuing requests that fail
/// with generic errors in the meantime. The poll/Realtime subscription
/// (CheckStudentAppAccessService) remain the authoritative detection paths;
/// this hook only closes the gap between "an RPC noticed it" and "the poll
/// confirms it".
///
/// Following the `SecurityService.killAppHandler` idiom: the composition
/// root (auth_provider) registers a handler at startup; the hook stays
/// inert (null handler) until then. [notify] swallows handler errors — the
/// hook may fire from a catch block mid-teardown and must never throw out
/// of band.
class SessionRevocationHook {
  SessionRevocationHook._();

  static void Function(SessionRevokedException exception)? onSessionRevoked;

  static bool get isWired => onSessionRevoked != null;

  static void notify(SessionRevokedException exception) {
    final handler = onSessionRevoked;
    if (handler == null) return;
    try {
      handler(exception);
    } catch (e) {
      debugPrint('[SessionRevocationHook] handler error: ${e.runtimeType}');
    }
  }
}
