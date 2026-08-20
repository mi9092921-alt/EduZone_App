import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/arb/app_localizations.dart';
import '../../features/auth/domain/enums/account_status.dart';

/// Per-status foreground color only.
/// The background is derived at runtime as foreground.withOpacity(0.12),
/// which automatically adapts to both light and dark themes.
const _chipForeground = <AccountStatus, Color>{
  AccountStatus.active: AppColors.success,
  AccountStatus.locked: AppColors.error,
  AccountStatus.suspended: AppColors.warning,
  AccountStatus.banned: AppColors.error,
  AccountStatus.inactive: AppColors.neutral500,
  AccountStatus.maintenance: AppColors.warning,
  AccountStatus.unauthenticated: AppColors.neutral500,
  AccountStatus.appLocked: AppColors.error,
  AccountStatus.unrecognized: AppColors.neutral500,
};

class StatusChip extends StatelessWidget {
  final AccountStatus status;

  const StatusChip({super.key, required this.status});

  String _labelFor(AppLocalizations l10n) {
    return switch (status) {
      AccountStatus.active => l10n.statusActive,
      AccountStatus.locked => l10n.statusLocked,
      AccountStatus.suspended => l10n.statusSuspended,
      AccountStatus.banned => l10n.statusBanned,
      AccountStatus.inactive => l10n.statusInactive,
      AccountStatus.maintenance => l10n.statusMaintenance,
      AccountStatus.unauthenticated => l10n.statusUnauthenticated,
      AccountStatus.appLocked => l10n.statusAppLocked,
      AccountStatus.unrecognized => l10n.statusUnrecognized,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final isRtl = locale.languageCode == 'ar';
    final fg = _chipForeground[status]!;
    final bg = fg.withValues(alpha: 0.12);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xs,
          AppSpacing.xs2,
          AppSpacing.sm,
          AppSpacing.xs2,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.fullBorder,
          border: Border.all(color: fg.withValues(alpha: 0.25), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: fg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs2),
            Text(
              _labelFor(l10n),
              style: AppTextStyles.labelSmall.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

