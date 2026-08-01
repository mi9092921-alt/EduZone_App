import '../repositories/auth_repository.dart';

/// Calls `logout_current_user()` RPC + `auth.signOut()`.
///
/// NOTE (intentionally unused in production as of the auth Domain-layer
/// migration): [Auth.logout] in `auth_provider.dart` does NOT call this
/// use case. It uses `LogoutOrchestrator` instead, which performs the same
/// RPC + signOut as one of 7 comprehensive cleanup steps (secure storage
/// wipe, SharedPreferences wipe, FCM token cleanup, event bus, etc.) built
/// directly on the Supabase client.
///
/// This use case is kept — rather than deleted — as a documented, tested,
/// minimal fallback for a possible future scenario that needs a bare
/// login/logout without the full orchestrated cleanup. Before wiring it
/// into any new call site, confirm it still meets the security bar set by
/// `LogoutOrchestrator` (session-scoped storage wipe, best-effort error
/// handling, etc.) — do not use it as a drop-in replacement for the
/// orchestrator.
class LogoutUser {
  final AuthRepository repository;

  LogoutUser(this.repository);

  Future<void> call() {
    return repository.logout();
  }
}