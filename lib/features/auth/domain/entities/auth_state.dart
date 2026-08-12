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
