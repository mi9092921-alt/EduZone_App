// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_deep_link_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(PendingDeepLink)
final pendingDeepLinkProvider = PendingDeepLinkProvider._();

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
final class PendingDeepLinkProvider
    extends $NotifierProvider<PendingDeepLink, String?> {
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
  PendingDeepLinkProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingDeepLinkProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingDeepLinkHash();

  @$internal
  @override
  PendingDeepLink create() => PendingDeepLink();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$pendingDeepLinkHash() => r'7a4279a2e2d8a5d99ba8fc63490339d3dc95a52c';

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

abstract class _$PendingDeepLink extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
