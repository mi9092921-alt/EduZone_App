import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../providers/network_banner_provider.dart';

/// A globally available banner that displays when network connection is lost.
///
/// Wrap the main scaffold body with this widget. Connectivity state and the
/// dismiss state are both owned by [networkBannerProvider]
/// (`NetworkBannerNotifier`) — this widget only reacts to `state.shouldShow`
/// and animates in/out, the same separation `TodoNotifier` uses for todos.
class NetworkBanner extends ConsumerStatefulWidget {
  final Widget child;

  const NetworkBanner({super.key, required this.child});

  @override
  ConsumerState<NetworkBanner> createState() => _NetworkBannerState();
}

class _NetworkBannerState extends ConsumerState<NetworkBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);

    // Only react when shouldShow actually flips (offline && !dismissed).
    ref.listen<bool>(
      networkBannerProvider.select((s) => s.shouldShow),
      (previous, shouldShow) {
        if (shouldShow) {
          _animController.forward();
        } else {
          _animController.reverse();
        }
      },
    );

    return Stack(
      children: [
        // The main content
        widget.child,

        // The banner overlay
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: Material(
              elevation: 4,
              color: Colors.transparent,
              child: SafeArea(
                bottom: false,
                child: Container(
                  width: double.infinity,
                  margin:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: ds.error,
                    borderRadius: AppRadius.smBorder,
                    boxShadow: [
                      BoxShadow(
                        color: ds.error.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        AppIcons.wifiOff,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Builder(
                          builder: (ctx) {
                            // Use Builder to get context with localizations
                            final l10n = AppLocalizations.of(ctx);
                            final text = l10n?.noInternetBanner ??
                                'No internet connection';
                            return Text(
                              text,
                              style: AppTextStyles.label.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Dismiss button — lets the student close the banner
                      // while still offline (e.g. watching a downloaded
                      // video). It reappears next time the connection
                      // actually drops again.
                      Builder(
                        builder: (ctx) {
                          final l10n = AppLocalizations.of(ctx);
                          return Semantics(
                            button: true,
                            label: l10n?.dismissOfflineNotice ?? 'Dismiss offline notice',
                            child: InkWell(
                              borderRadius: AppRadius.lgBorder,
                              onTap: () => ref
                                  .read(networkBannerProvider.notifier)
                                  .dismiss(),
                              child: const Padding(
                                padding: EdgeInsets.all(AppSpacing.xs2), // check-ignore -- already a token; false positive
                                child: Icon(
                                  AppIcons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
