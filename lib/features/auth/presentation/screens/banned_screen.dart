import 'dart:async';

import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../shared/models/auth_state.dart';
import '../../application/providers/auth_provider.dart';

/// Screen shown when a user is permanently banned.
///
/// Access data is derived from the sealed [AuthState], not passed via constructor.
/// Logout triggers auth state change → router redirects automatically.
///
/// A periodic verifyAccess() re-check (same cadence as MaintenanceScreen)
/// covers the rare un-ban case: verifyAccess resolves to unauthenticated
/// (the session was force-signed-out) → the router moves the user to
/// /login automatically instead of leaving them stranded here.
class BannedScreen extends ConsumerStatefulWidget {
  const BannedScreen({super.key});

  @override
  ConsumerState<BannedScreen> createState() => _BannedScreenState();
}

class _BannedScreenState extends ConsumerState<BannedScreen> {
  Timer? _pollingTimer;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _checkAccess();
    });
  }

  /// Re-checks access — state change drives router navigation.
  Future<void> _checkAccess() async {
    if (_isChecking || !mounted) return;
    _isChecking = true;
    try {
      await ref.read(authProvider.notifier).verifyAccess();
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _appealBan() async {
    final uri = Uri.parse('mailto:appeals@eduzone.io?subject=Ban%20Appeal');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ds = AppColors.of(context);

    // Extract access data from the sealed state
    final authState = ref.watch(authProvider);
    final access = authState is AuthRestricted ? authState.access : null;

    return AppScreen(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ban icon
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.error.withValues(alpha: 0.1),
                child: const Icon(
                  AppIcons.banned,
                  size: 40,
                  color: AppColors.error,
                ),
              ),

              const SizedBox(height: AppSpacing.xl2),

              // Title
              Text(
                l10n.bannedScreenTitle,
                style: AppTextStyles.h1.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Message
              Text(
                l10n.bannedScreenMsg,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: ds.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              // Reason (if available)
              if (access?.message != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft.withValues(alpha: 0.5),
                    borderRadius: AppRadius.smBorder,
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    l10n.statusReason(access!.message!),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xl3),

              // Appeal Info
              Text(
                l10n.bannedScreenAppeal,
                style: AppTextStyles.bodySmall.copyWith(color: ds.textMuted),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Appeal Button
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: l10n.contactSupport,
                  leadingIcon: AppIcons.support,
                  onPressed: _appealBan,
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Logout button — NO manual context.go()
              Consumer(
                builder: (context, ref, _) {
                  final authState = ref.watch(authProvider);
                  final isLoggingOut = authState is AuthLoggingOut;

                  return SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: l10n.logout,
                      variant: AppButtonVariant.ghost,
                      leadingIcon: isLoggingOut ? null : AppIcons.logout,
                      isLoading: isLoggingOut,
                      onPressed: isLoggingOut
                          ? null
                          : () => ref.read(authProvider.notifier).logout(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
