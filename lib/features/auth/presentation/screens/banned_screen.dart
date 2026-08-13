import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../application/providers/auth_provider.dart';
import '../../domain/entities/auth_state.dart';

/// Screen shown when a user is permanently banned.
///
/// Access data is derived from the sealed [AuthState], not passed via constructor.
/// Logout triggers auth state change → router redirects automatically.
class BannedScreen extends ConsumerWidget {
  const BannedScreen({super.key});

  Future<void> _appealBan() async {
    final uri = Uri.parse('mailto:appeals@eduzone.io?subject=Ban%20Appeal');
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
