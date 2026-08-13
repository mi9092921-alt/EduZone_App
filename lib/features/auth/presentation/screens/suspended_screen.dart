import 'dart:async';

import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../application/providers/auth_provider.dart';
import '../../domain/entities/auth_state.dart';

/// Screen shown when user's account is temporarily suspended.
/// Per PRD §7.3.
///
/// Access data is derived from the sealed [AuthState].
/// Features:
/// - Live countdown timer showing days:hours:minutes until suspension ends
/// - Auto-check access when timer reaches zero
/// - Contact support mailto link
class SuspendedScreen extends ConsumerStatefulWidget {
  const SuspendedScreen({super.key});

  @override
  ConsumerState<SuspendedScreen> createState() => _SuspendedScreenState();
}

class _SuspendedScreenState extends ConsumerState<SuspendedScreen> {
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    final authState = ref.read(authProvider);
    final until = authState is AuthRestricted ? authState.access.until : null;
    if (until == null) return;

    _remaining = until.difference(DateTime.now());
    if (_remaining.isNegative) {
      _remaining = Duration.zero;
      _checkAccess();
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final diff = until.difference(now);

      if (diff.isNegative || diff == Duration.zero) {
        _countdownTimer?.cancel();
        setState(() => _remaining = Duration.zero);
        _checkAccess();
      } else {
        setState(() => _remaining = diff);
      }
    });
  }

  /// Re-checks access — state change drives router navigation.
  Future<void> _checkAccess() async {
    await ref.read(authProvider.notifier).verifyAccess();
    // No manual navigation — router reacts to auth state change.
  }

  Future<void> _contactSupport() async {
    final uri = Uri.parse(
      'mailto:support@eduzone.io?subject=Account%20Suspended',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ds = AppColors.of(context);

    // Extract access data from the sealed state
    final authState = ref.watch(authProvider);
    final access = authState is AuthRestricted ? authState.access : null;

    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;

    return AppScreen(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Timer icon
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.warning.withValues(alpha: 0.1),
                child: const Icon(
                  AppIcons.suspended,
                  size: 40,
                  color: AppColors.warning,
                ),
              ),

              const SizedBox(height: AppSpacing.xl2),

              // Title
              Text(
                l10n.suspendedScreenTitle,
                style: AppTextStyles.h1.copyWith(color: ds.warningText),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Message
              Text(
                l10n.suspendedScreenMsg,
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
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: AppRadius.xsBorder,
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    l10n.statusReason(access!.message!),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: ds.warningText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              // Countdown timer
              if (access?.until != null) ...[
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: ds.surface,
                    borderRadius: AppRadius.smBorder,
                    border: Border.all(color: ds.border),
                  ),
                  child: Text(
                    l10n.suspendedCountdown(days, hours, minutes),
                    style: AppTextStyles.h2.copyWith(
                      fontFamily: 'JetBrainsMono',
                      color: ds.warningText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xl3),

              // Check Status button
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: l10n.suspendedScreenCheckStatusBtn,
                  onPressed: _checkAccess,
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Contact Support button
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: l10n.contactSupport,
                  variant: AppButtonVariant.ghost,
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
