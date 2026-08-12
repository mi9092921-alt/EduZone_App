import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/auth/domain/entities/auth_state.dart';
import '../../features/auth/domain/enums/account_status.dart';
import '../../features/auth/application/providers/auth_provider.dart';

part 'app_state_provider.g.dart';

/// Derives [AppAuthState] from the sealed [AuthState] hierarchy.
///
/// This is the ONLY provider the router watches. All 7 AppAuthState
/// values are now reachable — fixing the dead-branch router bug.
@riverpod
AppAuthState appState(Ref ref) {
  final authState = ref.watch(authProvider);
  return switch (authState) {
    AuthInitializing()   => AppAuthState.initializing,
    AuthAuthenticating() => AppAuthState.initializing,
    AuthAuthenticated()  => AppAuthState.authenticated,
    AuthUnauthenticated() => AppAuthState.unauthenticated,
    AuthLoggingOut()     => AppAuthState.loggingOut,
    AuthForceUpdate()    => AppAuthState.forceUpdate,
    AuthRestricted(status: AccountStatus.banned)      => AppAuthState.banned,
    AuthRestricted(status: AccountStatus.suspended)    => AppAuthState.suspended,
    AuthRestricted(status: AccountStatus.locked)       => AppAuthState.locked,
    AuthRestricted(status: AccountStatus.maintenance)  => AppAuthState.maintenance,
    AuthRestricted(status: AccountStatus.appLocked)    => AppAuthState.appLocked,
    AuthRestricted()     => AppAuthState.unauthenticated,
  };
}
