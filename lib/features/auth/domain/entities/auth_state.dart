import 'package:equatable/equatable.dart';

import '../enums/account_status.dart';
import 'app_user.dart';
import 'update_info.dart';
import 'user_access.dart';

/// The complete set of application-level authentication states.
/// The Router's redirect logic is driven exclusively by this enum.
///
/// Derived by [appStateProvider] from the sealed [AuthState] hierarchy.
enum AppAuthState {
  /// Initial state — session check in progress.
  initializing,

  /// Session is valid and the user has access.
  authenticated,

  /// Logout is in progress. Blocks new API requests.
  /// Router shows /splash during this state.
  loggingOut,

  /// No valid session. Router redirects to /login.
  unauthenticated,

  /// Account permanently banned. Router redirects to /banned.
  banned,

  /// Account temporarily suspended. Router redirects to /suspended.
  suspended,

  /// Account locked (e.g. too many failed attempts). Router redirects to /locked.
  locked,

  /// Platform is in maintenance mode. Router redirects to /maintenance.
  maintenance,

  /// App is temporarily locked. Router redirects to /app-locked.
  appLocked,

  /// App version is below the minimum — access is blocked until update.
  /// This is an APP-LEVEL restriction, not an account restriction.
  forceUpdate,

  /// A local session exists but it could not be verified against the
  /// server yet because of a transient/network error (not an explicit
  /// denial). The Router keeps showing /splash while the app retries
  /// automatically — it must NOT redirect to /login on its own, since
  /// that would force a logout-equivalent UX on a simple network blip.
  /// See EduZone_Authentication_Session_Security_Architecture.md, Phase 18.
  sessionVerificationPending,
}

// ─── Sealed Auth State Hierarchy ────────────────────────────────────────────

/// Single Source of Truth for the application's authentication state.
///
/// Used by [Auth] notifier in `auth_provider.dart`.
/// All variants are [Equatable] for proper Riverpod diffing — preventing
/// phantom rebuilds when the state hasn't actually changed.
sealed class AuthState extends Equatable {
  const AuthState();
}

/// App is booting — checking for an existing Supabase session.
class AuthInitializing extends AuthState {
  const AuthInitializing();

  @override
  List<Object?> get props => [];
}

/// Login form submitted — waiting for server response.
class AuthAuthenticating extends AuthState {
  const AuthAuthenticating();

  @override
  List<Object?> get props => [];
}

/// No valid session exists.
///
/// [error] contains a localization key when login fails,
/// or `null` after a clean logout / cold start.
class AuthUnauthenticated extends AuthState {
  final String? error;

  const AuthUnauthenticated({this.error});

  @override
  List<Object?> get props => [error];
}

/// User has a valid session and is allowed full access.
///
/// [updateInfo] is non-null when an optional update is available.
/// The UI layer (HomeScreen) reads this and shows the dialog once per version.
class AuthAuthenticated extends AuthState {
  final AppUser user;
  final UserAccess access;
  final UpdateInfo? updateInfo;

  const AuthAuthenticated({
    required this.user,
    required this.access,
    this.updateInfo,
  });

  @override
  List<Object?> get props => [user, access, updateInfo];
}

/// User has a session but their account is restricted.
///
/// [status] determines which restricted screen the router shows
/// (banned, suspended, locked, maintenance).
class AuthRestricted extends AuthState {
  final AccountStatus status;
  final UserAccess access;

  const AuthRestricted({required this.status, required this.access});

  @override
  List<Object?> get props => [status, access];
}

/// App version is critically outdated — access is fully blocked.
///
/// Separate from [AuthRestricted] because this is an APP-LEVEL state,
/// not an account restriction. The router redirects to /force-update.
class AuthForceUpdate extends AuthState {
  final UpdateInfo updateInfo;

  const AuthForceUpdate(this.updateInfo);

  @override
  List<Object?> get props => [updateInfo];
}

/// Logout in progress — orchestrator is running cleanup steps.
class AuthLoggingOut extends AuthState {
  const AuthLoggingOut();

  @override
  List<Object?> get props => [];
}

/// A local Supabase session exists, but [_initializeSession] could not
/// confirm it with the server because of a transient error (no
/// connectivity, timeout, DNS failure, 5xx, etc.) — NOT an explicit
/// denial from the server.
///
/// The session is deliberately left intact: no local cleanup, no
/// server-side logout call, no navigation to /login. The `Auth` notifier
/// retries verification automatically with capped exponential backoff
/// (see `_scheduleDegradedRetry` / `retryDegradedSession` in
/// `auth_provider.dart`).
///
/// This exists specifically to satisfy
/// EduZone_Authentication_Session_Security_Architecture.md Phase 18:
/// "transient network error must never force logout / redirect to
/// login by itself." Before this state existed, any transient error hit
/// during cold-start session verification fell through to
/// [AuthUnauthenticated], which the Router maps straight to /login —
/// silently discarding a perfectly valid session because of a network
/// blip.
class AuthDegraded extends AuthState {
  /// Localization key for the underlying transient error, if any.
  final String? error;

  /// How many automatic retries have been attempted so far. Exposed
  /// mainly for tests/telemetry; the UI is not required to display it.
  final int retryAttempt;

  const AuthDegraded({this.error, this.retryAttempt = 0});

  @override
  List<Object?> get props => [error, retryAttempt];
}
