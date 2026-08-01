import 'dart:async';

import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../domain/entities/auth_state.dart';
import '../providers/auth_provider.dart';

/// Screen shown when the system is under maintenance.
///
/// Access data is derived from the sealed [AuthState].
/// Features:
/// - Auto-polling every 60 seconds to check if maintenance is over.
/// - Countdown timer if an end time is provided.
class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  Timer? _pollingTimer;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startPolling();
    _startCountdown();
  }

  void _startPolling() {
    // Poll every 60 seconds to check if maintenance is done
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _checkAccess();
    });
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

  @override
  void dispose() {
    _pollingTimer?.cancel();
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

    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes % 60;

    return AppScreen(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Maintenance icon
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  AppIcons.maintenance,
                  size: 56,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: AppSpacing.xl2),

              // Title
              Text(
                l10n.maintenanceScreenTitle,
                style: AppTextStyles.h1.copyWith(color: AppColors.primary),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Message
              Text(
                l10n.maintenanceScreenMsg,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: ds.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              // Countdown timer (if available)
              if (access?.until != null) ...[
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: ds.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ds.border),
                  ),
                  child: Text(
                    l10n.maintenanceCountdown(hours, minutes),
                    style: AppTextStyles.h2.copyWith(
                      fontFamily: 'JetBrainsMono',
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xl3),

              // Check again button
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: l10n.retryButton,
                  onPressed: _checkAccess,
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
