import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../application/providers/auth_provider.dart';
import '../../domain/entities/auth_state.dart';

/// Screen shown when user's account is locked (too many failed logins,
/// admin action, etc.). Per PRD §7.3.
///
/// Access data is derived from the sealed [AuthState].
/// Logout triggers auth state change → router redirects automatically.
class LockedScreen extends ConsumerWidget {
  const LockedScreen({super.key});

  Future<void> _contactSupport() async {
    final uri = Uri.parse('mailto:support@eduzone.io?subject=Account%20Locked');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              // Lock icon
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.error.withValues(alpha: 0.1),
                child: const Icon(
                  AppIcons.locked,
                  size: 40,
                  color: AppColors.error,
                ),
              ),

              const SizedBox(height: AppSpacing.xl2),

              // Title
              Text(
                l10n.lockedScreenTitle,
                style: AppTextStyles.h1.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Message
              Text(
                l10n.lockedScreenMsg,
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
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: AppRadius.xsBorder,
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    l10n.statusReason(access!.message!),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xl3),

              // Contact Support button
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: l10n.contactSupport,
                  leadingIcon: AppIcons.support,
                  onPressed: _contactSupport,
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
