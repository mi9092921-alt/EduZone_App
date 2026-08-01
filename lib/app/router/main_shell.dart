import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/location_service.dart';
import '../../features/auth/domain/entities/auth_state.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/services/check_user_access_service.dart';

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  late final CheckUserAccessService _accessService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _accessService = CheckUserAccessService(
      supabase: ref.read(supabaseClientProvider),
      onAccessDenied: ({required reason}) {
        ref.read(authProvider.notifier).handleAccessDenied(reason: reason);
      },
    );

    // Start service if already authenticated
    _syncService(ref.read(authProvider));
  }

  /// Reactively starts/stops the access service based on auth state.
  void _syncService(AuthState authState) {
    if (authState is AuthAuthenticated) {
      _accessService.start(
        userId: authState.user.id,
        tenantId: authState.user.tenantId,
      );
    } else {
      _accessService.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Battery optimization: pause polling when app is backgrounded
    switch (state) {
      case AppLifecycleState.resumed:
        _syncService(ref.read(authProvider));
        LocationService.logOnAppOpen();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _accessService.stop();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _accessService.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state to reactively stop service on logout (Fix #10)
    ref.listen<AuthState>(authProvider, (prev, next) {
      _syncService(next);
    });

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: widget.navigationShell.currentIndex,
        onTap: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}